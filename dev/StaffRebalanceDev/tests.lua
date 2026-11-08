-- SPDX-License-Identifier: MPL-2.0
-- Run with Lua 5.4: lua dev/StaffRebalanceDev/tests.lua dev/StaffRebalanceDev/Scripts/main.lua
local path = assert(arg[1])
local assets = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local astral = assets .. "hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local fireBolt = assets .. "hilda_staff_bolt_fire.hilda_staff_bolt_fire_C"
local fireSphere = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_200.sphere_200_C"
local fireBegin = fireBolt .. ":ReceiveBeginPlay"
local fireSphereBegin = fireSphere .. ":ReceiveBeginPlay"
local daggers = assets .. "hilda_dual_atk.hilda_dual_atk_C"
local otherMelee = {
    daggers_plus = {assets .. "hilda_dual_atk_plus.hilda_dual_atk_plus_C", "hilda_dual_atk_plus_astral"},
    bracelets_3 = {assets .. "hilda_bracelet_atk3.hilda_bracelet_atk3_C", "hilda_bracelet_atk3_astral"},
    bracelets_4 = {assets .. "hilda_bracelet_atk4.hilda_bracelet_atk4_C", "hilda_bracelet_atk4_astral"},
    spear = {assets .. "hilda_spear.hilda_spear_C", "hilda_spear_astral"},
    hammer = {assets .. "hilda_cudgel_fire.hilda_cudgel_fire_C", "hilda_cudgel_astral"},
    sword_shield = {assets .. "hilda_sword_atk.hilda_sword_atk_C", "hilda_sword_attack_astral"},
    bracelets = {assets .. "hilda_bracelet_atk1.hilda_bracelet_atk1_C", "hilda_bracelet_astral"},
}
local root = "/Game/MainContent/Template/BaseBlueprint/"
local hit = root .. "BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local conduit = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local recovery = root .. "MainGameInstance_BP.MainGameInstance_BP_C:RecoverPlayerAndScene"
local context = root .. "GameGlobalBlueprintLibrary.GameGlobalBlueprintLibrary_C:RecoverPlayerAndScene"
local begin = astral .. ":ReceiveBeginPlay"
local nativeBegin = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local nativeEnd = "/Script/Genesis.BaseCharacterAnimInstance:EndDoSkill"
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
    local anim = object("HildaAnim", 3, nil, "/Game/MainContent/Assets/creature/01_character/hilda/hilda_AnimBP.hilda_AnimBP_C")
    anim.doing = "None"
    anim.GetDoingSkill = function() return {ToString = function() return anim.doing end} end
    local mesh = object("HildaMesh", 4)
    mesh.GetOwner = function() return pawn end
    mesh.GetAnimInstance = function() return anim end
    pawn.Mesh = mesh
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
    reflected("/Script/Engine.Actor:GetOwner", 0x400, {result})
    reflected(begin, 0)
    if not options.missingFire then
        reflected(fireBegin, 0)
        reflected(fireSphereBegin, 0)
    end
    reflected(nativeBegin, 0x400)
    reflected(nativeEnd, 0x400)
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
    e.RegisterHook = function(name, callback, post)
        if options.registrationError and name == hit then error("registration failed") end
        hooks[name] = {pre = post and callback or nil, post = post or callback}
        if post then return 10, 11 end
        return 4, 4
    end
    e.UnregisterHook = function(name) hooks[name] = nil end
    e.print = function(line) lines[#lines + 1] = line end

    local function source(name, classPath, key, owner, initialRate)
        local s = object(name, 20, nil, classPath)
        s.ProjectileDataName = {ToString = function() return key end}
        s.GetCharacterOwner = function() return owner or pawn end
        s.rate = initialRate or 0.875
        s.initial = s.rate
        s.GetPropertyValue = function(_, field) return field == "DamageRate" and s.rate or options.saved or 0 end
        s.SetPropertyValue = function(_, field, value)
            assert(field == "DamageRate")
            s.rate = value
            if options.writeError and value ~= s.initial then error("partial write") end
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
        melee = function(name, kind, owner, row)
            local spec = assert(otherMelee[kind], kind)
            return source(name, spec[1], row or spec[2], owner)
        end,
        fireBolt = function(name, owner, key)
            return source(name, fireBolt, key or "hilda_staff_bolt_fire", owner)
        end,
        fireSphere = function(name, parent, owner, key)
            local s = source(name, fireSphere, key or "hilda_staff_bolt_fire_explosion", owner, 0.9)
            s.GetOwner = function() return parent end
            return s
        end,
        emit = function(name, ...) assert(hooks[name], name).post(...) end,
        beginStep = function(skill)
            anim.doing = "None"
            assert(hooks[nativeBegin], "missing BeginDoSkill").pre(parameter(anim))
            anim.doing = skill
            options.skill = skill
            hooks[nativeBegin].post(parameter(anim))
        end,
        endStep = function()
            assert(hooks[nativeEnd], "missing EndDoSkill").pre(parameter(anim))
            anim.doing = "None"
            hooks[nativeEnd].post(parameter(anim))
            options.skill = "None"
        end,
        emptyEnd = function()
            anim.doing = "None"
            hooks[nativeEnd].pre(parameter(anim))
        end,
    }
