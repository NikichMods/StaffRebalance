-- SPDX-License-Identifier: MPL-2.0
-- Dev candidate, not production. F3=start, F7=stop. Astral/Fire/Thunder/Ice basic staff attacks.
local prefix = "STAFF_RESERVE01"
local assets = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/"
local astral = assets .. "hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local fireBolt = assets .. "hilda_staff_bolt_fire.hilda_staff_bolt_fire_C"
local staffVfx = "/Game/MainContent/Assets/fx/bp/skill/hilda/_staff/"
local fireVfx = staffVfx .. "hilda_staff_fire_bp.hilda_staff_fire_bp_C"
local fireParticle = "ParticleSystem " .. staffVfx .. "private/fire_missile.fire_missile"
local fireSphere = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_200.sphere_200_C"
local thunderBolt = assets .. "hilda_staff_bolt_thunder.hilda_staff_bolt_thunder_C"
local iceBolt = assets .. "hilda_staff_bolt_ice.hilda_staff_bolt_ice_C"
local iceSphere = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_150.sphere_150_C"
local iceSkills = {
    hilda_staff_atk1_idle_ice = true,
    hilda_staff_atk1_ice = true,
    hilda_staff_atk2_ice = true,
    hilda_staff_atk3_ice = true,
}
local thunderSkills = {
    hilda_staff_atk1_idle_thunder = true, hilda_staff_atk1_thunder = true,
    hilda_staff_atk2_thunder = true, hilda_staff_atk3_thunder = true,
}
local fireSkills = {
    hilda_staff_atk1_idle_fire = true,
    hilda_staff_atk1_fire = true,
    hilda_staff_atk2_fire = true,
    hilda_staff_atk3_fire = true,
}
local daggers = assets .. "hilda_dual_atk.hilda_dual_atk_C"
-- Cooked Remapping/Projectile_Player define these eight exact melee source
-- families for astral, fire, ice and thunder. No class or row prefix matching.
-- The hammer's elemental class is hilda_cudgel_fire_C even for astral/ice/thunder;
-- the unmapped hilda_cudgel_C is deliberately not accepted.
local meleeFamilies = {
    {kind = "daggers", class = daggers, rowBase = "hilda_dual_attack"},
    {kind = "daggers", class = assets .. "hilda_dual_atk_plus.hilda_dual_atk_plus_C", rowBase = "hilda_dual_atk_plus"},
    {kind = "spear", class = assets .. "hilda_spear.hilda_spear_C", rowBase = "hilda_spear"},
    {kind = "hammer", class = assets .. "hilda_cudgel_fire.hilda_cudgel_fire_C", rowBase = "hilda_cudgel"},
    {kind = "sword_shield", class = assets .. "hilda_sword_atk.hilda_sword_atk_C", rowBase = "hilda_sword_attack"},
    {kind = "bracelets", class = assets .. "hilda_bracelet_atk1.hilda_bracelet_atk1_C", rowBase = "hilda_bracelet"},
    {kind = "bracelets", class = assets .. "hilda_bracelet_atk3.hilda_bracelet_atk3_C", rowBase = "hilda_bracelet_atk3"},
    {kind = "bracelets", class = assets .. "hilda_bracelet_atk4.hilda_bracelet_atk4_C", rowBase = "hilda_bracelet_atk4"},
}
local meleeSources = {}
for _, family in ipairs(meleeFamilies) do
    for _, element in ipairs({"astral", "fire", "ice", "thunder"}) do
        meleeSources[#meleeSources + 1] = {
            kind = family.kind, element = element, class = family.class, row = family.rowBase .. "_" .. element
        }
    end
