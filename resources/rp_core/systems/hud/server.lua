local EVENT_SHOW = "rp:hud:show"
local EVENT_HIDE = "rp:hud:hide"
local EVENT_UPDATE = "rp:hud:update"
local EVENT_REQUEST = "rp:hud:requestSync"
local EVENT_TIME_TOGGLE = "rp:time:toggle"

local snapshots = {}
local spectateTargets = {}

local function requiredExperience(level)
    if getPlayerRequiredExperience then
        return getPlayerRequiredExperience(level)
    end
    return math.max(1, tonumber(level) or 1) * 4
end

local function playerName(player)
    return getElementData(player, "rp:name")
        or getElementData(player, "auth:rpName")
        or getPlayerName(player)
        or "Unknown"
end

local function weaponData(player)
    local weapon = getPedWeapon(player) or 0
    local clip = getPedAmmoInClip(player) or 0
    local total = getPedTotalAmmo(player) or 0

    return {
        id = weapon,
        clip = clip,
        total = total,
        reserve = math.max(0, total - clip)
    }
end

local function collectHudData(player)
    local level = tonumber(getElementData(player, "rp:level")) or 1

    return {
        player = {
            name = playerName(player),
            id = tonumber(getElementData(player, "rp:id")) or 0,
            accountId = tonumber(getElementData(player, "auth:playerId")) or 0
        },
        progression = {
            level = level,
            experience = tonumber(getElementData(player, "rp:experience")) or 0,
            requiredExperience = requiredExperience(level)
        },
        economy = {
            money = getPlayerMoney(player) or 0
        },
        vitals = {
            health = math.max(0, math.min(100, getElementHealth(player) or 0)),
            armor = math.max(0, math.min(100, getPedArmor(player) or 0))
        },
        weapon = weaponData(player),
        faction = getElementData(player, "rp:faction") or false
    }
end

local function flatten(data)
    return {
        name = data.player.name,
        id = data.player.id,
        accountId = data.player.accountId,
        level = data.progression.level,
        experience = data.progression.experience,
        requiredExperience = data.progression.requiredExperience,
        money = data.economy.money,
        health = data.vitals.health,
        armor = data.vitals.armor,
        weaponId = data.weapon.id,
        weaponClip = data.weapon.clip,
        weaponTotal = data.weapon.total,
        weaponReserve = data.weapon.reserve,
        faction = data.faction
    }
end

local function diffSnapshot(old, new)
    if not old then return new end

    local changed = {}
    local hasChanges = false

    for key, value in pairs(new) do
        if old[key] ~= value then
            changed[key] = value
            hasChanges = true
        end
    end

    return hasChanges and changed or false
end

local function isHudPlayer(player)
    return isElement(player) and getElementType(player) == "player" and getElementData(player, "auth:loggedIn")
end

local function getHudSubject(viewer)
    local target = spectateTargets[viewer]
    if isHudPlayer(target) then return target end
    spectateTargets[viewer] = nil
    return viewer
end

local function syncViewer(viewer, force)
    if not isHudPlayer(viewer) then return false end

    local subject = getHudSubject(viewer)
    if not isHudPlayer(subject) then return false end

    local data = collectHudData(subject)
    local flat = flatten(data)
    local changed = force and flat or diffSnapshot(snapshots[viewer], flat)

    snapshots[viewer] = flat

    if changed then
        triggerClientEvent(viewer, EVENT_UPDATE, resourceRoot, changed)
    end

    return data
end

local function showHud(viewer, subject)
    if not isHudPlayer(viewer) then return end

    subject = isHudPlayer(subject) and subject or getHudSubject(viewer)
    if not isHudPlayer(subject) then return end

    local data = collectHudData(subject)
    snapshots[viewer] = flatten(data)
    triggerClientEvent(viewer, EVENT_SHOW, resourceRoot, data)
end

local function hideHud(viewer)
    if not isElement(viewer) then return end
    snapshots[viewer] = nil
    triggerClientEvent(viewer, EVENT_HIDE, resourceRoot)
end

addEvent("rp:timeRequested", false)

function togglePlayerTime(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    triggerClientEvent(player, EVENT_TIME_TOGGLE, resourceRoot, getRealTime().timestamp)
    triggerEvent("rp:timeRequested", player)
    return true
end

addCommandHandler("time", function(player)
    togglePlayerTime(player)
end)

local function updateSubject(subject, force)
    if not isElement(subject) then return end

    for _, viewer in ipairs(getElementsByType("player")) do
        if viewer == subject or spectateTargets[viewer] == subject then
            syncViewer(viewer, force)
        end
    end
end

addEvent("auth:spawned", true)
addEventHandler("auth:spawned", root, function(player)
    if not isElement(player) then return end
    if client and client ~= player then return end
    showHud(player, player)
end)

addEvent(EVENT_REQUEST, true)
addEventHandler(EVENT_REQUEST, root, function()
    if client ~= source then return end
    showHud(client)
end)

addEvent("admin:spectateHudTarget", true)
addEventHandler("admin:spectateHudTarget", root, function(target)
    if client ~= source or not isHudPlayer(client) then return end

    if isHudPlayer(target) and target ~= client then
        spectateTargets[client] = target
        showHud(client, target)
        return
    end

    spectateTargets[client] = nil
    showHud(client, client)
end)

addEventHandler("onElementDataChange", root, function(key)
    if getElementType(source) ~= "player" then return end
    if key == "auth:loggedIn" and not getElementData(source, "auth:loggedIn") then
        hideHud(source)
        for viewer, target in pairs(spectateTargets) do
            if target == source then
                spectateTargets[viewer] = nil
                showHud(viewer, viewer)
            end
        end
        return
    end
    if key ~= "rp:name" and key ~= "auth:rpName" and key ~= "rp:id" and key ~= "rp:level" and key ~= "rp:experience" and key ~= "rp:faction" then return end
    updateSubject(source, false)
end)

addEventHandler("onPlayerDamage", root, function()
    updateSubject(source, false)
end)

addEventHandler("onPlayerWasted", root, function()
    updateSubject(source, true)
end)

addEventHandler("onPlayerSpawn", root, function()
    if getElementData(source, "auth:loggedIn") then
        updateSubject(source, true)
    end
end)

addEventHandler("onPlayerWeaponSwitch", root, function()
    updateSubject(source, false)
end)

addEventHandler("onPlayerWeaponFire", root, function()
    updateSubject(source, false)
end)

addEventHandler("onPlayerMoneyChange", root, function()
    updateSubject(source, false)
end)

addEventHandler("onPlayerQuit", root, function()
    snapshots[source] = nil
    spectateTargets[source] = nil
    for viewer, target in pairs(spectateTargets) do
        if target == source then
            spectateTargets[viewer] = nil
            showHud(viewer, viewer)
        end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        hideHud(player)
    end
end)

function showPlayerHUD(player)
    showHud(player)
    return true
end

function hidePlayerHUD(player)
    hideHud(player)
    return true
end

function updatePlayerHUD(player)
    updateSubject(player, true)
    return true
end