end

local function shot(test, name)
    local bolt = test.bolt(name)
    test.emit(begin, parameter(bolt))
    return bolt
end

local target = parameter(object("MobA", 40, "m052_arvicolina_BP_C"))
local other = parameter(object("MobB", 41, "m006_2_thugdagger_BP_C"))
-- World objects are not receivers of the mob-specific hit hook.
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
    assert(t.has("START reserve=3 hooks=11"))
    assert(t.count("SHOT") == 0)
    assert(shot(t, "One").rate == 0.875 and t.count("SHOT") == 1)
    assert(shot(t, "Two").rate == 0.875 and shot(t, "Three").rate == 0.875)
    assert(t.has("mode=strong before=1 reserve=0"))
    local weak = shot(t, "Four")
    assert(weak.rate == 0.4375 and t.has("mode=weak before=0 reserve=0"))
    contact(t, weak, target)
    assert(t.has("ASTRAL_HIT mode=weak"))
    local blade = t.blade("First")
    -- A scene hit cannot enter the mob-receiver callback; runtime verification is still required.
    assert(t.hooks[hit] ~= nil)
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
    contact(t, blade, other) -- Different mob Blueprint class, same dagger source.
    assert(t.has("MELEE before=0 reserve=1"))
    contact(t, t.blade("Second phase"), target)
    contact(t, t.blade("Third"), target)
    contact(t, t.blade("Fourth"), target)
    assert(t.has("MELEE before=2 reserve=3") and t.has("MELEE before=3 reserve=3"))
    t.keys[7](); assert(not next(t.hooks) and t.has("STOP reserve=3 hooks_remaining=0"))
    t.keys[4](); assert(not next(t.hooks))
end