end
local root = "/Game/MainContent/Template/BaseBlueprint/"
local mobHit = root .. "BaseAICharacter_Mob_BP.BaseAICharacter_Mob_BP_C:ProjectileHitEvent"
local conduit = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local recovery = root .. "MainGameInstance_BP.MainGameInstance_BP_C:RecoverPlayerAndScene"
local recoveryContext = root .. "GameGlobalBlueprintLibrary.GameGlobalBlueprintLibrary_C:RecoverPlayerAndScene"
local GLOBAL = "/Script/Genesis.Default__GameGlobal"
local animSkill = "/Script/Genesis.BaseCharacterAnimInstance:"
local capacity = 3 -- unchanged gameplay reserve
local diagnosticCapacity = 50 -- log-only, counts eligible unique contacts independent of gameplay cap
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
    if skill == "hilda_staff_atk2" or skill == "hilda_staff_atk3"
        or fireSkills[skill] or thunderSkills[skill] or iceSkills[skill] then
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

-- Thunder: 1/2/3 direct bolts per ordinary skill action. Debit only when
-- the first bolt of an authenticated native BeginDoSkill execution appears.
-- Dev candidate: Thunder owner, action delivery and damage need live verification.
local function thunderBegin(pawn, context)
    local bolt = context:get()
    assert(exact(bolt, thunderBolt), "unexpected_thunder_context")
    if not owned(bolt, pawn) or bolt.ProjectileDataName:ToString() ~= "hilda_staff_bolt_thunder" then
        log("SKIP", "reason=foreign_or_unsupported_thunder_bolt")
        return
    end
    local sourceId = id(bolt)
    if session.shots[sourceId] then
        log("SKIP", "reason=duplicate_thunder_source source=" .. sourceId)
        return
    end
    local skill = StaticFindObject(GLOBAL):GetDoingSkill(pawn):ToString()
    if not thunderSkills[skill] then
        log("SKIP", "reason=unsupported_thunder_skill skill=" .. skill)
        return
    end
    local combo = session.combo
    local mesh = pawn.Mesh
    local anim = valid(mesh) and mesh:GetAnimInstance()
    if not combo or combo.skill ~= skill or not valid(anim) or id(anim) ~= session.anim then
        log("SKIP", "reason=unverified_thunder_action skill=" .. skill)
        return
    end
    if combo.mode == "skip_e804" then
        log("SKIP", "reason=unverified_e804_thunder_combo source=" .. sourceId)
        return
    end
    assert(field(bolt, "DamageRate", 0x2C4))
    assert(field(bolt, "Original Damage Rate"))
    local rate = get(bolt, "DamageRate")
    assert(rate > 0, "invalid_thunder_rate")
    if get(bolt, "Original Damage Rate") ~= 0 then
        combo.mode = "skip_e804"
        log("SKIP", "reason=unverified_e804_thunder source=" .. sourceId)
        return
    end
    local before = session.reserve
    local first = not combo.mode
    local mode = combo.mode or (before > 0 and "strong" or "weak")
    local effective = rate
    if mode == "weak" then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_thunder_rate")
        local ok, err = pcall(write, bolt, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, bolt, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    local debit = first and mode == "strong" and 1 or 0
    if debit == 1 then session.reserve = before - 1 end
    if first then combo.mode = mode end
    session.shots[sourceId] = "thunder_" .. mode
    log("THUNDER_BOLT", "skill=" .. skill .. " mode=" .. mode .. " before=" .. before
        .. " reserve=" .. session.reserve .. " debit=" .. debit .. " rate=" .. rate
        .. " effective=" .. effective .. " source=" .. sourceId)
end

local function fireFlightVfx(bolt, sourceId)
    local probe = session.fireVfxProbe or "scale"
    local function requireFunction(path, shape)
        local ready, reason = check("/Script/Engine." .. path, true, false, shape)
        assert(ready, reason)
    end
    local function same(object, expected)
        return valid(object) and valid(expected) and id(object) == id(expected)
    end
    local function nativeClass(object, name)
        return valid(object) and object:GetClass():GetFullName() == "Class /Script/Engine." .. name
    end

    local ok, reason = pcall(function()
        requireFunction("ActorComponent:GetOwner", "ObjectProperty:ReturnValue")
        requireFunction("Actor:GetParentComponent", "ObjectProperty:ReturnValue")
        requireFunction("SceneComponent:GetAttachParent", "ObjectProperty:ReturnValue")
        requireFunction("ActorComponent:IsActive", "BoolProperty:ReturnValue")
        requireFunction("PrimitiveComponent:GetCollisionEnabled", "ByteProperty:ReturnValue")

        local mount = bolt.hilda_staff_fire_bp
        assert(nativeClass(mount, "ChildActorComponent") and same(mount:GetOwner(), bolt)
            and same(mount:GetAttachParent(), bolt.RootArrow), "fire_vfx_mount")
        local child = mount.ChildActor
        assert(exact(child, fireVfx) and same(child:GetParentComponent(), mount), "fire_vfx_child")
        local particle = child.ParticleSystem
        assert(nativeClass(particle, "ParticleSystemComponent") and same(particle:GetOwner(), child)
            and same(particle:GetAttachParent(), child.Scene), "fire_vfx_particle")
        local template = particle.Template
        assert(valid(template) and template:GetFullName() == fireParticle, "fire_vfx_template")
        assert(particle:IsActive() and particle:GetCollisionEnabled() == 0
            and particle.AttachChildren:GetArrayNum() == 0
            and particle.bAllowRecycling == false, "fire_vfx_not_ready_or_not_leaf")

        local function stockScale()
            local scale = particle.RelativeScale3D
            return scale.X == 1 and scale.Y == 1 and scale.Z == 1
        end
        assert(stockScale() and particle.InstanceParameters:GetArrayNum() == 0, "fire_vfx_nonstock")
        local apply, restore
        if probe == "fade" then
            requireFunction("FXSystemComponent:SetFloatParameter", "NameProperty:ParameterName,FloatProperty:Param")
            local name = FName("Fade", EFindName.FNAME_Find)
            assert(name:ToString() == "Fade", "fire_vfx_fade_name")
            local function fadeEntry()
                local params = particle.InstanceParameters
                assert(params:GetArrayNum() == 1, "fire_vfx_fade_count")
                local entry = params[1]
                assert(entry.Name:ToString() == "Fade" and entry.ParamType == 1, "fire_vfx_fade_entry")
                return entry
            end
            apply = function()
                particle:SetFloatParameter(name, 0.5)
                assert(fadeEntry().Scalar == 0.5, "fire_vfx_fade_readback")
            end
            restore = function()
                if particle.InstanceParameters:GetArrayNum() == 0 then return end
                fadeEntry()
                particle.InstanceParameters:Empty()
                assert(particle.InstanceParameters:GetArrayNum() == 0, "fire_vfx_fade_restore")
            end
        else
            requireFunction("SceneComponent:SetRelativeScale3D", "StructProperty:NewScale3D")
            apply = function()
                particle:SetRelativeScale3D({X = 0.75, Y = 0.75, Z = 0.75})
                local scale = particle.RelativeScale3D
                assert(scale.X == 0.75 and scale.Y == 0.75 and scale.Z == 0.75, "fire_vfx_scale_readback")
            end
            restore = function()
                if stockScale() then return end
                particle:SetRelativeScale3D({X = 1, Y = 1, Z = 1})
                assert(stockScale(), "fire_vfx_scale_restore")
            end
        end
        log("FIRE_VFX_WRITE", "probe=" .. probe .. " source=" .. sourceId)
        local applied, problem = pcall(apply)
        if not applied then
            local restored = pcall(restore)
            error("write:" .. tostring(problem) .. " rollback=" .. (restored and "ok" or "failed"), 0)
        end
    end)
    if ok then
        log("FIRE_VFX_APPLIED", "probe=" .. probe .. " source=" .. sourceId)
    else
        session.fireVfxError = true
        log("FIRE_VFX_SKIP", "probe=" .. probe .. " reason=" .. tostring(reason):sub(-220)
            .. " action=disable_vfx_for_session")
    end
end

local function fireBegin(pawn, context)
    local bolt = context:get()
    assert(exact(bolt, fireBolt), "unexpected_fire_bolt_context")
    local sourceId = id(bolt)
    -- Duplicate callbacks must not discard a still-pending child mode.
    if session.combo and session.combo.fireSource == sourceId then
        log("SKIP", "reason=duplicate_fire_bolt source=" .. sourceId)
        return
    end
    -- A newly observed, unsupported use must not inherit an old actor address.
    session.fireParents[sourceId] = nil
    if bolt.ProjectileDataName:ToString() ~= "hilda_staff_bolt_fire" or not owned(bolt, pawn) then
        log("SKIP", "reason=foreign_or_unsupported_fire_bolt source=" .. sourceId)
        return
    end
    local skill = StaticFindObject(GLOBAL):GetDoingSkill(pawn):ToString()
    if not fireSkills[skill] then
        log("SKIP", "reason=unsupported_fire_skill skill=" .. skill)
        return
    end
    local combo = session.combo
    local mesh = pawn.Mesh
    local anim = valid(mesh) and mesh:GetAnimInstance()
    if not combo or combo.skill ~= skill or combo.mode or not valid(anim) or id(anim) ~= session.anim then
        log("SKIP", "reason=unverified_fire_action skill=" .. skill)
        return
    end
    -- Exactly one base Fire bolt was observed per execution; debit at its BeginPlay.
    local before = session.reserve
    local mode = before > 0 and "strong" or "weak"
    session.fireParents[sourceId] = mode
    combo.mode, combo.fireSource = mode, sourceId
    if mode == "strong" then session.reserve = before - 1 end
    log("FIRE_BOLT", "skill=" .. skill .. " mode=" .. mode .. " before=" .. before
        .. " reserve=" .. session.reserve .. " debit=" .. (mode == "strong" and 1 or 0)
        .. " source=" .. sourceId)
    if session.fireParents[sourceId] == "weak" and not session.fireVfxError then
        fireFlightVfx(bolt, sourceId)
    end
end

local function fireExplosion(pawn, context)
    local sphere = context:get()
    assert(exact(sphere, fireSphere), "unexpected_fire_sphere_context")
    if sphere.ProjectileDataName:ToString() ~= "hilda_staff_bolt_fire_explosion" then return end
    local parent = sphere:GetOwner()
    if not exact(parent, fireBolt) or parent.ProjectileDataName:ToString() ~= "hilda_staff_bolt_fire"
        or not owned(sphere, pawn) or not owned(parent, pawn) then
        log("SKIP", "reason=foreign_fire_explosion")
        return
    end
    local sourceId, parentId = id(sphere), id(parent)
    if session.shots[sourceId] then
        log("SKIP", "reason=duplicate_fire_explosion source=" .. sourceId)
        return
    end
    local mode = session.fireParents[parentId]
    if not mode then
        log("SKIP", "reason=unmatched_fire_parent parent=" .. parentId)
        return
    end
    assert(field(sphere, "DamageRate", 0x2C4))
    local rate = get(sphere, "DamageRate")
    assert(rate > 0, "invalid_fire_explosion_rate")
    local effective = rate
    if mode == "weak" then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_fire_rate")
        local ok, err = pcall(write, sphere, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, sphere, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    -- The observed basic Fire path produces one sphere per bolt.
    session.fireParents[parentId] = nil
    session.shots[sourceId] = "fire_" .. mode
    log("FIRE_SPHERE", "mode=" .. mode .. " source=" .. sourceId .. " parent=" .. parentId
        .. " rate=" .. rate .. " effective=" .. effective)
end

-- Ice creates a carrier bolt and repeated child damage pulses. Capture one
-- mode/debit on native skill execution; apply that mode to the carrier itself.
-- Unlike Fire, the parent mapping must survive ALL child pulses and EndDoSkill.
local function iceBegin(pawn, context)
    local bolt = context:get()
    assert(exact(bolt, iceBolt), "unexpected_ice_context")
    local sourceId = id(bolt)
    if session.shots[sourceId] then
        log("SKIP", "reason=duplicate_ice_bolt source=" .. sourceId)
        return
    end
    -- Reject stale parent context when a distinct/unsupported actor takes this ID.
    session.iceParents[sourceId] = nil
    if bolt.ProjectileDataName:ToString() ~= "hilda_staff_bolt_ice" or not owned(bolt, pawn) then
        log("SKIP", "reason=foreign_or_unsupported_ice_bolt source=" .. sourceId)
        return
    end
    local skill = StaticFindObject(GLOBAL):GetDoingSkill(pawn):ToString()
    if not iceSkills[skill] then
        log("SKIP", "reason=unsupported_ice_skill skill=" .. skill)
        return
    end
    local combo = session.combo
    local mesh = pawn.Mesh
    local anim = valid(mesh) and mesh:GetAnimInstance()
    if not combo or combo.skill ~= skill or combo.mode or not valid(anim) or id(anim) ~= session.anim then
        log("SKIP", "reason=unverified_ice_action skill=" .. skill)
        return
    end
    assert(field(bolt, "DamageRate", 0x2C4))
    local rate = get(bolt, "DamageRate")
    -- The carrier can have no independent damage. Zero still establishes
    -- an executed action and a mode for its damaging child pulses.
    assert(rate >= 0, "invalid_ice_rate")
    local before = session.reserve
    local mode = before > 0 and "strong" or "weak"
    local effective = rate
    if mode == "weak" and rate > 0 then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_ice_rate")
        local ok, err = pcall(write, bolt, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, bolt, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    session.iceParents[sourceId] = mode
    combo.mode, combo.iceSource = mode, sourceId
    if mode == "strong" then session.reserve = before - 1 end
    session.shots[sourceId] = "ice_" .. mode
    log("ICE_BOLT", "skill=" .. skill .. " mode=" .. mode .. " before=" .. before
        .. " reserve=" .. session.reserve .. " debit=" .. (mode == "strong" and 1 or 0)
        .. " rate=" .. rate .. " effective=" .. effective .. " source=" .. sourceId)
end

local function icePulse(pawn, context)
    local sphere = context:get()
    assert(exact(sphere, iceSphere), "unexpected_ice_pulse_context")
    -- Same Blueprint class is also used for Ice VFX and an unrelated Fourth attack.
    if sphere.ProjectileDataName:ToString() ~= "hilda_staff_bolt_ice_hit" then return end
    local sourceId = id(sphere)
    if session.shots[sourceId] then
        log("SKIP", "reason=duplicate_ice_pulse source=" .. sourceId)
        return
    end
    local parent = sphere:GetOwner()
    if not exact(parent, iceBolt) or parent.ProjectileDataName:ToString() ~= "hilda_staff_bolt_ice"
        or not owned(parent, pawn) or not owned(sphere, pawn) then
        log("SKIP", "reason=foreign_ice_pulse source=" .. sourceId)
        return
    end
    local parentId = id(parent)
    local mode = session.iceParents[parentId]
    if not mode then
        log("SKIP", "reason=unmatched_ice_parent parent=" .. parentId)
        return
    end
    assert(field(sphere, "DamageRate", 0x2C4))
    local rate = get(sphere, "DamageRate")
    assert(rate > 0, "invalid_ice_pulse_rate")
    local effective = rate
    if mode == "weak" then
        effective = string.unpack("f", string.pack("f", rate * 0.5))
        assert(finite(effective) and effective > 0 and effective < rate, "invalid_weak_ice_pulse_rate")
        local ok, err = pcall(write, sphere, "DamageRate", effective)
        if not ok then
            local restored = pcall(write, sphere, "DamageRate", rate)
            log(restored and "ROLLBACK_OK" or "ROLLBACK_FAILED", "source=" .. sourceId)
            error(err)
        end
    end
    -- Do NOT remove iceParents[parentId]: another pulse may arrive later.
    session.shots[sourceId] = "ice_" .. mode
    log("ICE_PULSE", "mode=" .. mode .. " source=" .. sourceId .. " parent=" .. parentId
        .. " rate=" .. rate .. " effective=" .. effective)
end

local function meleeKind(source)
    local class = source:GetClass():GetFullName()
    local row = source.ProjectileDataName:ToString()
    for _, spec in ipairs(meleeSources) do
        if class == "BlueprintGeneratedClass " .. spec.class and row == spec.row then
            return spec.kind, spec.element
        end
    end
    return nil
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
    if exact(source, fireSphere) then
        local mode = session.shots[id(source)]
        if mode == "fire_strong" or mode == "fire_weak" then
            local damage = damageParam:get()
            assert(finite(damage), "invalid_fire_notification")
            log("FIRE_HIT", "mode=" .. mode .. " notified_damage=" .. damage
                .. " rate=" .. get(source, "DamageRate") .. " source=" .. id(source) .. " target=" .. id(target))
        end
        return
    end
    if exact(source, iceBolt) or exact(source, iceSphere) then
        local sourceId = id(source)
        local mode = session.shots[sourceId]
        if mode == "ice_strong" or mode == "ice_weak" then
            local damage = damageParam:get()
            assert(finite(damage), "invalid_ice_notification")
            local kind = exact(source, iceBolt) and "carrier" or "pulse"
            log("ICE_HIT", "kind=" .. kind .. " mode=" .. mode .. " notified_damage=" .. damage
                .. " rate=" .. get(source, "DamageRate") .. " source=" .. sourceId .. " target=" .. id(target))
        end
        return
    end
    if exact(source, thunderBolt) then
        local sourceId = id(source)
        local mode = session.shots[sourceId]
        if mode == "thunder_strong" or mode == "thunder_weak" then
            local damage = damageParam:get()
            assert(finite(damage), "invalid_thunder_notification")
            log("THUNDER_HIT", "mode=" .. mode .. " notified_damage=" .. damage
                .. " rate=" .. get(source, "DamageRate") .. " source=" .. sourceId .. " target=" .. id(target))
        end
        return
    end
    local kind, element = meleeKind(source)
    if not kind or not owned(source, pawn) then return end
    -- The hooked BaseAICharacter_Mob_BP_C receiver is a combat character, not scenery.
    -- The accepted contact contract does not require an additional faction filter.
    -- At most one credit per source-target pair: repeated callbacks are logged but not credited.
    local damage = damageParam:get()
    assert(finite(damage), "invalid_melee_notification")
    local sourceId, targetId = id(source), id(target)
    local seen = session.contacts[sourceId]
    if not seen then
        seen = {}
        session.contacts[sourceId] = seen
    end
    if seen[targetId] then
        log("DUPLICATE", "reserve=" .. session.reserve .. " source=" .. sourceId .. " target=" .. targetId
            .. " weapon=" .. kind .. " element=" .. element .. " diag_total=" .. session.diagnostic.total)
        return
    end
    seen[targetId] = true
    local diagnostic = session.diagnostic
    diagnostic.total = math.min(diagnosticCapacity, diagnostic.total + 1)
    diagnostic.byWeapon[kind] = math.min(diagnosticCapacity, (diagnostic.byWeapon[kind] or 0) + 1)
    local before = session.reserve
    session.reserve = math.min(capacity, before + 1)
    log("MELEE", "before=" .. before .. " reserve=" .. session.reserve .. " notified_damage=" .. damage
        .. " source=" .. sourceId .. " target=" .. targetId .. " weapon=" .. kind
        .. " element=" .. element .. " diag_total=" .. diagnostic.total
        .. " diag_weapon=" .. diagnostic.byWeapon[kind])
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
    -- Fire classes can remain unloaded until the first Fire shot.
    -- Treat Fire hooks as one optional pair: never block proven Astral on their absence.
    local fireReady = true
    for _, spec in ipairs({
        {"/Script/Engine.Actor:GetOwner", true, false, "ObjectProperty:ReturnValue"},
        {fireBolt .. ":ReceiveBeginPlay", false, false, ""},
        {fireSphere .. ":ReceiveBeginPlay", false, false, ""},
    }) do
        local ready, reason = check(table.unpack(spec))
        if not ready then
            fireReady = false
            log("FIRE_UNAVAILABLE", "reason=" .. reason .. " warmup_fire_before_F3=true")
            break
        end
    end
    if fireReady then
        routes[#routes + 1] = {fireBolt .. ":ReceiveBeginPlay", "", fireBegin}
        routes[#routes + 1] = {fireSphere .. ":ReceiveBeginPlay", "", fireExplosion}
    end
    -- Thunder class may remain unloaded in this save; keep existing elements operational.
    local thunderReady, thunderReason = check(thunderBolt .. ":ReceiveBeginPlay", false, false, "")
    if thunderReady then
        routes[#routes + 1] = {thunderBolt .. ":ReceiveBeginPlay", "", thunderBegin}
    else
        log("THUNDER_UNAVAILABLE", "reason=" .. thunderReason .. " warmup_thunder_before_F3=true")
    end
    -- Ice is optional as a pair: never debit a carrier without the child hook.
    local iceReady = true
    for _, spec in ipairs({
        {"/Script/Engine.Actor:GetOwner", true, false, "ObjectProperty:ReturnValue"},
        {iceBolt .. ":ReceiveBeginPlay", false, false, ""},
        {iceSphere .. ":ReceiveBeginPlay", false, false, ""},
    }) do
        local ready, reason = check(table.unpack(spec))
        if not ready then
            iceReady = false
            log("ICE_UNAVAILABLE", "reason=" .. reason .. " warmup_ice_before_F3=true")
            break
        end
    end
    if iceReady then
        routes[#routes + 1] = {iceBolt .. ":ReceiveBeginPlay", "", iceBegin}
        routes[#routes + 1] = {iceSphere .. ":ReceiveBeginPlay", "", icePulse}
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
        shots = {}, fireParents = {}, iceParents = {}, contacts = {}, skippedSkills = {},
        diagnostic = {total = 0, byWeapon = {}}}
    log("START", "reserve=" .. capacity .. " hooks=" .. #hooks
        .. " fire=" .. (fireReady and "ready" or "unavailable")
        .. " thunder=" .. (thunderReady and "ready" or "unavailable")
        .. " ice=" .. (iceReady and "ready" or "unavailable")
        .. " diag_total=0 diag_capacity=" .. diagnosticCapacity)
end

local function stop()
    local reserve = session and session.reserve or "inactive"
    if session and session.diagnostic then
        local d = session.diagnostic
        log("DIAG_SUMMARY", "total=" .. d.total .. " capacity=" .. diagnosticCapacity
            .. " daggers=" .. (d.byWeapon.daggers or 0)
            .. " spear=" .. (d.byWeapon.spear or 0)
            .. " hammer=" .. (d.byWeapon.hammer or 0)
            .. " sword_shield=" .. (d.byWeapon.sword_shield or 0)
            .. " bracelets=" .. (d.byWeapon.bracelets or 0))
    end
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
    for _, key in ipairs({Key.F3, Key.F7}) do
        assert(not IsKeyBindRegistered(key), "key_collision")
    end
    bind(Key.F7, stop)
    bind(Key.F3, start)
    local fadeReady = pcall(function()
        assert(Key.F4 and not IsKeyBindRegistered(Key.F4), "fade_key_unavailable")
        bind(Key.F4, function()
            if not session or session.fireVfxError then return end
            session.fireVfxProbe = session.fireVfxProbe == "fade" and "scale" or "fade"
            log("FIRE_VFX_PROBE", "probe=" .. session.fireVfxProbe)
        end)
    end)
    if not fadeReady then
        log("FIRE_VFX_PROBE", "probe=scale fade_key=unavailable")
    end
end)
if ok then log("LOADED", "F3=start F7=stop astral_fire_basic_shared_reserve=true")
else fail(err) end
