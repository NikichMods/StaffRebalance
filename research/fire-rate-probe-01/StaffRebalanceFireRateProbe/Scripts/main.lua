-- SPDX-License-Identifier: MPL-2.0
-- Research only. At most one modified Fire sphere. F4=vanilla, F6=weak, F7=stop.
local P = "STAFF_FIRE_RATE01"
local CLASS = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_200.sphere_200_C"
local PARENT = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/hilda_staff_bolt_fire.hilda_staff_bolt_fire_C"
local BEGIN = CLASS .. ":ReceiveBeginPlay"
local HIT = "/Game/MainContent/Template/BaseBlueprint/BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local GLOBAL = "/Script/Genesis.Default__GameGlobal"
local mode, disabled = nil, false
local hooks, samples = {}, {}
local baseline, weakAttempted

local function log(event, detail)
    print(P .. " " .. event .. " " .. (detail or "") .. "\n")
end
local function valid(x)
    return x ~= nil and x:IsValid()
end
local function id(x)
    if not valid(x) then return "none" end
    return x:GetFName():ToString() .. "@" .. tostring(x:GetAddress())
end
local function finite(x)
    return type(x) == "number" and x == x and math.abs(x) < math.huge
end
local function check(path, native, static, shape, offsets)
    local fn = StaticFindObject(path)
    if not valid(fn) or fn:GetFullName() ~= "Function " .. path then
        return false, "missing:" .. path
    end
    local flags = fn:GetFunctionFlags()
    if (((flags & 0x400) ~= 0) ~= native)
        or (((flags & 0x2000) ~= 0) ~= static)
        or (flags & 0x00400000) ~= 0 then
        return false, "flags:" .. path
    end
    local fields = {}
    fn:ForEachProperty(function(prop)
        local kind, name = prop:GetFullName():match("^(%w+) .+:([^:]+)$")
        if offsets and name then name = name:lower() end
        local item = tostring(kind) .. ":" .. tostring(name)
        if offsets then item = item .. "@" .. prop:GetOffset_Internal() end
        fields[#fields + 1] = item
    end)
    if table.concat(fields, ",") ~= shape then
        return false, "shape:" .. path .. ":" .. table.concat(fields, ",")
    end
    return true
end
local function field(object, name, offset)
    local prop = object:Reflection():GetProperty(name)
    -- XProperty returns nil from GetFullName for a null property.
    local fullName = prop and prop:GetFullName()
    if type(fullName) ~= "string" then return false, "missing_property:" .. name end
    local kind, actual = fullName:match("^(%w+) .+:([^:]+)$")
    if kind ~= "FloatProperty" or actual ~= name then
        return false, "wrong_property:" .. name
    end
    if offset and prop:GetOffset_Internal() ~= offset then
        return false, "wrong_offset:" .. name
    end
    return true
end
local function get(object, name)
    local value = object:GetPropertyValue(name)
    assert(finite(value), "nonfinite_property:" .. name)
    return value
end
local function write(object, name, value)
    object:SetPropertyValue(name, value)
    assert(get(object, name) == value, "readback_mismatch:" .. name)
end
local function player()
    local cdo = StaticFindObject(GLOBAL)
    if not valid(cdo) or cdo:GetFullName() ~= "GameGlobal " .. GLOBAL then
        return nil, "missing_global"
    end
    local pawn = cdo:GetPlayerCharacter()
    if not valid(pawn) or pawn:GetClass():GetFName():ToString() ~= "hilda_BP_C" then
        return nil, "missing_hilda"
    end
    return pawn
end
local function disable(reason)
    if disabled then return end
    disabled, mode = true, nil
    log("DISABLED", "reason=" .. tostring(reason):sub(1, 170) .. " action=restart_game")
end
local function guarded(callback)
    return function(...)
        if not mode or disabled then return end
        local ok, err = pcall(callback, ...)
        if not ok then disable("callback:" .. tostring(err)) end
    end
end
local function cleanup()
    local remaining = {}
    for _, item in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, item.path, item.a, item.b)
        if not ok then
            remaining[#remaining + 1] = item
            log("CLEANUP_FAILED", "path=" .. item.path .. " error=" .. tostring(err):sub(1, 100))
        end
    end
    hooks = remaining
end
local function attach(path, handler)
    local a, b = RegisterHook(path, guarded(handler))
    hooks[#hooks + 1] = {path = path, a = a, b = b}
    assert(type(a) == "number" and a > 0 and a == b, "hook_ids:" .. path)
end

local function exact(object, path)
    return valid(object) and object:GetClass():GetFullName() == "BlueprintGeneratedClass " .. path
end

local function begin(context)
    if not IsInGameThread() then disable("wrong_thread"); return end
    if mode == "weak" and weakAttempted then return end
    local sphere = context:get()
    if not exact(sphere, CLASS) or sphere.ProjectileDataName:ToString() ~= "hilda_staff_bolt_fire_explosion" then return end
    local parent = sphere:GetOwner()
    if not exact(parent, PARENT) or parent.ProjectileDataName:ToString() ~= "hilda_staff_bolt_fire" then
        log("SKIP", "reason=fire_parent")
        return
    end
    local pawn = player()
    if not pawn or id(sphere:GetCharacterOwner()) ~= id(pawn) or id(parent:GetCharacterOwner()) ~= id(pawn) then
        log("SKIP", "reason=character_owner")
        return
    end
    local sourceId = id(sphere)
    if samples[sourceId] then return end
    local ready, reason = field(sphere, "DamageRate", 0x2C4)
    assert(ready, reason)
    local rate = get(sphere, "DamageRate")
    assert(rate > 0, "nonpositive_rate")
    local effective = rate
    if mode == "weak" then
        if rate ~= baseline.rate then
            disable("baseline_rate_mismatch")
            return
        end
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_scaled_rate")
        weakAttempted = true
        local ok, err = pcall(write, sphere, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, sphere, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    samples[sourceId] = {mode = mode, rate = rate, parent = id(parent), owner = id(pawn)}
    log("SPHERE", "mode=" .. mode .. " source=" .. sourceId .. " parent=" .. id(parent)
        .. " owner=" .. id(pawn) .. " before=" .. rate .. " after=" .. effective)
end

local function hit(context, projectile, _component, _position, damage)
    if not IsInGameThread() then disable("wrong_thread"); return end
    local sphere = projectile:get()
    if not exact(sphere, CLASS) then return end
    local sourceId = id(sphere)
    local sample = samples[sourceId]
    if not sample then return end
    local target, pawn = context:get(), player()
    if not valid(target) or not pawn or id(pawn) ~= sample.owner or id(sphere:GetCharacterOwner()) ~= sample.owner then return end
    local notified = damage:get()
    assert(finite(notified), "invalid_hit_damage")
    local current = get(sphere, "DamageRate")
    if sample.mode == "vanilla" and not baseline and notified > 0 and current == sample.rate then
        baseline = sample
    end
    log("HIT", "mode=" .. sample.mode .. " source=" .. sourceId .. " parent=" .. sample.parent
        .. " target=" .. id(target) .. " target_class=" .. target:GetClass():GetFName():ToString()
        .. " current_rate=" .. current .. " notified_damage=" .. notified)
end

local function arm(nextMode)
    if disabled then log("UNAVAILABLE", "restart_required"); return end
    if not IsInGameThread() then log("UNAVAILABLE", "not_game_thread"); return end
    if nextMode == "weak" and (not baseline or weakAttempted) then
        log("UNAVAILABLE", "need_vanilla_hit_or_weak_already_attempted"); return
    end
    if #hooks == 0 then
        for _, row in ipairs({
            {"/Script/Genesis.GameGlobal:GetPlayerCharacter", true, true, "ObjectProperty:ReturnValue", false},
            {"/Script/Genesis.BaseProjectile:GetCharacterOwner", true, false, "ObjectProperty:ReturnValue", false},
            {"/Script/Engine.Actor:GetOwner", true, false, "ObjectProperty:ReturnValue", false},
            {BEGIN, false, false, "", false},
            {HIT, false, false, "ObjectProperty:projectile@0,ObjectProperty:hitcomponent@8,StructProperty:hitposition@16,FloatProperty:damage@28", true}
        }) do
            local ok, reason = check(row[1], row[2], row[3], row[4], row[5])
            if not ok then log("UNAVAILABLE", reason); return end
        end
        if not player() then log("UNAVAILABLE", "load_playable_hilda"); return end
        local ok, err = pcall(function()
            attach(BEGIN, begin)
            attach(HIT, hit)
        end)
        if not ok then
            log("UNAVAILABLE", "registration:" .. tostring(err):sub(1, 150))
            cleanup()
            disable("hook_registration")
            return
        end
        log("HOOKS_READY", "count=" .. #hooks)
    elseif #hooks ~= 2 then
        disable("incomplete_hook_set")
        return
    end
    mode = nextMode
    log("MODE", "value=" .. mode .. " k=" .. (mode == "weak" and "0.5" or "1.0")
        .. " wait_for_previous_sphere_before_switch=true")
end
local function stop()
    if not IsInGameThread() then disable("stop_wrong_thread"); return end
    mode, disabled = nil, true
    cleanup()
    samples = {}
    log("STOP", "hooks_remaining=" .. #hooks .. " exit_game_without_save=true")
end
local function dispatch(key, callback)
    log("KEY", "key=" .. key)
    local ok, err = pcall(ExecuteInGameThread, function()
        log("ENGINE_TICK_ENTRY", "key=" .. key)
        local result, reason = pcall(callback)
        if not result then disable("action:" .. tostring(reason)) end
    end, EGameThreadMethod.EngineTick)
    if not ok then disable("dispatch:" .. tostring(err)) end
end

local ok, errorStartup = pcall(function()
    assert(EngineTickAvailable == true and type(EGameThreadMethod.EngineTick) == "number",
        "no_engine_tick")
    for _, fn in ipairs({"StaticFindObject", "RegisterHook", "UnregisterHook",
        "RegisterKeyBind", "IsKeyBindRegistered", "ExecuteInGameThread", "IsInGameThread"}) do
        assert(type(_G[fn]) == "function", "missing_api:" .. fn)
    end
    for _, key in ipairs({Key.F4, Key.F6, Key.F7}) do
        assert(type(key) == "number" and not IsKeyBindRegistered(key), "key_collision")
    end
    RegisterKeyBind(Key.F4, function() dispatch("F4", function() arm("vanilla") end) end)
    RegisterKeyBind(Key.F6, function() dispatch("F6", function() arm("weak") end) end)
    RegisterKeyBind(Key.F7, function() dispatch("F7", stop) end)
end)
if ok then
    log("ARMED", "inactive_by_default=true F4=vanilla F6=weak F7=stop")
else
    disabled = true
    log("UNAVAILABLE", tostring(errorStartup):sub(1, 180))
end