-- Live-confirmed first melee classes and statically mapped combo class/row pairs.
-- All callbacks below are synthetic; combo integration must be tested in-game.
for _, case in ipairs({
    {"spear", "spear"}, {"hammer", "hammer"}, {"sword_shield", "sword_shield"},
    {"bracelets", "bracelets"}, {"daggers_plus", "daggers"},
    {"bracelets_3", "bracelets"}, {"bracelets_4", "bracelets"}
}) do
    local kind, expectedWeapon = case[1], case[2]
    local t = setup({skill = "hilda_staff_atk1"})
    t.keys[4]()
    for i = 1, 3 do shot(t, kind .. "Drain" .. i) end
    assert(t.has("mode=strong before=1 reserve=0"))
    local first = t.melee(kind .. "First", kind)
    contact(t, first, target)
    assert(t.count("MELEE") == 1 and t.has("MELEE before=0 reserve=1")
        and t.has("weapon=" .. expectedWeapon))
    contact(t, first, target) -- Bracelet repeated callback: do not double-credit one source-target pair.
    assert(t.count("MELEE") == 1 and t.has("DUPLICATE reserve=1"))
    contact(t, t.melee(kind .. "WrongRow", kind, nil, "other_melee_row"), target)
    contact(t, t.melee(kind .. "Foreign", kind, object("ForeignOwner", 91)), target)
    assert(t.count("MELEE") == 1)
    contact(t, first, other) -- Different target of the same source is a separate pair.
    assert(t.count("MELEE") == 2 and t.has("MELEE before=1 reserve=2"))
    contact(t, t.melee(kind .. "NextSource", kind), target)
    assert(t.count("MELEE") == 3 and t.has("MELEE before=2 reserve=3"))
    contact(t, t.melee(kind .. "OverCap", kind), target)
    assert(t.count("MELEE") == 4 and t.has("MELEE before=3 reserve=3"))
    contact(t, t.bolt(kind .. "StaffNegative"), target)
    assert(t.count("MELEE") == 4)
    t.keys[7]()
    assert(not next(t.hooks) and t.has("STOP reserve=3 hooks_remaining=0"))
end

do
    local t = setup({skill = "hilda_staff_atk2"})
    t.keys[4]()
    assert(shot(t, "No native Begin").rate == 0.875)
    assert(t.count("SHOT") == 0 and t.has("SKIP reason=unverified_combo_boundary"))
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
-- New dev-only coverage. Historical Reserve Slice 01 remains unchanged.
do
    local t = setup()
    t.keys[4]()
    -- One earlier first-step bolt leaves exactly one charge.
    shot(t, "FirstOne")
    shot(t, "FirstTwo")
    t.beginStep("hilda_staff_atk2")
    local a, b = shot(t, "A2-1"), shot(t, "A2-2")
    assert(a.rate == 0.875 and b.rate == 0.875)
    assert(t.has("skill=hilda_staff_atk2 mode=strong before=1 reserve=0"))
    assert(t.has("skill=hilda_staff_atk2 mode=strong before=0 reserve=0"))
    t.endStep()
    t.beginStep("hilda_staff_atk3")
    local c, d, e = shot(t, "A3-1"), shot(t, "A3-2"), shot(t, "A3-3")
    assert(c.rate == 0.4375 and d.rate == 0.4375 and e.rate == 0.4375)
    assert(t.has("skill=hilda_staff_atk3 mode=weak before=0 reserve=0"))
    t.endStep()
    t.emptyEnd() -- Vanilla extra End(doing=None) must not reopen or debit.
    assert(t.count("SHOT") == 7 and t.count("COMBO_BEGIN") == 2 and t.count("COMBO_END") == 2)
    contact(t, t.blade("Restore"), target)
    t.beginStep("hilda_staff_atk2")
    assert(shot(t, "B2-1").rate == 0.875 and shot(t, "B2-2").rate == 0.875)
    t.endStep()
    t.keys[7]()
    assert(not next(t.hooks) and t.has("STOP") and t.has("hooks_remaining=0"))
end
do
    local t = setup()
    t.keys[4]()
    t.beginStep("hilda_staff_atk2")
    t.endStep() -- No bolt: no debit.
    assert(t.count("SHOT") == 0 and t.has("mode=no_bolt"))
    t.beginStep("hilda_staff_atk3")
    local foreign = t.bolt("Foreign", object("ForeignOwner", 87))
    t.emit(begin, parameter(foreign))
    assert(t.count("SHOT") == 0)
    local first = t.bolt("Actual")
    t.emit(begin, parameter(first)); t.emit(begin, parameter(first))
    assert(t.count("SHOT") == 1 and t.has("SKIP reason=duplicate_source"))
    assert(shot(t, "More").rate == 0.875 and shot(t, "Last").rate == 0.875)
    assert(t.count("SHOT") == 3 and t.has("reserve=2"))
    t.endStep()
    t.beginStep("hilda_staff_atk2")
    assert(shot(t, "NewRepeat").rate == 0.875 and t.has("skill=hilda_staff_atk2 mode=strong before=2 reserve=1"))
    t.endStep()
    t.keys[7]()
