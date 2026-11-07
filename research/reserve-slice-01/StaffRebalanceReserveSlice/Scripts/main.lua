-- SPDX-License-Identifier: MPL-2.0
-- Research only. F4=start, F6=arm one Astral attempt, F7=stop.
local prefix = "STAFF_RESERVE01"
local assets = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local astral = assets .. "hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local daggers = assets .. "hilda_dual_atk.hilda_dual_atk_C"
local root = "/Game/MainContent/Template/BaseBlueprint/"
local mobHit = root .. "BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local conduit = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local recovery = root .. "MainGameInstance_BP.MainGameInstance_BP_C:RecoverPlayerAndScene"
local recoveryContext = root .. "GameGlobalBlueprintLibrary.GameGlobalBlueprintLibrary_C:RecoverPlayerAndScene"
local GLOBAL = "/Script/Genesis.Default__GameGlobal"
local capacity = 3
local hooks = {}
local session, closed

local function log(event, detail)
    print(prefix .. " " .. event .. " " .. (detail or "") .. "\n")
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function id(object)
    assert(valid(object), "invalid_object")
    return object:GetFullName() .. "@" .. tostring(object:GetAddress())
end

local function exact(object, path)
    return valid(object) and object:GetClass():GetFullName() == "BlueprintGeneratedClass " .. path
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
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
local function fail(reason)
    session, closed = nil, true
    log("FAILED", "reason=" .. tostring(reason):sub(1, 200) .. " action=F7_then_exit")
end

