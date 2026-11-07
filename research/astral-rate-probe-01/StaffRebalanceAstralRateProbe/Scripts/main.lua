-- SPDX-License-Identifier: MPL-2.0
-- Research only. No writes until F6; F4=vanilla, F6=0.5x, F7=stop.
local P = "STAFF_ASTRAL_RATE01"
local ROOT = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local CLASS = ROOT .. "hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local BEGIN = CLASS .. ":ReceiveBeginPlay"
local HIT = "/Game/MainContent/Template/BaseBlueprint/BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local GLOBAL = "/Script/Genesis.Default__GameGlobal"
local KEY = "hilda_staff_bolt_astral"
local SAVED = "Original Damage Rate"
local mode, disabled = nil, false
local hooks, samples, serial = {}, {}, 0

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
local function equal(a, b)
    return finite(a) and finite(b)
        and math.abs(a - b) <= 0.0001 * math.max(math.abs(a), math.abs(b), 0.000001)
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
    if not valid(prop) then return false, "missing_property:" .. name end
    local kind, actual = prop:GetFullName():match("^(%w+) .+:([^:]+)$")
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
local function source(object)
    if not valid(object) or object:GetClass():GetFullName() ~= "BlueprintGeneratedClass " .. CLASS then
        return false, "class"
    end
    local row = object.ProjectileDataName
    if not row or row:ToString() ~= KEY then return false, "row" end
    local pawn, problem = player()
    if not pawn then return false, problem end
    local owner = object:GetCharacterOwner()
    if not valid(owner) or id(owner) ~= id(pawn) then return false, "owner" end
    return true
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
    assert(type(a) == "number" and a > 0 and a == b, "hook_ids:" .. path)
    hooks[#hooks + 1] = {path = path, a = a, b = b}
end

local function begin(context)
    if not IsInGameThread() then disable("wrong_thread"); return end
    local bolt = context:get()
    local ok, why = source(bolt)
    if not ok then
        if why ~= "class" and why ~= "row" then log("SKIP", "reason=" .. why) end
        return
    end
    local goodRate, whyRate = field(bolt, "DamageRate", 0x2C4)
    local goodSaved, whySaved = field(bolt, SAVED)
    if not goodRate or not goodSaved then
        disable("reflection:" .. tostring(whyRate or whySaved))
        return
    end
    local rate, saved = get(bolt, "DamageRate"), get(bolt, SAVED)
    if rate <= 0 or saved < 0 then disable("invalid_initial_rate"); return end
    local talent = "plain"
    if saved > 0 then
        if equal(rate, saved * 1.1) then talent = "e804"
        elseif equal(rate, saved) then talent = "saved_equal"
        else disable("unrecognized_rate_relation"); return end
    end
    local reduced = mode == "weak"
    local newRate, newSaved = reduced and rate * 0.5 or rate, reduced and saved * 0.5 or saved
    if not finite(newRate) or newRate <= 0 or not finite(newSaved) then
        disable("invalid_scaled_rate")
        return
    end
    if reduced then
        local wrote, errorWrite = pcall(function()
            if saved > 0 then
                bolt:SetPropertyValue(SAVED, newSaved)
                assert(equal(get(bolt, SAVED), newSaved), "saved_not_updated")
            end
            bolt:SetPropertyValue("DamageRate", newRate)
            assert(equal(get(bolt, "DamageRate"), newRate), "rate_not_updated")
        end)
        if not wrote then
            local restored, errorRestore = pcall(function()
                bolt:SetPropertyValue("DamageRate", rate)
                if saved > 0 then bolt:SetPropertyValue(SAVED, saved) end
                assert(equal(get(bolt, "DamageRate"), rate), "rate_not_restored")
                if saved > 0 then assert(equal(get(bolt, SAVED), saved), "saved_not_restored") end
            end)
            if not restored then
                log("ROLLBACK_FAILED", "source=" .. id(bolt) .. " error=" .. tostring(errorRestore):sub(1, 110)
                    .. " action=quit_without_save")
            end
            disable("write_failed:" .. tostring(errorWrite))
            return
        end
    end
    serial = serial + 1
    samples[tostring(bolt:GetAddress())] = {serial = serial, mode = mode}
    log("BOLT", "n=" .. serial .. " mode=" .. mode .. " source=" .. id(bolt)
        .. " talent=" .. talent .. " before=" .. tostring(rate)
        .. " after=" .. tostring(get(bolt, "DamageRate"))
        .. " original_before=" .. tostring(saved)
        .. " original_after=" .. tostring(get(bolt, SAVED)))
end
local function hit(context, projectile, _component, _position, damage)
    if not IsInGameThread() then disable("wrong_thread"); return end
    local bolt = projectile:get()
    if not source(bolt) then return end
    local sample = samples[tostring(bolt:GetAddress())]
    local notified = damage:get()
    if not finite(notified) then disable("invalid_hit_damage"); return end
    local target = context:get()
    if not valid(target) then return end
    log("HIT", "n=" .. (sample and sample.serial or "untracked")
        .. " spawn_mode=" .. (sample and sample.mode or "unknown")
        .. " source=" .. id(bolt) .. " target=" .. id(target)
        .. " current_rate=" .. tostring(get(bolt, "DamageRate"))
        .. " notified_damage=" .. tostring(notified) .. " phase=script_post")
end

local function arm(nextMode)
    if disabled then log("UNAVAILABLE", "restart_required"); return end
    if not IsInGameThread() then log("UNAVAILABLE", "not_game_thread"); return end
    if not player() then log("UNAVAILABLE", "load_playable_hilda"); return end
    if #hooks == 0 then
        for _, row in ipairs({
            {"/Script/Genesis.GameGlobal:GetPlayerCharacter", true, true, "ObjectProperty:ReturnValue", false},
            {"/Script/Genesis.BaseProjectile:GetCharacterOwner", true, false, "ObjectProperty:ReturnValue", false},
            {BEGIN, false, false, "", false},
            {HIT, false, false, "ObjectProperty:projectile@0,ObjectProperty:hitcomponent@8,StructProperty:hitposition@16,FloatProperty:damage@28", true}
        }) do
            local ok, reason = check(row[1], row[2], row[3], row[4], row[5])
            if not ok then log("UNAVAILABLE", reason); return end
        end
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
        .. " wait_for_previous_bolt_before_switch=true")
end
local function stop()
    mode = nil
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
    log("UNAVAILABLE", tostring(errorStartup):sub(1, 180))
end