end
do
    local t = setup()
    t.keys[4]()
    t.beginStep("hilda_staff_atk2")
    t.setSkill("hilda_staff_atk3")
    assert(shot(t, "Wrong-skill").rate == 0.875 and t.count("SHOT") == 0)
    t.setSkill("hilda_staff_atk2")
    t.setSaved(1)
    assert(shot(t, "e804-first").rate == 0.875 and t.has("SKIP reason=unverified_e804"))
    t.setSaved(0)
    assert(shot(t, "e804-later").rate == 0.875 and t.count("SHOT") == 0
        and t.has("SKIP reason=unverified_e804_combo"))
    t.endStep()
    t.beginStep("hilda_staff_atk2")
    assert(shot(t, "Next-valid").rate == 0.875 and t.has("mode=strong before=3 reserve=2"))
    t.endStep()
    t.keys[7]()
end
-- Fire changes stay isolated in these dev-only tests. Real UE4SS integration is a separate gate.
do
    local t = setup({missingFire = true})
    t.keys[4]()
    assert(t.has("FIRE_UNAVAILABLE reason=missing:"))
    assert(t.has("START reserve=3 hooks=9 fire=unavailable"))
    assert(shot(t, "AstralWithFireClassUnloaded").rate == 0.875)
    assert(t.has("mode=strong before=3 reserve=2"))
    t.keys[7]()
    assert(not next(t.hooks))
end
do
    local t = setup()
    t.keys[4]()
    local skills = {"hilda_staff_atk1_idle_fire", "hilda_staff_atk2_fire", "hilda_staff_atk3_fire"}
    local bolts = {}
    for i, skill in ipairs(skills) do
        t.beginStep(skill)
        local b = t.fireBolt("FireBolt" .. i)
        bolts[i] = b
        t.emit(fireBegin, parameter(b))
        assert(t.has("FIRE_BOLT skill=" .. skill .. " mode=strong"))
        t.endStep()
    end
    assert(t.has("skill=hilda_staff_atk3_fire mode=strong before=1 reserve=0"))
    assert(t.count("FIRE_BOLT") == 3)
    -- First-step Fire explosion arrives after End and after step 2/3 has run.
    for i, b in ipairs(bolts) do
        local sphere = t.fireSphere("FireSphere" .. i, b)
        t.emit(fireSphereBegin, parameter(sphere))
        assert(sphere.rate == 0.9)
        t.emit(hit, target, parameter(sphere), nil, nil, parameter(90.72))
    end
    assert(t.count("FIRE_SPHERE") == 3 and t.count("FIRE_HIT") == 3)
    assert(t.has("FIRE_HIT mode=fire_strong"))
    t.beginStep("hilda_staff_atk1_fire")
    local weakBolt = t.fireBolt("WeakFireBolt")
    t.emit(fireBegin, parameter(weakBolt))
    t.endStep()
    t.beginStep("hilda_staff_atk2_fire")
    local nextBolt = t.fireBolt("NextFireBolt")
    t.emit(fireBegin, parameter(nextBolt))
    local weakSphere = t.fireSphere("WeakFireSphere", weakBolt)
    t.emit(fireSphereBegin, parameter(weakSphere))
    assert(weakSphere.rate == string.unpack("f", string.pack("f", 0.45)))
    t.emit(hit, target, parameter(weakSphere), nil, nil, parameter(45.36))
    assert(t.has("FIRE_HIT mode=fire_weak") and t.has("FIRE_BOLT skill=hilda_staff_atk2_fire mode=weak"))
    assert(t.count("FIRE_BOLT") == 5)
    local weakSphere2 = t.fireSphere("WeakFireSphere2", nextBolt)
    t.emit(fireSphereBegin, parameter(weakSphere2))
    assert(weakSphere2.rate == string.unpack("f", string.pack("f", 0.45)))
    t.endStep()
    contact(t, t.blade("FireRestore1"), target)
    t.beginStep("hilda_staff_atk3_fire")
    local restoredBolt = t.fireBolt("FireRestoredBolt")
    t.emit(fireBegin, parameter(restoredBolt))
    assert(t.has("FIRE_BOLT skill=hilda_staff_atk3_fire mode=strong before=1 reserve=0"))
    t.endStep()
    local restoredSphere = t.fireSphere("RestoredFireSphere", restoredBolt)
    t.emit(fireSphereBegin, parameter(restoredSphere))
    assert(restoredSphere.rate == 0.9)
    t.keys[7]()
    assert(not next(t.hooks) and t.has("hooks_remaining=0"))