local function cleanup()
    local remaining = {}
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, hook.path, hook.a, hook.b)
        if not ok then
            remaining[#remaining + 1] = hook
            log("CLEANUP_FAILED", hook.path .. " " .. tostring(err):sub(1, 100))
        end
    end
    hooks = remaining
end

local function attach(path, callback)
    local a, b = RegisterHook(path, function(...)
        if not session then return end
        local ok, err = pcall(function(...)
            assert(IsInGameThread(), "not_game_thread")
            local pawn = player()
            assert(pawn and id(pawn) == session.player, "player_changed")
            callback(pawn, ...)
        end, ...)
        if not ok then fail(err) end
    end)
    hooks[#hooks + 1] = {path = path, a = a, b = b}
    assert(type(a) == "number" and a > 0 and a == b, "unexpected_hook_ids:" .. path)
end

local function owned(source, pawn)
    local owner = source:GetCharacterOwner()
    return valid(owner) and id(owner) == id(pawn)
end

local function astralBegin(pawn, context)
    local bolt = context:get()
    assert(exact(bolt, astral), "unexpected_astral_context")
    if not owned(bolt, pawn) then
        assert(not session.armed, "astral_owner_mismatch")
        return
    end
    assert(bolt.ProjectileDataName:ToString() == "hilda_staff_bolt_astral", "astral_row_mismatch")
    local skill = StaticFindObject(GLOBAL):GetDoingSkill(pawn):ToString()
    assert(skill == "hilda_staff_atk1" or skill == "hilda_staff_atk1_idle", "unsupported_astral_skill:" .. skill)
    local sourceId = id(bolt)
    assert(session.armed and not session.shots[sourceId], "extra_or_unarmed_astral_source")
    session.armed = false
    assert(field(bolt, "DamageRate", 0x2C4))
    assert(field(bolt, "Original Damage Rate"))
    local rate = get(bolt, "DamageRate")
    assert(rate > 0 and get(bolt, "Original Damage Rate") == 0, "unsupported_rate_or_e804")
    local before = session.reserve
    local effective = rate
    if before == 0 then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_rate")
        local ok, err = pcall(write, bolt, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, bolt, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    else
        session.reserve = before - 1
    end
    local mode = before > 0 and "strong" or "weak"
    session.shots[sourceId] = mode
    log("SHOT", "attempt=" .. session.attempt .. " skill=" .. skill .. " mode=" .. mode
        .. " before=" .. before .. " reserve=" .. session.reserve .. " rate=" .. rate
        .. " effective=" .. effective .. " source=" .. sourceId)
end

local function hit(pawn, context, sourceParam, _component, _position, damageParam)
    local target, source = context:get(), sourceParam:get()
    if not valid(target) or not valid(source) then return end
    if exact(source, astral) then
        local sourceId = id(source)
        local mode = session.shots[sourceId]
        if mode then
            local damage = damageParam:get()
            assert(finite(damage), "invalid_astral_notification")
            log("ASTRAL_HIT", "mode=" .. mode .. " notified_damage=" .. damage
                .. " rate=" .. get(source, "DamageRate") .. " source=" .. sourceId .. " target=" .. id(target))
        end
        return
    end
    if not exact(source, daggers) or source.ProjectileDataName:ToString() ~= "hilda_dual_attack_astral"
        or not owned(source, pawn) then return end
    -- Only the observed enemy class and the native AffectEnemy dagger row are in scope.
    if target:GetClass():GetFName():ToString() ~= "m052_arvicolina_BP_C" then return end
    local damage = damageParam:get()
    assert(finite(damage), "invalid_melee_notification")
    local sourceId, targetId = id(source), id(target)
    local seen = session.contacts[sourceId]
    if not seen then
        seen = {}
        session.contacts[sourceId] = seen
    end
    if seen[targetId] then
        log("DUPLICATE", "reserve=" .. session.reserve .. " source=" .. sourceId .. " target=" .. targetId)
        return
    end
    seen[targetId] = true
    local before = session.reserve
    session.reserve = math.min(capacity, before + 1)
    log("MELEE", "before=" .. before .. " reserve=" .. session.reserve .. " notified_damage=" .. damage
        .. " source=" .. sourceId .. " target=" .. targetId)
end

local function requestRest(_, context)
    session.rest = {conduit = id(context:get())}
    log("REST_REQUEST", "reserve=" .. session.reserve .. " conduit=" .. session.rest.conduit)
end

local function endUse(_, context)
    session.rest = nil
    log("MENU_EXIT", "reserve=" .. session.reserve .. " conduit=" .. id(context:get()))
end

local function transport()
    session.rest = nil
    log("TRANSPORT", "reserve=" .. session.reserve)
end

local function recover(_, context)
    if session.rest then session.rest.recovery = id(context:get()) end
end

local function confirmRest(_, _context, worldContext)
    local pending = session.rest
    session.rest = nil
    local point = worldContext:get()
    if not pending or not pending.recovery or not valid(point) or id(point) ~= pending.conduit then
        log("RECOVERY_IGNORED", "reserve=" .. session.reserve)
        return
    end
    local before = session.reserve
    session.reserve = capacity
    log("REST", "before=" .. before .. " reserve=" .. session.reserve .. " conduit=" .. pending.conduit)
end

local function start()
    if closed or session then return end
    for _, spec in ipairs({
        {"/Script/Genesis.GameGlobal:GetPlayerCharacter", true, true, "ObjectProperty:ReturnValue"},
        {"/Script/Genesis.GameGlobal:GetDoingSkill", true, true, "ObjectProperty:Character,NameProperty:ReturnValue"},
        {"/Script/Genesis.BaseProjectile:GetCharacterOwner", true, false, "ObjectProperty:ReturnValue"},
    }) do
        local ok, reason = check(table.unpack(spec))
        if not ok then log("UNAVAILABLE", reason); return end
    end
    local pawn, problem = player()
    if not pawn then log("UNAVAILABLE", problem); return end
    local routes = {
        {astral .. ":ReceiveBeginPlay", "", astralBegin},
        {mobHit, "ObjectProperty:projectile@0,ObjectProperty:hitcomponent@8,StructProperty:hitposition@16,FloatProperty:damage@28", hit, false, true},
        {conduit .. "Interact_Rest", "", requestRest},
        {conduit .. "Interact_EndUse", "", endUse},
        {conduit .. "Interact_Transport", "NameProperty:SavePointRowName", transport},
        {recovery, "", recover},
        {recoveryContext, "ObjectProperty:__WorldContext,ObjectProperty:CallFunc_GetGenesisGameInstance_ReturnValue", confirmRest, true},
    }
    for _, route in ipairs(routes) do
        local ok, reason = check(route[1], false, route[4] == true, route[2], route[5])
        if not ok then log("UNAVAILABLE", reason); return end
    end
    local ok, err = pcall(function()
        for _, route in ipairs(routes) do attach(route[1], route[3]) end
    end)
    if not ok then
        fail(err)
        cleanup()
        return
    end
    session = {player = id(pawn), reserve = capacity, attempt = 0, shots = {}, contacts = {}}
    log("START", "reserve=" .. capacity .. " hooks=" .. #hooks)
end

local function arm()
    if not session then return end
    if session.armed then
        log("ATTEMPT_PENDING", "attempt=" .. session.attempt .. " reserve=" .. session.reserve)
        return
    end
    session.attempt = session.attempt + 1
    session.armed = true
    log("ATTEMPT", "attempt=" .. session.attempt .. " reserve=" .. session.reserve)
end

local function stop()
    local reserve = session and session.reserve or "inactive"
    session, closed = nil, true
    cleanup()
    log("STOP", "reserve=" .. reserve .. " hooks_remaining=" .. #hooks)
end

local function bind(key, action)
    RegisterKeyBind(key, function()
        local ok, err = pcall(ExecuteInGameThread, function()
            local executed, problem = pcall(function()
                assert(IsInGameThread(), "not_game_thread")
                action()
            end)
            if not executed then fail(problem) end
        end, EGameThreadMethod.EngineTick)
        if not ok then fail(err) end
    end)
end

local ok, err = pcall(function()
    assert(EngineTickAvailable == true and type(EGameThreadMethod.EngineTick) == "number", "no_engine_tick")
    for _, name in ipairs({"RegisterHook", "UnregisterHook", "StaticFindObject",
        "RegisterKeyBind", "IsKeyBindRegistered", "ExecuteInGameThread", "IsInGameThread"}) do
        assert(type(_G[name]) == "function", "missing_api:" .. name)
    end
    for _, key in ipairs({Key.F4, Key.F6, Key.F7}) do
        assert(not IsKeyBindRegistered(key), "key_collision")
    end
    bind(Key.F7, stop)
    bind(Key.F4, start)
    bind(Key.F6, arm)
end)
if ok then log("LOADED", "F4=start F6=arm_one_Astral F7=stop")
else fail(err) end
