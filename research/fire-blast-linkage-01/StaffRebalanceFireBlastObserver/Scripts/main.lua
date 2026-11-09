-- SPDX-License-Identifier: MPL-2.0
-- Read-only Fire blast provenance. F6 arms after warmup, F8 stops.
local bolt = "/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/hilda_staff_bolt_fire.hilda_staff_bolt_fire_C"
local sphere = "/Game/MainContent/Act/Skill_BP/CommonSkill_BP/sphere_200.sphere_200_C"
local blast = "/Game/MainContent/Assets/fx/bp/general/fire/fire_explosion_b_02_bp.fire_explosion_b_02_bp_C"
local init = "/Game/MainContent/Assets/fx/bp/basic/VFX_Base_bp.VFX_Base_bp_C:EventInit"
local particleTemplate = "ParticleSystem /Game/MainContent/Assets/fx/bp/general/fire/fire_explosion_b_02.fire_explosion_b_02"
local hooks = {}
local active, finished = false, false
local sequence = 0

local function log(event, details)
    sequence = sequence + 1
    print("STAFF_FIRE_BLAST01 seq=" .. sequence .. " " .. event .. " " .. (details or "") .. "\n")
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function id(object)
    if not valid(object) then return "none" end
    return string.format("%q", object:GetFullName() .. "@" .. tostring(object:GetAddress()))
end

local function exact(object, class)
    return valid(object) and object:GetClass():GetFullName() == "BlueprintGeneratedClass " .. class
end

local function stop()
    active, finished = false, true
    local remaining = {}
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, hook.path, hook.pre, hook.post)
        if not ok then
            remaining[#remaining + 1] = hook
            log("UNHOOK_ERROR", tostring(err))
        end
    end
    hooks = remaining
    log("STOP", "remaining=" .. #hooks)
end

local function check(path, expected)
    local fn = StaticFindObject(path)
    assert(valid(fn) and fn:type() == "UFunction" and fn:GetFullName() == "Function " .. path, "missing " .. path)
    assert((fn:GetFunctionFlags() & 0x2400) == 0, "expected instance Blueprint function " .. path)
    local fields = {}
    fn:ForEachProperty(function(prop)
        local kind, name = prop:GetFullName():match("^(%w+) .+:([^:]+)$")
        fields[#fields + 1] = tostring(kind) .. ":" .. tostring(name):lower()
    end)
    assert(table.concat(fields, ",") == expected, "unexpected signature " .. path)
end

local function attach(path, class, callback)
    local a, b = RegisterHook(path, function(context, ...)
        if not active then return end
        local ok, err = pcall(function(...)
            assert(IsInGameThread(), "not game thread")
            local actor = context:get()
            if exact(actor, class) then callback(actor, ...) end
        end, ...)
        if not ok then
            active = false
            log("FAILED", tostring(err) .. " action=F8")
        end
    end)
    hooks[#hooks + 1] = {path = path, pre = a, post = b}
    assert(math.type(a) == "integer" and a > 0 and a == b, "unexpected Blueprint hook IDs " .. path)
end

local function projectile(event, row)
    return function(actor)
        if actor.ProjectileDataName:ToString() ~= row then return end
        log(event, "actor=" .. id(actor) .. " owner=" .. id(actor:GetOwner())
            .. " character=" .. id(actor:GetCharacterOwner()))
    end
end

local function componentOwner(component)
    return valid(component) and component:GetOwner() or nil
end

local function blastState(actor)
    local root = actor.RootComponent
    local parent = valid(root) and root:GetAttachParent() or nil
    local psc = actor.ParticleSystem
    local owned = valid(psc) and id(psc:GetOwner()) == id(actor)
    local template = owned and psc.Template or nil
    local ready = valid(template) and template:GetFullName() == particleTemplate
    return "actor=" .. id(actor) .. " owner=" .. id(actor:GetOwner())
        .. " attachActor=" .. id(actor:GetAttachParentActor()) .. " attachComponent=" .. id(parent)
        .. " attachOwner=" .. id(componentOwner(parent)) .. " psc=" .. id(psc)
        .. " pscExact=" .. tostring(ready) .. " pscActive=" .. tostring(ready and psc:IsActive())
end

local function start()
    if active or finished then return end
    local routes = {
        {bolt .. ":ReceiveBeginPlay", bolt, "", projectile("BOLT", "hilda_staff_bolt_fire")},
        {sphere .. ":ReceiveBeginPlay", sphere, "", projectile("SPHERE", "hilda_staff_bolt_fire_explosion")},
        {blast .. ":ReceiveBeginPlay", blast, "", function(actor)
            log("BLAST_BEGIN", blastState(actor))
        end},
        {init, blast, "ObjectProperty:sender,ObjectProperty:recver,ObjectProperty:attachcomponent,StructProperty:data",
            function(actor, sender, recver, component)
                local attachComponent = component:get()
                log("BLAST_INIT", blastState(actor) .. " sender=" .. id(sender:get())
                    .. " recver=" .. id(recver:get()) .. " initComponent=" .. id(attachComponent)
                    .. " initComponentOwner=" .. id(componentOwner(attachComponent)))
            end},
    }
    for _, route in ipairs(routes) do check(route[1], route[3]) end
    for _, route in ipairs(routes) do attach(route[1], route[2], route[4]) end
    active = true
    log("START", "hooks=" .. #hooks)
end

local function bind(key, action)
    RegisterKeyBind(key, function()
        local queued, err = pcall(ExecuteInGameThread, function()
            local ok, problem = pcall(function()
                assert(IsInGameThread(), "not game thread")
                action()
            end)
            if not ok then
                log("FAILED", tostring(problem))
                if IsInGameThread() then stop() end
            end
        end, EGameThreadMethod.EngineTick)
        if not queued then log("FAILED", tostring(err)) end
    end)
end

local ok, err = pcall(function()
    assert(EngineTickAvailable and EGameThreadMethod.EngineTick, "EngineTick unavailable")
    assert(not IsKeyBindRegistered(Key.F6) and not IsKeyBindRegistered(Key.F8), "observer key occupied")
    bind(Key.F8, stop)
    bind(Key.F6, start)
end)
if ok then log("LOADED", "F6=start F8=stop") else log("FAILED", tostring(err)) end