end
do
    local t = setup()
    t.keys[4]()
    local b = t.fireBolt("NoBoundary")
    t.setSkill("hilda_staff_atk2_fire")
    t.emit(fireBegin, parameter(b))
    assert(t.count("FIRE_BOLT") == 0 and t.has("reason=unverified_fire_action"))
    t.beginStep("hilda_staff_atk2_fire")
    local foreign = t.fireBolt("ForeignFire", object("OtherOwner", 55))
    t.emit(fireBegin, parameter(foreign))
    local wrongRow = t.fireBolt("WrongRowFire", nil, "other_fire")
    t.emit(fireBegin, parameter(wrongRow))
    assert(t.count("FIRE_BOLT") == 0)
    local accepted = t.fireBolt("AcceptedFire")
    t.emit(fireBegin, parameter(accepted))
    t.emit(fireBegin, parameter(accepted)) -- duplicate callback: no second debit or lost parent.
    t.emit(fireBegin, parameter(t.fireBolt("ExtraFire")))
    assert(t.count("FIRE_BOLT") == 1 and t.has("reason=duplicate_fire_bolt")
        and t.has("reason=unverified_fire_action"))
    local fakeSphere = t.fireSphere("FakeFireSphere", t.fireBolt("UntrackedParent"))
    t.emit(fireSphereBegin, parameter(fakeSphere))
    assert(t.has("reason=unmatched_fire_parent"))
    local foreignSphere = t.fireSphere("ForeignFireSphere", accepted, object("ForeignOwner", 66))
    t.emit(fireSphereBegin, parameter(foreignSphere))
    assert(t.has("reason=foreign_fire_explosion"))
    local wrongSphere = t.fireSphere("WrongRowSphere", accepted, nil, "other_explosion")
    t.emit(fireSphereBegin, parameter(wrongSphere))
    local sphere = t.fireSphere("AcceptedFireSphere", accepted)
    t.endStep()
    t.beginStep("hilda_staff_other_special_fire")
    t.emit(fireSphereBegin, parameter(sphere))
    assert(sphere.rate == 0.9 and t.count("FIRE_SPHERE") == 1)
    t.emit(fireSphereBegin, parameter(sphere))
    assert(t.count("FIRE_SPHERE") == 1 and t.has("reason=duplicate_fire_explosion"))
    t.endStep()
    t.keys[7]()
end
do
    local t = setup()
    t.keys[4]()
    for i=1,3 do
        t.beginStep("hilda_staff_atk1_fire")
        t.emit(fireBegin, parameter(t.fireBolt("DrainFire" .. i)))
        t.endStep()
    end
    t.beginStep("hilda_staff_atk1_fire")
    local weakBolt = t.fireBolt("WeakWriteError")
    t.emit(fireBegin, parameter(weakBolt))
    local sphere = t.fireSphere("WeakWriteErrorSphere", weakBolt)
    t.emit(fireSphereBegin, parameter(sphere))
    assert(sphere.rate == string.unpack("f", string.pack("f", 0.45)))
    t.endStep()
    t.keys[7]()
end
print("PASS: dev Astral/Fire basic shared reserve, parent-linked explosion mode, legacy guards")
