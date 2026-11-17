AdminActions = {}

local function vecNear(player)
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local rad = math.rad(rz)
    return x - math.sin(rad) * 1.5, y + math.cos(rad) * 1.5, z
end

local function message(player, text, good)
    RPNotifications.send(player, text, good and 102 or 239, good and 187 or 83, good and 106 or 80)
end

local function setHealth(player, value)
    setElementHealth(player, math.max(1, math.min(100, tonumber(value) or 100)))
end

local function setArmor(player, value)
    setPedArmor(player, math.max(0, math.min(100, tonumber(value) or 0)))
end

local function cleanReason(value, fallback)
    if type(value) ~= "string" then return fallback end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return fallback end
    return value
end

local function targetName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Unknown"
end

local function adminName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Console"
end

local function logAction(action, admin, target, reason, details)
    if RPBans and RPBans.logAction then
        RPBans.logAction(action, admin, targetName(target), getPlayerSerial(target), tonumber(getElementData(target, "rp:id")) or 0, reason, details)
    else
        outputDebugString(string.format("[AdminLog] %s | admin=%s target=%s reason=%s", tostring(action), adminName(admin), targetName(target), tostring(reason)), 3)
    end
end

local function applyConfiguredAdminVehicleHandling(vehicle)
    if not isElement(vehicle) then return false end
    local resource = getResourceFromName("rp_car")
    if not resource or getResourceState(resource) ~= "running" then return false end
    local ok, result = pcall(function()
        return exports.rp_car:applyConfiguredVehicleHandling(vehicle)
    end)
    return ok and result == true
end

