-- SPDX-License-Identifier: MPL-2.0
-- Read-only trace on the local Hilda and her animation instance.
local base = "/Script/Genesis.BaseCharacterAnimInstance:"
local global = "/Script/Genesis.GameGlobal:"
local cdoPath = "/Script/Genesis.Default__GameGlobal"
local boltClass = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/hilda_staff_bolt_astral.hilda_staff_bolt_astral_C"
local hooks = {}
local active, finished = false, false
local pawnId, animId
local sequence, segment = 0, 0

local function log(event, detail)
    sequence = sequence + 1
    print("STAFF_COMBO01 seq=" .. sequence .. " segment=" .. segment .. " " .. event .. " " .. detail .. "\n")
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function id(object)
    return valid(object) and object:GetFullName() .. "@" .. tostring(object:GetAddress()) or "none"
end

local function quote(value)
    return string.format("%q", tostring(value))
end

local function localPlayer()
    local cdo = StaticFindObject(cdoPath)
    assert(valid(cdo) and cdo:GetFullName() == "GameGlobal " .. cdoPath, "missing GameGlobal")
    local pawn = cdo:GetPlayerCharacter()
    assert(valid(pawn) and pawn:GetClass():GetFullName() ==
        "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C", "load playable Hilda")
    local mesh = pawn.Mesh
    assert(valid(mesh) and id(mesh:GetOwner()) == id(pawn), "unexpected mesh owner")
    local anim = mesh:GetAnimInstance()
    assert(valid(anim) and anim:GetClass():GetFullName():match("%.hilda_AnimBP_C$"), "unexpected anim")
    return cdo, pawn, anim
end

local function check(path, native, static, expected)
    local fn = StaticFindObject(path)
    assert(valid(fn) and fn:type() == "UFunction" and fn:GetFullName() == "Function " .. path, "missing " .. path)
    local flags = fn:GetFunctionFlags()
    assert(((flags & 0x400) ~= 0) == native and ((flags & 0x2000) ~= 0) == static, "unexpected flags " .. path)
    local fields = {}
    fn:ForEachProperty(function(prop)
        local kind, name = prop:GetFullName():match("^(%w+) .+:([^:]+)$")
        fields[#fields + 1] = tostring(kind) .. ":" .. tostring(name)
    end)
    assert(table.concat(fields, ",") == expected, "unexpected signature " .. path .. " " .. table.concat(fields, ","))
end

local function stop(reason)
    active, finished = false, true
    local remaining = {}
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, hook.path, hook.pre, hook.post)
        if not ok then
            remaining[#remaining + 1] = hook
            log("UNHOOK_ERROR", quote(err))
        end
    end
    hooks = remaining
    log("STOP", "reason=" .. reason .. " unrequestable=" .. #hooks .. " native_removal=deferred")
end

local function guarded(callback)
    return function(...)
        if not active then return end
        local ok, err = pcall(function(...)
            assert(IsInGameThread(), "not game thread")
            callback(...)
        end, ...)
        if not ok then
            active = false
            log("FAILED", quote(err))
            local queued = pcall(ExecuteInGameThread, function() stop("failure") end, EGameThreadMethod.EngineTick)
            if not queued then log("CLEANUP_PENDING", "press_F7") end
        end
    end
end

local function attach(path, pre, post)
    local a, b
    if pre then a, b = RegisterHook(path, guarded(pre), guarded(post))
    else a, b = RegisterHook(path, guarded(post)) end
    hooks[#hooks + 1] = {path = path, pre = a, post = b}
    assert(math.type(a) == "integer" and math.type(b) == "integer" and a > 0 and b > 0
        and ((a ~= b) == (pre ~= nil)), "unexpected hook IDs " .. path)
    log("HOOK", "path=" .. path .. " pre=" .. a .. " post=" .. b)
end

local function snapshot(anim)
    return " pending=" .. quote(anim:GetToDoSkill():ToString()) .. " doing=" .. quote(anim:GetDoingSkill():ToString())
end

local function skill(method, phase)
    return function(context, ...)
        local anim = context:get()
        if id(anim) ~= animId then return end
        assert(select("#", ...) == 0, "unexpected skill inputs")
        local _, pawn, current = localPlayer()
        assert(id(pawn) == pawnId and id(current) == animId, "local identity changed")
        log("SKILL", "method=" .. method .. " phase=" .. phase .. snapshot(anim))
    end
end

local function bolt(context)
    local source = context:get()
    if not valid(source) or source:GetClass():GetFullName() ~= "BlueprintGeneratedClass " .. boltClass then return end
    if source.ProjectileDataName:ToString() ~= "hilda_staff_bolt_astral" then return end
    local owner = id(source:GetCharacterOwner())
    if owner ~= pawnId then
        log("BOLT_SKIPPED", "source=" .. quote(id(source)) .. " owner=" .. quote(owner))
        return
    end
    local cdo, pawn, anim = localPlayer()
    assert(id(pawn) == pawnId and id(anim) == animId, "local identity changed")
    log("BOLT", "skill=" .. quote(cdo:GetDoingSkill(pawn):ToString()) .. snapshot(anim)
        .. " source=" .. quote(id(source)) .. " owner=" .. quote(owner))
end

local function startOrMark()
    if finished then return end
    if active then
        segment = segment + 1
        log("MARK", "scenario_boundary")
        return
    end
    check(global .. "GetPlayerCharacter", true, true, "ObjectProperty:ReturnValue")
    check(global .. "GetDoingSkill", true, true, "ObjectProperty:Character,NameProperty:ReturnValue")
    check("/Script/Genesis.BaseProjectile:GetCharacterOwner", true, false, "ObjectProperty:ReturnValue")
    check(base .. "BeginDoSkill", true, false, "")
    check(base .. "EndDoSkill", true, false, "")
    check(boltClass .. ":ReceiveBeginPlay", false, false, "")
    local _, pawn, anim = localPlayer()
    pawnId, animId = id(pawn), id(anim)
    for _, method in ipairs({"BeginDoSkill", "EndDoSkill"}) do
        attach(base .. method, skill(method, "pre"), skill(method, "post"))
    end
    attach(boltClass .. ":ReceiveBeginPlay", nil, bolt)
    active, segment = true, 1
    log("START", "pawn=" .. quote(pawnId) .. " anim=" .. quote(animId) .. snapshot(anim))
end

local function bind(key, action)
    RegisterKeyBind(key, function()
        local queued, err = pcall(ExecuteInGameThread, function()
            local ok, problem = pcall(function()
                assert(IsInGameThread(), "not game thread")
                action()
            end)
            if not ok then
                log("FAILED", quote(problem))
                if #hooks > 0 then stop("failure") end
            end
        end, EGameThreadMethod.EngineTick)
        if not queued then
            active = false
            log("FAILED", quote(err))
        end
    end)
end

assert(EngineTickAvailable == true and type(EGameThreadMethod.EngineTick) == "number", "EngineTick required")
assert(not IsKeyBindRegistered(Key.F4) and not IsKeyBindRegistered(Key.F7), "key collision")
bind(Key.F7, function() stop("user") end)
bind(Key.F4, startOrMark)
log("ARMED", "F4=start_or_mark F7=stop")
