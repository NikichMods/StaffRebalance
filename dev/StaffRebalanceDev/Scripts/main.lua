-- SPDX-License-Identifier: MPL-2.0
-- Dev candidate, not production. F4=start, F7=stop. Astral 2/3 action boundary is native skill Begin/End.
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
local animSkill = "/Script/Genesis.BaseCharacterAnimInstance:"
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

local function guarded(callback)
    return function(...)
        if not session then return end
        local ok, err = pcall(function(...)
            assert(IsInGameThread(), "not_game_thread")
            local pawn = player()
            assert(pawn and id(pawn) == session.player, "player_changed")
            callback(pawn, ...)
        end, ...)
        if not ok then fail(err) end
    end
end

local function attach(path, callback)
    local a, b = RegisterHook(path, guarded(callback))
    hooks[#hooks + 1] = {path = path, a = a, b = b}
    assert(type(a) == "number" and a > 0 and a == b, "unexpected_hook_ids:" .. path)
end

local function attachNative(path, pre, post)
    local a, b = RegisterHook(path, guarded(pre), guarded(post))
    hooks[#hooks + 1] = {path = path, a = a, b = b}
    assert(math.type(a) == "integer" and math.type(b) == "integer"
        and a > 0 and b > 0 and a ~= b, "unexpected_native_hook_ids:" .. path)
end

local function comboBegin(_, context)
    local anim = context:get()
    if not valid(anim) or id(anim) ~= session.anim then return end
    local skill = anim:GetDoingSkill():ToString()
    -- An independent Begin replaces the prior action, including an interrupted one.
    session.combo = nil
    if skill == "hilda_staff_atk2" or skill == "hilda_staff_atk3" then
        session.combo = {skill = skill}
        log("COMBO_BEGIN", "skill=" .. skill)
    end
end

local function comboEnd(_, context)
    local anim = context:get()
    if not session.combo or not valid(anim) or id(anim) ~= session.anim then return end
    local skill = anim:GetDoingSkill():ToString()
    if skill == session.combo.skill then
        log("COMBO_END", "skill=" .. skill .. " mode=" .. tostring(session.combo.mode or "no_bolt"))
        session.combo = nil
    end
end

local function owned(source, pawn)
    local owner = source:GetCharacterOwner()
    return valid(owner) and id(owner) == id(pawn)
end

local function astralBegin(pawn, context)
    local bolt = context:get()
    assert(exact(bolt, astral), "unexpected_astral_context")
    -- First-step bolts are one per action. Steps 2/3 use native Begin/End and the first real bolt.
    if not owned(bolt, pawn) then
        log("SKIP", "reason=foreign_astral_owner")
        return
    end
    local row = bolt.ProjectileDataName:ToString()
    if row ~= "hilda_staff_bolt_astral" then
        log("SKIP", "reason=unsupported_astral_row row=" .. tostring(row))
        return
    end
    local sourceId = id(bolt)
    if session.shots[sourceId] then
        log("SKIP", "reason=duplicate_source source=" .. sourceId)
        return
    end
    local skill = StaticFindObject(GLOBAL):GetDoingSkill(pawn):ToString()
    local combo
    if skill == "hilda_staff_atk2" or skill == "hilda_staff_atk3" then
        combo = session.combo
        local mesh = pawn.Mesh
        local anim = valid(mesh) and mesh:GetAnimInstance()
        if not combo or combo.skill ~= skill or not valid(anim) or id(anim) ~= session.anim then
            if not session.skippedSkills[skill] then
                session.skippedSkills[skill] = true
                log("SKIP", "reason=unverified_combo_boundary skill=" .. skill)
            end
            return
        end
        if combo.mode == "skip_e804" then
            log("SKIP", "reason=unverified_e804_combo source=" .. sourceId)
            return
        end
    elseif skill ~= "hilda_staff_atk1" and skill ~= "hilda_staff_atk1_idle" then
        if not session.skippedSkills[skill] then
            session.skippedSkills[skill] = true
            log("SKIP", "reason=unsupported_astral_skill skill=" .. skill)
        end
        return
    end
    assert(field(bolt, "DamageRate", 0x2C4))
    assert(field(bolt, "Original Damage Rate"))
    local rate = get(bolt, "DamageRate")
    assert(rate > 0, "invalid_astral_rate")
    if get(bolt, "Original Damage Rate") ~= 0 then
        if combo and not combo.mode then combo.mode = "skip_e804" end
        log("SKIP", "reason=unverified_e804 source=" .. sourceId)
        return
    end
    local before = session.reserve
    local first = not combo or not combo.mode
    local mode = (combo and combo.mode) or (before > 0 and "strong" or "weak")
    local effective = rate
    if mode == "weak" then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_rate")
        local ok, err = pcall(write, bolt, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, bolt, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    local debit = (first and mode == "strong") and 1 or 0
    if debit == 1 then session.reserve = before - 1 end
    if combo and first then combo.mode = mode end
    session.shots[sourceId] = mode
    log("SHOT", "skill=" .. skill .. " mode=" .. mode
        .. " before=" .. before .. " reserve=" .. session.reserve .. " rate=" .. rate
        .. " effective=" .. effective .. " debit=" .. debit .. " source=" .. sourceId)
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
        {animSkill .. "BeginDoSkill", true, false, ""},
        {animSkill .. "EndDoSkill", true, false, ""},
    }) do
        local ok, reason = check(table.unpack(spec))
        if not ok then log("UNAVAILABLE", reason); return end
    end
    local pawn, problem = player()
    if not pawn then log("UNAVAILABLE", problem); return end
    local mesh = pawn.Mesh
    if not valid(mesh) or not valid(mesh:GetOwner()) or id(mesh:GetOwner()) ~= id(pawn) then
        log("UNAVAILABLE", "invalid_hilda_mesh")
        return
    end
    local anim = mesh:GetAnimInstance()
    if not valid(anim) or not anim:GetClass():GetFullName():match("%.hilda_AnimBP_C$") then
        log("UNAVAILABLE", "invalid_hilda_anim")
        return
    end
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
        attachNative(animSkill .. "BeginDoSkill", function() end, comboBegin)
        attachNative(animSkill .. "EndDoSkill", comboEnd, function() end)
    end)
    if not ok then
        fail(err)
        cleanup()
        return
    end
    session = {player = id(pawn), anim = id(anim), reserve = capacity,
        shots = {}, contacts = {}, skippedSkills = {}}
    log("START", "reserve=" .. capacity .. " hooks=" .. #hooks)
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
    for _, key in ipairs({Key.F4, Key.F7}) do
        assert(not IsKeyBindRegistered(key), "key_collision")
    end
    bind(Key.F7, stop)
    bind(Key.F4, start)
end)
if ok then log("LOADED", "F4=start F7=stop astral_atk2_atk3_action_debit=true")
else fail(err) end
