-- SPDX-License-Identifier: MPL-2.0
-- Run with Lua 5.4: lua tests.lua StaffRebalanceReserveSlice/Scripts/main.lua
local path = assert(arg[1])
local assets = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local astral = assets .. "hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local daggers = assets .. "hilda_dual_atk.hilda_dual_atk_C"
local root = "/Game/MainContent/Template/BaseBlueprint/"
local hit = root .. "BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local conduit = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local recovery = root .. "MainGameInstance_BP.MainGameInstance_BP_C:RecoverPlayerAndScene"
local context = root .. "GameGlobalBlueprintLibrary.GameGlobalBlueprintLibrary_C:RecoverPlayerAndScene"
local begin = astral .. ":ReceiveBeginPlay"
local global = "/Script/Genesis.Default__GameGlobal"

local function object(name, address, className, classPath, fullName)
    return {
        IsValid = function() return true end,
        GetAddress = function() return address end,
        GetFullName = function() return fullName or name end,
        GetClass = function()
            return {
                GetFullName = function() return "BlueprintGeneratedClass " .. classPath end,
                GetFName = function() return {ToString = function() return className end} end,
            }
        end,
    }
end

local function parameter(value)
    return {get = function() return value end}
end

local function setup(options)
    options = options or {}
    local e = setmetatable({}, {__index = _G})
    e._G = e
    local keys, hooks, lines, functions = {}, {}, {}, {}
    local pawn = object("Hilda", 1, "hilda_BP_C")
    local cdo = object("GameGlobal", 2, nil, nil, "GameGlobal " .. global)
    functions[global] = cdo
    cdo.GetPlayerCharacter = function() return pawn end
    cdo.GetDoingSkill = function() return {ToString = function() return options.skill or "hilda_staff_atk1" end} end
    local function property(name, offset)
        return {GetFullName = function() return name end, GetOffset_Internal = function() return offset end}
    end
    local function reflected(name, flags, properties)
        local fn = object(name, 0, nil, nil, "Function " .. name)
        fn.GetFunctionFlags = function() return flags end
        fn.ForEachProperty = function(_, callback)
            for _, prop in ipairs(properties or {}) do callback(prop) end
        end
        functions[name] = fn
    end
    local result = property("ObjectProperty Owner:ReturnValue")
    reflected("/Script/Genesis.GameGlobal:GetPlayerCharacter", 0x2400, {result})
    reflected("/Script/Genesis.GameGlobal:GetDoingSkill", 0x2400,
        {property("ObjectProperty Owner:Character"), property("NameProperty Owner:ReturnValue")})
    reflected("/Script/Genesis.BaseProjectile:GetCharacterOwner", 0x400, {result})
    reflected(begin, 0)
    reflected(hit, 0, {
        property("ObjectProperty Owner:Projectile", 0), property("ObjectProperty Owner:HitComponent", 8),
        property("StructProperty Owner:HitPosition", 16), property("FloatProperty Owner:Damage", options.badShape and 32 or 28),
    })
    reflected(conduit .. "Interact_Rest", 0)
    reflected(conduit .. "Interact_EndUse", 0)
    reflected(conduit .. "Interact_Transport", 0, {property("NameProperty Owner:SavePointRowName")})
    reflected(recovery, 0)
    reflected(context, 0x2000, {property("ObjectProperty Owner:__WorldContext"),
        property("ObjectProperty Owner:CallFunc_GetGenesisGameInstance_ReturnValue")})

    e.StaticFindObject = function(name) return functions[name] end
    e.EngineTickAvailable = true
    e.EGameThreadMethod = {EngineTick = 1}
    e.Key = {F4 = 4, F7 = 7}
    e.IsKeyBindRegistered = function(key) return options.collision and key == 4 or false end
    e.RegisterKeyBind = function(key, callback) keys[key] = callback end
    e.ExecuteInGameThread = function(callback, method) assert(method == 1); callback() end
    e.IsInGameThread = function() return not options.wrongThread end
    e.RegisterHook = function(name, callback)
        if options.registrationError and name == hit then error("registration failed") end
        hooks[name] = callback
        return 4, 4
    end
    e.UnregisterHook = function(name) hooks[name] = nil end
    e.print = function(line) lines[#lines + 1] = line end

    local function source(name, classPath, key, owner)
        local s = object(name, 20, nil, classPath)
        s.ProjectileDataName = {ToString = function() return key end}
        s.GetCharacterOwner = function() return owner or pawn end
        s.rate = 0.875
        s.GetPropertyValue = function(_, field) return field == "DamageRate" and s.rate or options.saved or 0 end
        s.SetPropertyValue = function(_, field, value)
            assert(field == "DamageRate")
            s.rate = value
            if options.writeError and value ~= 0.875 then error("partial write") end
        end
        s.Reflection = function()
            return {GetProperty = function(_, field) return property("FloatProperty Owner:" .. field, 0x2C4) end}
        end
        return s
    end

    assert(loadfile(path, "t", e))()
    return {
        keys = keys,
        hooks = hooks,
        has = function(fragment) return table.concat(lines):find(fragment, 1, true) end,
        count = function(event)
            local _, count = table.concat(lines):gsub("STAFF_RESERVE01 " .. event .. " ", "")
            return count
        end,
        bolt = function(name, owner) return source(name, astral, "hilda_staff_bolt_astral", owner) end,
        otherBolt = function(name) return source(name, astral, "other_astral_key") end,
        setSkill = function(value) options.skill = value end,
        setSaved = function(value) options.saved = value end,
        blade = function(name, owner) return source(name, daggers, "hilda_dual_attack_astral", owner) end,
        emit = function(name, ...) hooks[name](...) end,
    }
end

local function shot(test, name)
    local bolt = test.bolt(name)
    test.emit(begin, parameter(bolt))
    return bolt
end

local target = parameter(object("MobA", 40, "m052_arvicolina_BP_C"))
local other = parameter(object("MobB", 41, "m052_arvicolina_BP_C"))
local neutral = parameter(object("Other", 42, "other_BP_C"))
local point = parameter(object("ConduitA", 50))
local wrongPoint = parameter(object("ConduitB", 51))
local game = parameter(object("MainGameInstance", 52))
local function contact(test, blade, enemy)
    test.emit(hit, enemy, parameter(blade), nil, nil, parameter(0))
end

for _, skill in ipairs({"hilda_staff_atk1", "hilda_staff_atk1_idle"}) do
    local t = setup({skill = skill})
    assert(not next(t.hooks))
    t.keys[4]()
    assert(t.has("START reserve=3 hooks=7"))
    assert(t.count("SHOT") == 0)
    assert(shot(t, "One").rate == 0.875 and t.count("SHOT") == 1)
    assert(shot(t, "Two").rate == 0.875 and shot(t, "Three").rate == 0.875)
    assert(t.has("mode=strong before=1 reserve=0"))
    local weak = shot(t, "Four")
    assert(weak.rate == 0.4375 and t.has("mode=weak before=0 reserve=0"))
    contact(t, weak, target)
    assert(t.has("ASTRAL_HIT mode=weak"))
    local blade = t.blade("First")
    contact(t, blade, neutral)
    contact(t, t.blade("Foreign", object("ForeignOwner", 90)), target)
    assert(t.count("MELEE") == 0)
    contact(t, blade, target)
    contact(t, blade, target)
    assert(t.has("MELEE before=0 reserve=1") and t.has("DUPLICATE reserve=1"))
    assert(shot(t, "Five").rate == 0.875 and t.has("mode=strong before=1 reserve=0"))
    t.emit(conduit .. "Interact_EndUse", point)
    t.emit(recovery, game); t.emit(context, nil, point)
    assert(t.count("REST") == 0 and t.has("MENU_EXIT reserve=0"))
    t.emit(conduit .. "Interact_Rest", point)
    t.emit(recovery, game); t.emit(context, nil, wrongPoint)
    assert(t.count("REST") == 0)
    t.emit(conduit .. "Interact_Rest", point)
    t.emit(recovery, game); t.emit(conduit .. "Interact_Transport")
    t.emit(context, nil, point)
    assert(t.count("REST") == 0)
    t.emit(conduit .. "Interact_Rest", point)
    t.emit(context, nil, point)
    assert(t.count("REST") == 0)
    t.emit(conduit .. "Interact_Rest", point)
    t.emit(recovery, game); t.emit(context, nil, point); t.emit(context, nil, point)
    assert(t.count("REST") == 1 and t.has("REST before=0 reserve=3"))
    for i = 6, 8 do shot(t, "Shot" .. i) end
    contact(t, blade, other)
    contact(t, t.blade("Second phase"), target)
    contact(t, t.blade("Third"), target)
    contact(t, t.blade("Fourth"), target)
    assert(t.has("MELEE before=2 reserve=3") and t.has("MELEE before=3 reserve=3"))
    t.keys[7](); assert(not next(t.hooks) and t.has("STOP reserve=3 hooks_remaining=0"))
    t.keys[4](); assert(not next(t.hooks))
end

do
    local t = setup({skill = "hilda_staff_atk2"})
    t.keys[4]()
    assert(shot(t, "Unsupported").rate == 0.875)
    assert(t.count("SHOT") == 0 and t.has("SKIP reason=unsupported_astral_skill"))
    t.setSkill("hilda_staff_atk1")
    assert(shot(t, "Supported").rate == 0.875)
    assert(t.has("mode=strong before=3 reserve=2"))
    t.keys[7]()
end
do
    local t = setup({saved = 1})
    t.keys[4]()
    assert(shot(t, "e804").rate == 0.875)
    assert(t.count("SHOT") == 0 and t.has("SKIP reason=unverified_e804"))
    t.setSaved(0)
    assert(shot(t, "Supported").rate == 0.875)
    assert(t.has("mode=strong before=3 reserve=2"))
    t.keys[7]()
end

for _, skill in ipairs({"hilda_staff_atk1", "hilda_staff_atk1_idle"}) do
    local t = setup({skill = skill})
    t.keys[4]()
    local first = t.bolt("First")
    t.emit(begin, parameter(first))
    assert(first.rate == 0.875 and t.has("skill=" .. skill .. " mode=strong before=3 reserve=2"))
    t.emit(begin, parameter(first))
    assert(t.count("SHOT") == 1 and t.has("SKIP reason=duplicate_source"))
    assert(shot(t, "Second").rate == 0.875)
    assert(t.count("SHOT") == 2 and t.has("mode=strong before=2 reserve=1"))
    t.emit(begin, parameter(t.otherBolt("Unrelated")))
    t.emit(begin, parameter(t.bolt("Foreign", object("OtherOwner", 88))))
    assert(t.count("SHOT") == 2 and t.has("SKIP reason=foreign_astral_owner")
        and t.has("SKIP reason=unsupported_astral_row"))
    assert(shot(t, "Third").rate == 0.875)
    assert(shot(t, "Fourth").rate == 0.4375)
    assert(t.count("SHOT") == 4 and t.has("mode=weak before=0 reserve=0"))
    t.keys[7](); assert(not next(t.hooks))
end

do
    local t = setup({writeError = true})
    t.keys[4]()
    for i = 1, 3 do shot(t, "Strong" .. i) end
    assert(shot(t, "Rollback").rate == 0.875)
    assert(t.count("SHOT") == 3 and t.has("ROLLBACK_OK") and t.has("FAILED"))
end

for _, options in ipairs({{badShape = true}, {registrationError = true}, {wrongThread = true}}) do
    local t = setup(options)
    t.keys[4]()
    assert(not next(t.hooks) and not t.has("START"))
end
do
    local t = setup({collision = true})
    assert(not next(t.keys) and not next(t.hooks) and t.has("key_collision"))
end
print("PASS: reserve cycle, scope, dedup, rest guards, failures, cleanup")
