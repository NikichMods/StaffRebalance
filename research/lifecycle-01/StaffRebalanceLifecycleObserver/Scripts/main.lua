-- SPDX-License-Identifier: MPL-2.0
-- Read-only observation. Active until game exit.
local prefix = "/Script/Genesis."
local globalPath = prefix .. "Default__GameGlobal"
local conduit = "/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP.BaseSavePoint_BP_C:"
local skill = "/Game/MainContent/Act/Skill_BP/"
local gameInstance = "/Game/MainContent/Template/BaseBlueprint/MainGameInstance_BP.MainGameInstance_BP_C:"
local routes = {
    {prefix .. "GameGlobal:NotifyNeedLoadGameDataMain", "load_main", true},
    {prefix .. "GameGlobal:NotifyNeedLoadGameDataCurrent", "load_current", true},
    {prefix .. "GameGlobal:NotifyNeedLoadGameDataAutoSave", "load_autosave", true},
    {prefix .. "GameGlobal:ExecuteNotifyLoadGameData", "execute_load", true},
    {prefix .. "GenesisGameInstance:EventCharacterDead", "character_dead_base", false, "argument"},
    {gameInstance .. "EventCharacterDead", "character_dead", false, "argument"},
    {prefix .. "GenesisCharacter:ReviveEvent", "revive", false, "context"},
    {conduit .. "Interact_Transport", "transport", false},
    {conduit .. "Interact_Rest", "rest_request", false},
}
local readiness = {
    {"astral", skill .. "PlayerSkill_BP/hilda_staff_bolt_astral.hilda_staff_bolt_astral_C:ReceiveBeginPlay"},
    {"fire", skill .. "PlayerSkill_BP/hilda_staff_bolt_fire.hilda_staff_bolt_fire_C:ReceiveBeginPlay"},
    {"fire_child", skill .. "CommonSkill_BP/sphere_200.sphere_200_C:ReceiveBeginPlay"},
}
local attached = {}
local lastSnapshot
local warned = {}

local function log(message)
    print("SR_LIFECYCLE01 " .. message .. "\n")
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function hilda()
    local global = StaticFindObject(globalPath)
    if not valid(global) then return end
    local pawn = global:GetPlayerCharacter()
    if valid(pawn) and pawn:GetClass():GetFName():ToString() == "hilda_BP_C" then
        return pawn, global
    end
end

local function isCurrentPlayer(character)
    local pawn = hilda()
    return valid(character) and valid(pawn) and character:GetAddress() == pawn:GetAddress()
end

local function attach(route)
    local path, name, native, playerSource = table.unpack(route)
    if attached[path] then return end
    local fn = StaticFindObject(path)
    if not valid(fn) or fn:GetFullName() ~= "Function " .. path then return end

    local function observe(context, character)
        local ok, failure = pcall(function()
            if playerSource then
                local parameter = playerSource == "argument" and character or context
                if not parameter or not isCurrentPlayer(parameter:get()) then return end
            end
            log("EVENT " .. name)
        end)
        if not ok and not warned[path] then
            warned[path] = true
            log("EVENT_ERROR " .. name .. " " .. tostring(failure):sub(1, 150))
        end
    end

    local ok, pre, post
    if native then
        ok, pre, post = pcall(RegisterHook, path, observe, function() end)
    else
        ok, pre, post = pcall(RegisterHook, path, observe)
    end
    attached[path] = true -- No retries if registration throws after a partial bind.
    log((ok and "HOOK " or "HOOK_ERROR ") .. name .. " " .. tostring(pre) .. " " .. tostring(post))
end

local function sample()
    for _, route in ipairs(routes) do attach(route) end
    local pawn, global = hilda()
    local state = {"pawn=none"}
    if pawn then
        local world = pawn:GetWorld()
        local mesh = pawn.Mesh
        local animation = valid(mesh) and mesh:GetAnimInstance()
        local hp = global:GetHP(pawn)
        state = {
            "pawn=" .. tostring(pawn:GetAddress()),
            "world=" .. (valid(world) and world:GetFullName() .. "@" .. tostring(world:GetAddress()) or "none"),
            "hp=" .. (type(hp) == "number" and (hp > 0 and "positive" or "nonpositive") or "unknown"),
            "anim=" .. (valid(animation) and animation:GetClass():GetFName():ToString() or "none"),
        }
    end
    for _, route in ipairs(readiness) do
        state[#state + 1] = route[1] .. "=" .. tostring(valid(StaticFindObject(route[2])))
    end
    local snapshot = table.concat(state, " ")
    if snapshot ~= lastSnapshot then
        lastSnapshot = snapshot
        log("STATE " .. snapshot)
    end
end

local handle = LoopInGameThreadWithDelay(100, function()
    local ok, failure = pcall(sample)
    if not ok and not warned.sample then
        warned.sample = true
        log("SAMPLE_ERROR " .. tostring(failure):sub(1, 150))
    end
end)
log("LOADED handle=" .. tostring(handle))
