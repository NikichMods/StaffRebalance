-- SPDX-License-Identifier: MPL-2.0
local prefix = "STAFF_COMBAT_OBS01"
local genesis = "/Script/Genesis."
local projectile = genesis .. "BaseProjectile:"
local global = genesis .. "GameGlobal:"
local assets = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local scene = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local mode, sequence, generation = nil, 0, 0
local hooks = {}

local function log(event, detail)
    print(prefix .. " " .. event .. " " .. (detail or "") .. "\n")
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function name(object)
    return object:GetFName():ToString()
end

local function derived(object, expected)
    if not valid(object) then return false end
    local class = object:GetClass()
    for _ = 1, 24 do
        if not valid(class) then return false end
        if name(class) == expected then return true end
        class = class:GetSuperStruct()
    end
    return false
end

local function identity(object)
    if not valid(object) then return "none" end
    return name(object:GetClass()) .. "@" .. tostring(object:GetAddress())
end

-- ForEachProperty on this baseline exposes names and types, but not CPF flags.
-- Fire hit permits one audited by-value struct, which the callback never accesses.
local function check(path, native, static, expected, offsets)
    local fn = StaticFindObject(path)
    if not valid(fn) then log("SKIP", path .. " reason=not_loaded"); return false end
    local flags = fn:GetFunctionFlags()
    local fields = {}
    fn:ForEachProperty(function(property)
        local kind, field = property:GetFullName():match("^(%w+) .+:([^:]+)$")
        -- The Fire layout check uses FName semantics for parameter names.
        if offsets and field then field = field:lower() end
        local entry = tostring(kind) .. ":" .. tostring(field)
        if offsets then entry = entry .. "@" .. property:GetOffset_Internal() end
        fields[#fields + 1] = entry
    end)
    local shape = table.concat(fields, ",")
    if fn:GetFullName() ~= "Function " .. path
        or ((flags & 0x400) ~= 0) ~= native
        or ((flags & 0x2000) ~= 0) ~= static
        or (flags & 0x00400000) ~= 0
        or shape ~= expected then
        log("SKIP", path .. " reason=contract flags=" .. flags .. " fields=" .. shape)
        return false
    end
    log("CHECKED", path .. " flags=" .. flags .. " fields=" .. shape)
    return true
end

local function stop(reason)
    if mode then log("STOP", "mode=" .. mode .. " reason=" .. reason .. " events=" .. sequence) end
    mode = nil
end

local function cleanup()
    local remaining = {}
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, hook.path, hook.pre, hook.post)
        if not ok then
            remaining[#remaining + 1] = hook
            log("CLEANUP_FAILED", hook.path .. " " .. tostring(err):sub(1, 140))
        end
    end
    hooks = remaining
end

local function emit(event, detail)
    sequence = sequence + 1
    log(event, "mode=" .. mode .. " run=" .. generation .. " seq=" .. sequence
        .. " wall=" .. os.time() .. " " .. detail)
    if sequence >= 120 then stop("event_limit") end
end

local function guarded(fn)
    local run = generation
    return function(...)
        if not mode or generation ~= run then return end
        local ok, err = pcall(fn, ...)
        if not ok then stop("callback_error"); log("ERROR", tostring(err):sub(1, 180)) end
        -- Always return nil to UE4SS.
    end
end

local function attach(path, shape, post, pre, offsets, static)
    if not check(path, pre ~= nil, static == true, shape, offsets) then return end
    local a, b
    if pre then
        a, b = RegisterHook(path, guarded(pre), guarded(post))
    else
        a, b = RegisterHook(path, guarded(post))
    end
    hooks[#hooks + 1] = {path = path, pre = a, post = b}
    assert(type(a) == "number" and type(b) == "number" and a > 0 and b > 0
        and ((a ~= b) == (pre ~= nil)), "unexpected hook IDs: " .. path)
    log("HOOK", path .. " phase=" .. (pre and "native_pre/native_post" or "script_post"))
end

local function combat()
    assert(check(global .. "GetPlayerCharacter", true, true, "ObjectProperty:ReturnValue"), "player getter unavailable")
    assert(check(projectile .. "GetCharacterOwner", true, false, "ObjectProperty:ReturnValue"), "owner getter unavailable")
    local sampleSkill = check(global .. "GetDoingSkill", true, true, "ObjectProperty:Character,NameProperty:ReturnValue")
    local cdoPath = genesis .. "Default__GameGlobal"
    local cdo = StaticFindObject(cdoPath)
    assert(valid(cdo) and cdo:GetFullName() == "GameGlobal " .. cdoPath, "missing exact GameGlobal CDO")
    local player = cdo:GetPlayerCharacter()
    assert(derived(player, "GenesisCharacter") and name(player:GetClass()) == "hilda_BP_C", "load into playable Hilda first")
    local playerId = identity(player)
    -- Only scalar identities survive callback boundaries.
    local function currentPlayer()
        local live = StaticFindObject(cdoPath)
        if not valid(live) then stop("missing_game_global"); return end
        local owner = live:GetPlayerCharacter()
        if identity(owner) ~= playerId then stop("player_changed"); return end
        return owner, live
    end
    local function source(context, recordUnresolved)
        local object = context:get()
        if not valid(object) then return end
        local cls = name(object:GetClass())
        if not cls:match("^hilda_staff_") and cls ~= "hilda_dual_atk_C" then return end
        if not derived(object, "BaseProjectile") then return end
        local owner, live = currentPlayer()
        if not owner then return end
        local sourceOwner = identity(object:GetCharacterOwner())
        if sourceOwner == playerId then return object, owner, live end
        if recordUnresolved and sourceOwner == "none" then
            emit("SOURCE_OWNER_UNRESOLVED", "phase=script_post source=" .. identity(object))
        end
    end
    for _, event in ipairs({"BeginSkillStateEvent", "EndSkillStateEvent"}) do
        attach(genesis .. "GenesisCharacter:" .. event, "NameProperty:Skill", function(context, skill)
            if identity(context:get()) == playerId and currentPlayer() then
                local value = skill:get():ToString()
                if value:match("^hilda_staff_") or value:match("^hilda_dual_")
                    or value:match("^mod2_hilda_staff_") or value:match("^hilda_ult_com05") then
                    emit(event, "phase=script_post player=" .. playerId .. " skill=" .. string.format("%q", value))
                end
            end
        end)
    end
    for _, asset in ipairs({"hilda_staff_bolt_astral", "hilda_staff_bolt_fire",
        "hilda_staff_arrow", "hilda_staff_arrow_damage", "hilda_staff_atk4_astral_hit", "hilda_dual_atk"}) do
        attach(assets .. asset .. "." .. asset .. "_C:ReceiveBeginPlay", "", function(context)
            local object, owner, live = source(context, true)
            if not object then return end
            local skill = sampleSkill and live:GetDoingSkill(owner):ToString() or "unavailable"
            emit("SOURCE_BEGIN", "phase=script_post source=" .. identity(object) .. " player=" .. playerId
                .. " skill_at_sample=" .. string.format("%q", skill))
        end)
    end
    attach(projectile .. "CharacterHitted",
        "FloatProperty:damageValue,BoolProperty:defended,BoolProperty:knockBreak,BoolProperty:knockDown",
        function(context, damage, defended, broken, down)
            local object = source(context)
            if object then
                emit("HIT_NOTIFICATION", "phase=script_post source=" .. identity(object)
                    .. " damage=" .. tostring(damage:get()) .. " defended=" .. tostring(defended:get())
                    .. " break=" .. tostring(broken:get()) .. " down=" .. tostring(down:get()))
            end
        end)
    local function rate(phase)
        return function(context)
            local object = source(context)
            if object then emit("RATE_CALL", "phase=" .. phase .. " source=" .. identity(object)) end
        end
    end
    attach(projectile .. "GetBaseDamageRate", "FloatProperty:ReturnValue", rate("native_post"), rate("native_pre"))
end

local function rest()
    assert(type(IsInGameThread) == "function" and IsInGameThread(), "rest preflight outside game thread")
    local root = "/Game/MainContent/Template/BaseBlueprint/"
    local hud = "/Game/uiresources/GTGameHUDBPLocal.GTGameHUDBPLocal_C:"
    local function marker(event)
        return function(context)
            if not IsInGameThread() then stop("wrong_thread"); return end
            emit(event, "phase=script_post owner=" .. identity(context:get()))
        end
    end
    attach(hud .. "EventShowSavePointList", "NameProperty:DataName,StrProperty:DebugPointName", marker("MENU_OPEN"))
    attach(scene .. "Interact_Rest", "", marker("REST_REQUEST"))
    attach(scene .. "Interact_Transport", "NameProperty:SavePointRowName", marker("TRANSPORT"))
    attach(scene .. "Interact_EndUse", "", marker("MENU_EXIT"))
    attach(root .. "MainGameInstance_BP.MainGameInstance_BP_C:RecoverPlayerAndScene", "", marker("RECOVERY"))
    attach(hud .. "EventOnRestEnd", "", marker("REST_END"))
    -- Only __WorldContext is a parameter. ForEachProperty also enumerates the local.
    attach(root .. "GameGlobalBlueprintLibrary.GameGlobalBlueprintLibrary_C:RecoverPlayerAndScene",
        "ObjectProperty:__WorldContext,ObjectProperty:CallFunc_GetGenesisGameInstance_ReturnValue",
        function(context, worldContext)
            if not IsInGameThread() then stop("wrong_thread"); return end
            emit("RECOVERY_CONTEXT", "phase=script_post owner=" .. identity(context:get())
                .. " world_context=" .. identity(worldContext:get()))
        end, nil, nil, true)
    assert(#hooks == 7, "incomplete rest contract; load gameplay near Conduit and retry")
end

local function fire()
    assert(type(IsInGameThread) == "function" and IsInGameThread(), "Fire preflight outside game thread")
    local playerGetter = global .. "GetPlayerCharacter"
    assert(check(playerGetter, true, true, "ObjectProperty:ReturnValue"), "player getter unavailable")
    assert(check(projectile .. "GetCharacterOwner", true, false, "ObjectProperty:ReturnValue"), "character owner getter unavailable")
    assert(check("/Script/Engine.Actor:GetOwner", true, false, "ObjectProperty:ReturnValue"), "actor owner getter unavailable")
    local cdoPath = genesis .. "Default__GameGlobal"
    local boltPath = assets .. "hilda_staff_bolt_fire.hilda_staff_bolt_fire_C"
    local spherePath = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_200.sphere_200_C"
    local boltKey, explosionKey = "hilda_staff_bolt_fire", "hilda_staff_bolt_fire_explosion"
    local cdo = StaticFindObject(cdoPath)
    assert(valid(cdo) and cdo:GetFullName() == "GameGlobal " .. cdoPath, "missing exact GameGlobal CDO")
    local player = cdo:GetPlayerCharacter()
    assert(derived(player, "GenesisCharacter") and name(player:GetClass()) == "hilda_BP_C", "load into playable Hilda first")
    local playerId = identity(player)

    local function exact(object, path)
        return valid(object) and object:GetClass():GetFullName():match("^[^ ]+ (.+)$") == path
    end

    local function row(object)
        local value = object.ProjectileDataName
        return value and value:ToString() or "unavailable"
    end

    local hitPath = "/Game/MainContent/Template/BaseBlueprint/BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
    local shape = "ObjectProperty:projectile@0,ObjectProperty:hitcomponent@8,StructProperty:hitposition@16,FloatProperty:damage@28"
    attach(hitPath, shape, function(context, sourceParam, _hitComponent, _hitPosition, damageParam)
        if not IsInGameThread() then stop("wrong_thread"); return end
        local target = context:get()
        if not derived(target, "BaseAICharacter_Mob_BP_C") then return end
        local object = sourceParam:get()
        local isSphere = exact(object, spherePath)
        if not isSphere and not exact(object, boltPath) then return end
        local key = row(object)
        local actorOwner = object:GetOwner()
        local parentKey = exact(actorOwner, boltPath) and row(actorOwner) or "none"
        if (isSphere and key ~= explosionKey and parentKey ~= boltKey)
            or (not isSphere and key ~= boltKey) then return end
        local live = StaticFindObject(cdoPath)
        if not valid(live) or identity(live:GetPlayerCharacter()) ~= playerId then
            stop("player_changed")
            return
        end
        local actorOwnerId = identity(actorOwner)
        local characterOwner = identity(object:GetCharacterOwner())
        local parentCharacterOwner = parentKey ~= "none" and identity(actorOwner:GetCharacterOwner()) or "none"
        local matched = characterOwner == playerId and (
            (isSphere and key == explosionKey and parentKey == boltKey and parentCharacterOwner == playerId)
            or (not isSphere and actorOwnerId == playerId))
        local damage = damageParam:get()
        assert(type(damage) == "number" and math.abs(damage) < math.huge, "non-finite notified damage")
        emit("FIRE_HIT",
            "phase=script_post kind=" .. (isSphere and "explosion" or "bolt")
            .. " class=" .. (isSphere and spherePath or boltPath)
            .. " source=" .. identity(object) .. " target=" .. identity(target)
            .. " row=" .. string.format("%q", key) .. " actor_owner=" .. actorOwnerId
            .. " parent_row=" .. string.format("%q", parentKey)
            .. " character_owner=" .. characterOwner .. " parent_character_owner=" .. parentCharacterOwner
            .. " player=" .. playerId .. " matched=" .. tostring(matched)
            .. " notified_damage=" .. tostring(damage))
    end, nil, true)
    assert(#hooks == 1, "exact mob ProjectileHitEvent unavailable")
end

local function start(requested)
    if mode then log("BUSY", "mode=" .. mode); return end
    cleanup()
    if #hooks ~= 0 then log("UNAVAILABLE", "restart_required=cleanup_failed"); return end
    generation, sequence = generation + 1, 0
    local run = generation
    mode = requested
    local ok, err = pcall(function()
        if requested == "fire" then fire()
        elseif requested == "combat" then combat()
        else rest() end
        assert(#hooks > 0, "no compatible loaded observation points")
        ExecuteInGameThreadWithDelay(requested == "fire" and 45000 or requested == "combat" and 120000 or 90000, function()
            if generation == run then stop("deadline"); cleanup() end
        end)
    end)
    if ok then log("CAPTURE", "mode=" .. mode .. " hooks=" .. #hooks)
    else stop("preflight"); log("ERROR", tostring(err):sub(1, 180)); cleanup() end
end

-- Trace delivery, scheduling and execution separately; registration alone proves none of them.
local function dispatch(keyName, action)
    log("KEY_CALLBACK", "key=" .. keyName)
    local ok, err = pcall(ExecuteInGameThread, function()
        log("ENGINE_TICK_ENTRY", "key=" .. keyName)
        action()
    end, EGameThreadMethod.EngineTick)
    if ok then
        -- Only means ExecuteInGameThread returned; execution is proved by ENGINE_TICK_ENTRY.
        log("DISPATCH_RETURNED", "key=" .. keyName .. " method=EngineTick")
    else
        stop("dispatch")
        log("ERROR", "key=" .. keyName .. " " .. tostring(err):sub(1, 180))
    end
end

local ok, err = pcall(function()
    assert(EngineTickAvailable == true and type(EGameThreadMethod.EngineTick) == "number", "EngineTick unavailable")
    for _, api in ipairs({"StaticFindObject", "RegisterHook", "UnregisterHook", "RegisterKeyBind",
        "IsKeyBindRegistered", "ExecuteInGameThread", "ExecuteInGameThreadWithDelay"}) do
        assert(type(_G[api]) == "function", "missing API " .. api)
    end
    local modifiers = {ModifierKey.CONTROL, ModifierKey.SHIFT}
    for _, key in ipairs({Key.F8, Key.F9, Key.F10}) do
        assert(type(key) == "number" and not IsKeyBindRegistered(key, modifiers), "key collision")
    end
    RegisterKeyBind(Key.F8, modifiers, function() dispatch("F8", function() start("combat") end) end)
    RegisterKeyBind(Key.F9, modifiers, function() dispatch("F9", function() start("rest") end) end)
    RegisterKeyBind(Key.F10, modifiers, function() dispatch("F10", function() stop("user"); cleanup() end) end)

    -- Diagnostic alternative: distinguish bare key delivery from CTRL+SHIFT chord handling.
    -- An unavailable bare key never prevents the original chord registrations.
    local function registerBare(name, action)
        local key = Key[name]
        if type(key) ~= "number" then
            log("BARE_KEY_UNAVAILABLE", "key=" .. name .. " reason=missing_key")
            return
        end
        local registered, reason = pcall(function()
            if IsKeyBindRegistered(key) then
                log("BARE_KEY_UNAVAILABLE", "key=" .. name .. " reason=already_registered")
                return
            end
            RegisterKeyBind(key, function() dispatch(name, action) end)
            log("BARE_KEY_REGISTERED", "key=" .. name)
            return true
        end)
        if not registered then
            log("BARE_KEY_UNAVAILABLE", "key=" .. name .. " reason=" .. tostring(reason):sub(1, 120))
        end
        return registered and reason == true
    end
    local restStopAvailable = registerBare("F7", function() stop("user"); cleanup() end)
    if restStopAvailable then registerBare("F4", function() start("rest") end) end

    -- One-shot independent scheduler check even if no key callback is delivered.
    local tickOk, tickErr = pcall(ExecuteInGameThread, function()
        log("ENGINE_TICK_PING_ENTRY", "source=startup")
    end, EGameThreadMethod.EngineTick)
    if tickOk then
        log("ENGINE_TICK_PING_RETURNED", "source=startup")
    else
        log("ENGINE_TICK_PING_ERROR", tostring(tickErr):sub(1, 180))
    end
end)
if ok then log("ARMED", "F4=rest F7=stop (see BARE_KEY_*); CtrlShiftF8=combat CtrlShiftF9=rest CtrlShiftF10=stop")
else log("UNAVAILABLE", tostring(err):sub(1, 180)) end