local function broadcastAdminNotice(text)
    local recipients = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "auth:loggedIn") then recipients[#recipients + 1] = player end
    end
    RPChat.sendMany(recipients, {
        type = "adminPunishment",
        text = text,
        color = {239, 83, 80}
    })
end

local function formatSeconds(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "бессрочно" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60)
    if days > 0 then return tostring(days) .. " дн." end
    if hours > 0 then return tostring(hours) .. " ч." end
    return tostring(math.max(1, minutes)) .. " мин."
end

local function banDurationText(duration, unit)
    unit = unit or "days"
    if unit == "permanent" then return "навсегда" end
    local amount = math.max(1, math.floor(tonumber(duration) or 1))
    local labels = { minutes = "мин.", hours = "ч.", days = "дн.", weeks = "нед.", months = "мес." }
    return tostring(amount) .. " " .. tostring(labels[unit] or unit)
end

local function safePunishmentName(value)
    value = tostring(value or "")
    if value:match("^[A-Z][A-Za-z]+_[A-Z][A-Za-z]+$") then return value end
    return "указанного игрока"
end

function AdminActions.teleportTo(admin, target)
    local x, y, z = vecNear(target)
    setElementInterior(admin, getElementInterior(target))
    setElementDimension(admin, getElementDimension(target))
    setElementPosition(admin, x, y, z)
    logAction("teleportTo", admin, target, "", "")
    message(admin, "Вы телепортировались к игроку.", true)
end

function AdminActions.teleportHere(admin, target)
    local x, y, z = vecNear(admin)
    setElementInterior(target, getElementInterior(admin))
    setElementDimension(target, getElementDimension(admin))
    setElementPosition(target, x, y, z)
    logAction("teleportHere", admin, target, "", "")
    message(admin, "Игрок телепортирован к вам.", true)
end

function AdminActions.teleportPlayerToPlayer(admin, target, data)
    local destination = AdminCore.getPlayerById(data and data.destinationId)
    if not destination then return false, "Игрок назначения не найден." end
    local x, y, z = vecNear(destination)
    setElementInterior(target, getElementInterior(destination))
    setElementDimension(target, getElementDimension(destination))
    setElementPosition(target, x, y, z)
    message(admin, "Игрок телепортирован к выбранному игроку.", true)
    return true
end

function AdminActions.spawn(admin, target)
    local x, y, z = getElementPosition(target)
    local _, _, rz = getElementRotation(target)
    spawnPlayer(target, x, y, z, rz, getElementModel(target), getElementInterior(target), getElementDimension(target))
    fadeCamera(target, true, 0)
    setCameraTarget(target, target)
    message(admin, "Игрок заспавнен.", true)
end

function AdminActions.kill(admin, target)
    killPed(target)
    message(admin, "Игрок убит.", true)
end

function AdminActions.health(admin, target, data)
    setHealth(target, data and data.value)
    if updatePlayerHUD then updatePlayerHUD(target) end
    message(admin, "Здоровье изменено.", true)
end

function AdminActions.armor(admin, target, data)
    setArmor(target, data and data.value)
    if updatePlayerHUD then updatePlayerHUD(target) end
    message(admin, "Броня изменена.", true)
end

function AdminActions.skin(admin, target, data)
    local skin = math.max(0, math.min(312, tonumber(data and data.value) or getElementModel(target)))
    setElementModel(target, skin)
    message(admin, "Скин изменён.", true)
end

function AdminActions.money(admin, target, data)
    local amount = math.max(0, math.floor(tonumber(data and data.value) or 0))
    setPlayerMoney(target, amount)
    if updatePlayerHUD then updatePlayerHUD(target) end
    message(admin, "Деньги изменены.", true)
end

function AdminActions.level(admin, target, data)
    local level = math.max(1, math.floor(tonumber(data and data.value) or 1))
    setElementData(target, "rp:level", level, true)
    if AuthDBExec and getElementData(target, "auth:playerId") then
        AuthDBExec("UPDATE players SET level = ? WHERE id = ?", level, getElementData(target, "auth:playerId"))
    end
    if updatePlayerHUD then updatePlayerHUD(target) end
    message(admin, "Уровень изменён.", true)
end

function AdminActions.expHour(admin, target, data)
    local amount = math.max(1, math.floor(tonumber(data and data.value) or 1))

    if addPlayerExperience then
        addPlayerExperience(target, amount)
    else
        local exp = (tonumber(getElementData(target, "rp:experience")) or 0) + amount
        setElementData(target, "rp:experience", exp, true)
        if AuthDBExec and getElementData(target, "auth:playerId") then
            AuthDBExec("UPDATE players SET experience = ? WHERE id = ?", exp, getElementData(target, "auth:playerId"))
        end
    end

    message(admin, ("Игроку выдано %d EXP."):format(amount), true)
    if updatePlayerHUD then updatePlayerHUD(target) end
    return true
end

function AdminActions.vehicle(admin, target, data)
    local model = math.max(400, math.min(611, tonumber(data and data.value) or 411))
    local x, y, z = getElementPosition(target)
    local _, _, rz = getElementRotation(target)
    local rad = math.rad(rz)
    local vehicle = createVehicle(model, x - math.sin(rad) * 3, y + math.cos(rad) * 3, z + 0.5, 0, 0, rz)
    if not vehicle then return false, "Не удалось создать транспорт." end

    setElementInterior(vehicle, getElementInterior(target))
    setElementDimension(vehicle, getElementDimension(target))
    applyConfiguredAdminVehicleHandling(vehicle)
    AdminVehicles.register(vehicle, target)
    warpPedIntoVehicle(target, vehicle)
    logAction("vehicle", admin, target, "", "temporaryAdminVehicle=true; vehicleModel=" .. tostring(model))
    message(admin, "Транспорт выдан.", true)
end

function AdminActions.vehicleHealth(admin, target)
    local vehicle = getPedOccupiedVehicle(target)
    if not vehicle then return false, "Игрок не находится в транспорте." end

    local maxHP = tonumber(AdminConfig and AdminConfig.vehicleMaxHealth) or 1000
    local model = getElementModel(vehicle)
    
    -- Get current rotation to fix if needed
    local rx, ry, rz = getElementRotation(vehicle)
    
    -- Fix rotation if upside down
    if math.abs(rx) > 45 or math.abs(ry) > 45 then
        setElementRotation(vehicle, 0, 0, rz)
    end
    
    -- === HEALTH RESTORATION ===
    setElementHealth(vehicle, maxHP)
    if setVehicleEngineHealth then
        setVehicleEngineHealth(vehicle, maxHP)
    end
    
    -- === DOOR RESTORATION ===
    -- Reset all door states (0 = intact and closed)
    for i = 0, 5 do
        setVehicleDoorState(vehicle, i, 0)
    end
    
    -- === PANEL RESTORATION ===
    -- Set all vehicle panels to intact state (0 = undamaged)
    -- Expanded range to include windows and other components
    if setVehiclePanelState then
        for i = 0, 15 do
            setVehiclePanelState(vehicle, i, 0)
        end
    end
    
    -- === DEFORMATION GROUP RESTORATION ===
    -- Reset all deformation groups with expanded range
    if setVehicleDeformationGroup then
        for i = 0, 30 do
            setVehicleDeformationGroup(vehicle, i, 0)
        end
    end
    
    -- === WINDOW RESTORATION ===
    -- Try multiple methods to restore windows
    for i = 0, 3 do
        -- Method 1: smashVehicleWindow with false (should restore)
        if smashVehicleWindow then
            smashVehicleWindow(vehicle, i, false)
        end
        
        -- Method 2: setVehicleComponentVisible (make sure visible)
        if setVehicleComponentVisible then
            setVehicleComponentVisible(vehicle, i + 10, true)
        end
    end
    
    -- === LIGHT RESTORATION ===
    -- Fix all lights with expanded range
    if setVehicleLightState then
        for i = 0, 10 do
            setVehicleLightState(vehicle, i, 0)  -- 0 = working
        end
    end
    
    -- Override lights to normal state
    if setVehicleOverrideLights then
        setVehicleOverrideLights(vehicle, 0)  -- 0 = normal
    end
    
    -- === WHEEL/TIRE RESTORATION ===
    -- Fix all tires and wheels
    if setVehicleWheelStates then
        setVehicleWheelStates(vehicle, 0, 0, 0, 0)
    end
    
    if setVehicleTireBlow then
        for i = 0, 3 do
            setVehicleTireBlow(vehicle, i, false)
        end
    end
    
    -- === MISC RESTORATION ===
    -- Reset explosion time
    if resetVehicleExplosionTime then
        resetVehicleExplosionTime(vehicle)
    end
    
    -- Turn off any sirens
    if setVehicleSirensOn then
        setVehicleSirensOn(vehicle, false)
    end
    
    -- Make sure all components are visible
    if setVehicleComponentVisible then
        for i = 0, 20 do
            setVehicleComponentVisible(vehicle, i, true)
        end
    end
    
    -- Try component state restoration if available
    if setVehicleComponentState then
        for i = 0, 20 do
            pcall(function()
                setVehicleComponentState(vehicle, i, 0)
            end)
        end
    end
    
    -- === APPLY FIX ===
    -- Use fixVehicle as final step if available
    if fixVehicle then
        fixVehicle(vehicle)
    end
    
    -- Log action
    local vehicleModel = getVehicleNameFromModel(model) or tostring(model)
    local targetId = tonumber(getElementData(target, "rp:id")) or 0
    local vehicleId = getElementID(vehicle) or "n/a"
    
    local details = string.format(
        "admin=%s targetId=%s vehicle=%s vehicleModel=%s vehicleId=%s restored=%s time=%s",
        tostring(adminName(admin)),
        tostring(targetId),
        tostring(vehicleModel),
        tostring(model),
        tostring(vehicleId),
        tostring(maxHP),
        os.date("%Y-%m-%d %H:%M:%S", getRealTime().timestamp)
    )

    logAction("vehicleRepaired", admin, target, "", details)

    message(admin, string.format("Транспорт %s полностью восстановлен.", vehicleModel), true)
    return true
end

function AdminActions.weapon(admin, target, data)
    local weaponId = math.max(0, math.min(46, tonumber(data and data.value) or 31))
    if weaponId == 0 then
        takeAllWeapons(target)
        if updatePlayerHUD then updatePlayerHUD(target) end
        message(admin, "Оружие снято.", true)
        return
    end

    giveWeapon(target, weaponId, 500, true)
    if updatePlayerHUD then updatePlayerHUD(target) end
    message(admin, "Оружие выдано.", true)
end

function AdminActions.kick(admin, target, data)
    local reason = cleanReason(data and data.reason, "Причина не указана")
    logAction("kick", admin, target, reason, "")
    outputDebugString(string.format("[AdminKick] admin=%s target=%s reason=%s time=%s", adminName(admin), targetName(target), reason, os.date("%Y-%m-%d %H:%M:%S", getRealTime().timestamp)), 3)
    kickPlayer(target, admin, reason)
    return true
end

function AdminActions.ban(admin, target, data)
    if not RPBans or not RPBans.banPlayer then return false, "Система банов недоступна." end
    local reason = cleanReason(data and data.reason, "Причина не указана")
    local duration = tonumber(data and data.duration) or 1
    local unit = data and data.unit or "days"
    local targetRpName = targetName(target)
    local ok, err = RPBans.banPlayer(target, admin, duration, unit, reason)
    if ok then
        if unit == "permanent" then
            broadcastAdminNotice("Администратор " .. adminName(admin) .. " навсегда заблокировал игрока " .. targetRpName .. ". Причина: " .. reason .. ".")
        else
            broadcastAdminNotice("Администратор " .. adminName(admin) .. " заблокировал игрока " .. targetRpName .. " на " .. banDurationText(duration, unit) .. ". Причина: " .. reason .. ".")
        end
    end
    if not ok then return false, err or "Не удалось выдать бан." end
    message(admin, "Игрок заблокирован.", true)
    return true
end

function AdminActions.unban(admin, target, data)
    if not RPBans or not RPBans.unbanPlayerByIdentity then return false, "Система банов недоступна." end
    local reason = cleanReason(data and data.reason, "Unbanned by administrator")
    local identity = cleanReason(data and data.identity, "")
    local rpName = target and targetName(target) or identity
    local serial = target and getPlayerSerial(target) or identity
    if identity == "" and not target then return false, "Укажите RP-ник или Serial." end
    local ok, err = RPBans.unbanPlayerByIdentity(rpName, serial, admin, reason)
    if not ok then return false, err or "Активный бан не найден." end
    local text = "Администратор " .. adminName(admin) .. " снял бан с игрока " .. safePunishmentName(rpName) .. "."
    if reason ~= "" and reason ~= "Unbanned by administrator" then text = text .. " Причина: " .. reason .. "." end
    broadcastAdminNotice(text)
    logAction("unban", admin, target, reason, "identity=" .. tostring(identity))
    message(admin, "Бан снят.", true)
    return true
end

function AdminActions.mute(admin, target, data)
    local duration = tonumber(data and data.duration) or 3600
    local reason = cleanReason(data and data.reason, "Muted by administrator")
    AdminMutes.set(target, adminName(admin), duration, reason)
    logAction("mute", admin, target, reason, "duration=" .. tostring(duration))
    if duration <= 0 then
        broadcastAdminNotice("Администратор " .. adminName(admin) .. " выдал бессрочный мут игроку " .. targetName(target) .. ". Причина: " .. reason .. ".")
    else
        broadcastAdminNotice("Администратор " .. adminName(admin) .. " выдал мут игроку " .. targetName(target) .. " на " .. formatSeconds(duration) .. ". Причина: " .. reason .. ".")
    end
    message(admin, "Игрок замучен.", true)
end

function AdminActions.unmute(admin, target, data)
    local reason = cleanReason(data and data.reason, "")
    AdminMutes.clear(target)
    local text = "Администратор " .. adminName(admin) .. " снял мут с игрока " .. targetName(target) .. "."
    if reason ~= "" then text = text .. " Причина: " .. reason .. "." end
    broadcastAdminNotice(text)
    logAction("unmute", admin, target, reason, "")
    message(admin, "Мут снят.", true)
end

function AdminActions.freeze(admin, target)
    setElementFrozen(target, true)
    setElementData(target, "admin:frozen", true, true)
    toggleAllControls(target, false, true, false)
    triggerClientEvent(target, "admin:freezeControls", resourceRoot, true)
    message(admin, "Игрок заморожен.", true)
end

function AdminActions.unfreeze(admin, target)
    setElementFrozen(target, false)
    removeElementData(target, "admin:frozen")
    toggleAllControls(target, true)
    triggerClientEvent(target, "admin:freezeControls", resourceRoot, false)
    message(admin, "Игрок разморожен.", true)
end

function AdminActions.spectate(admin, target)
    triggerClientEvent(admin, "admin:spectate", resourceRoot, target)
    logAction("spectate", admin, target, "", "")
    message(admin, "Наблюдение включено. Нажмите Backspace, чтобы выйти.", true)
end
