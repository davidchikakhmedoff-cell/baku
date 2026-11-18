local recoverPlayerVehicleParking
local resourceStopping = false
local waitingForPropertyServices = false
local showcaseByElement = {}
local personalByElement = {}
local elementByVehicleId = {}
local personalRuntimeByElement = {}
local purchaseLocks = {}
local sellOffers = {}
local tuningLocks = {}
local tuningSessions = {}
local tuningSessionByVehicle = {}
local usedMarketMarker
local tuningMarkers = {}
local mapBlips = {}
local respawnLocks = {}
local explodedVehicleCleanup = {}
local showcaseTransitions = {}
local animatedExitPending = {}
local lightFlashTokens = {}
local handbrakeVehicles = setmetatable({}, { __mode = "k" })

local function coreRunning()
    local resource = getResourceFromName("rp_core")
    return resource and getResourceState(resource) == "running"
end

local function homeRunning()
    local resource = getResourceFromName("rp_home")
    return resource and getResourceState(resource) == "running"
end

local function notify(player, text, good)
    local c = good and CarConfig.colors.green or CarConfig.colors.red
    if coreRunning() then
        exports.rp_core:sendCoreNotification(player, text, c[1], c[2], c[3])
    else
        outputDebugString("[RP Car] Уведомление не отправлено: rp_core не запущен.", 2)
    end
end

local function debugLog(message)
    if CarConfig.DebugMode then
        local text = tostring(message)
        if text:sub(1, 8) == "[RP CAR]" then
            outputDebugString(text, 3)
        else
            outputDebugString("[RPCar] " .. text, 3)
        end
    end
end

local function debugLock(message)
    outputDebugString("[RP CAR SERVER] " .. tostring(message), 3)
end

local function isLogged(player)
    return isElement(player) and getElementType(player) == "player" and getElementData(player, "auth:loggedIn") == true
end

local function accountId(player)
    if coreRunning() then return tonumber(exports.rp_core:getAuthPlayerId(player)) end
    return tonumber(getElementData(player, "auth:playerId"))
end

local function ownsVehicleRow(player, row)
    local id = accountId(player)
    return row and id and tonumber(row.owner_account_id) == tonumber(id)
end

local function buildPersonalRuntime(row)
    if not row then return false end
    return {
        vehicleId = tonumber(row.id),
        ownerAccountId = tonumber(row.owner_account_id),
        status = tostring(row.status or ""),
        houseId = tonumber(row.house_id) or 0,
        parkingSlot = tonumber(row.parking_slot) or 0,
        tonerPercent = tonumber(row.toner_percent) or 0,
        tonerLobPercent = tonumber(row.toner_lob_percent) or 0,
        tonerFrontPercent = tonumber(row.toner_front_percent) or 0,
        tonerRearPercent = tonumber(row.toner_rear_percent) or tonumber(row.toner_percent) or 0,
        locked = tonumber(row.locked) == 1,
        engineOn = tonumber(row.engine_on) == 1,
        lightsOn = tonumber(row.lights_on) == 1
    }
end

local function clampRuntimeTonerPercent(value)
    value = tonumber(value) or 0
    value = math.floor(value / 10 + 0.5) * 10
    return math.max(0, math.min(100, value))
end

local function tonerStateForClient(row)
    return {
        lob = clampRuntimeTonerPercent(row and row.toner_lob_percent),
        front = clampRuntimeTonerPercent(row and row.toner_front_percent),
        rear = clampRuntimeTonerPercent((row and row.toner_rear_percent) or (row and row.toner_percent))
    }
end

local function syncVehicleToner(vehicle, row, target)
    if not isElement(vehicle) or not row then return false end
    local state = tonerStateForClient(row)
    local recipient = (target and isElement(target)) and target or root
    triggerClientEvent(recipient, CarConfig.events.applyTonerPreview, resourceRoot, vehicle, state)
    setTimer(function(syncTarget, syncVehicle, syncState)
        if isElement(syncVehicle) then
            local timerRecipient = (syncTarget and isElement(syncTarget)) and syncTarget or root
            triggerClientEvent(timerRecipient, CarConfig.events.applyTonerPreview, resourceRoot, syncVehicle, syncState)
        end
    end, 500, 1, target, vehicle, state)
    setTimer(function(syncTarget, syncVehicle, syncState)
        if isElement(syncVehicle) then
            local timerRecipient = (syncTarget and isElement(syncTarget)) and syncTarget or root
            triggerClientEvent(timerRecipient, CarConfig.events.applyTonerPreview, resourceRoot, syncVehicle, syncState)
        end
    end, 1500, 1, target, vehicle, state)
    return true
end

local function syncAllVehicleToners(target)
    for vehicle, vehicleId in pairs(personalByElement) do
        local row = RPCarDB and RPCarDB.vehicles and RPCarDB.vehicles[tonumber(vehicleId) or 0]
        if isElement(vehicle) and row then
            syncVehicleToner(vehicle, row, target)
        end
    end
end

local function setPersonalRuntime(vehicle, row)
    if not isElement(vehicle) or not row then return false end
    local data = buildPersonalRuntime(row)
    if not data or not data.vehicleId then return false end

    personalByElement[vehicle] = data.vehicleId
    elementByVehicleId[data.vehicleId] = vehicle
    personalRuntimeByElement[vehicle] = data

    setElementData(vehicle, "car:personal", true, true)
    setElementData(vehicle, "car:vehicleId", data.vehicleId, true)
    setElementData(vehicle, "car:ownerAccountId", data.ownerAccountId, true)
    setElementData(vehicle, "car:customName", row.custom_name, true)
    setElementData(vehicle, "car:tonerPercent", data.tonerPercent, true)
    setElementData(vehicle, "car:tonerLobPercent", data.tonerLobPercent, true)
    setElementData(vehicle, "car:tonerFrontPercent", data.tonerFrontPercent, true)
    setElementData(vehicle, "car:tonerRearPercent", data.tonerRearPercent, true)
    setElementData(vehicle, "car:houseId", data.houseId, false)
    setElementData(vehicle, "car:parkingSlot", data.parkingSlot, false)
    setElementData(vehicle, "rp_car:personal", true, true)
    setElementData(vehicle, "rp_car:id", data.vehicleId, true)
    setElementData(vehicle, "rp_car:ownerAccountId", data.ownerAccountId, true)
    setElementData(vehicle, "rp_car:tonerPercent", data.tonerPercent, true)
    setElementData(vehicle, "rp_car:tonerLobPercent", data.tonerLobPercent, true)
    setElementData(vehicle, "rp_car:tonerFrontPercent", data.tonerFrontPercent, true)
    setElementData(vehicle, "rp_car:tonerRearPercent", data.tonerRearPercent, true)
    syncVehicleToner(vehicle, row)
    return true
end

local function clearPersonalRuntime(vehicle, vehicleId)
    vehicleId = tonumber(vehicleId) or (isElement(vehicle) and tonumber(personalByElement[vehicle]))
    if isElement(vehicle) then
        personalRuntimeByElement[vehicle] = nil
        personalByElement[vehicle] = nil
    end
    if vehicleId then
        elementByVehicleId[vehicleId] = nil
    end
end

local function getPersonalRuntime(vehicle)
    if not isElement(vehicle) then return false end
    local data = personalRuntimeByElement[vehicle]
    if data and data.vehicleId then return data end

    local vehicleId = tonumber(personalByElement[vehicle]) or tonumber(getElementData(vehicle, "car:vehicleId")) or tonumber(getElementData(vehicle, "rp_car:id"))
    local row = vehicleId and RPCarDB and RPCarDB.vehicles and RPCarDB.vehicles[vehicleId]
    if row and setPersonalRuntime(vehicle, row) then
        return personalRuntimeByElement[vehicle]
    end
    return false
end

local function ownsVehicleRuntime(player, data)
    local id = accountId(player)
    return data and id and tonumber(data.ownerAccountId) == tonumber(id)
end

local function rpName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Unknown"
end

local function isAdmin(player, permission)
    if not coreRunning() then return false end
    if exports.rp_core.hasAdminPermission then
        local ok, allowed = pcall(function()
            return exports.rp_core:hasAdminPermission(player, permission or "adminVehicles")
        end)
        if ok then return allowed == true end
    end
    return (tonumber(exports.rp_core:getCoreAdminLevel(player)) or 0) >= 10
end

local function addAccountMoney(id, amount)
    if not coreRunning() then return false end
    local ok, result = pcall(function()
        return exports.rp_core:addAuthAccountMoney(id, amount)
    end)
    return ok and result == true
end

local function changePlayerMoney(player, amount)
    if not coreRunning() or not isElement(player) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then
        local ok, result = pcall(function()
            return exports.rp_core:giveAuthPlayerMoney(player, amount)
        end)
        if ok then return result == true end
    elseif amount < 0 then
        local ok, result = pcall(function()
            return exports.rp_core:takeAuthPlayerMoney(player, math.abs(amount))
        end)
        if ok then return result == true end
    end
    local id = accountId(player)
    return id and addAccountMoney(id, amount) or false
end

local function getPlayerBalance(player)
    if coreRunning() then
        local ok, balance = pcall(function()
            return exports.rp_core:getAuthPlayerBalance(player)
        end)
        if ok then return tonumber(balance) or 0 end
    end
    return getPlayerMoney(player) or 0
end

local function creditAccountOrPlayer(accountIdValue, player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if isElement(player) and accountId(player) == tonumber(accountIdValue) then
        return changePlayerMoney(player, amount)
    end
    return addAccountMoney(accountIdValue, amount)
end

local function getPlayerHouse(player)
    if not homeRunning() then return false end
    return exports.rp_home:getPlayerHouse(player)
end

local function getHouseParkingSpaces(houseId)
    if not homeRunning() then return {} end
    return exports.rp_home:getHouseParkingSpaces(tonumber(houseId) or 0) or {}
end

local function getHouseData(houseId)
    if not homeRunning() then return false end
    return exports.rp_home:getHouseData(tonumber(houseId) or 0)
end

local function accountOwnsHouse(accountIdValue, houseId)
    local house = getHouseData(houseId)
    return house and tonumber(house.owner_account_id) == tonumber(accountIdValue)
end

local function countPlayerVehicles(id)
    local count = 0
    id = tonumber(id) or 0
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.owner_account_id) == id then count = count + 1 end
    end
    return count
end

local function findOccupiedSlots(houseId)
    local occupied = {}
    houseId = tonumber(houseId) or 0
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.house_id) == houseId and tonumber(row.parking_slot) > 0 then
            occupied[tonumber(row.parking_slot)] = tonumber(row.id)
        end
    end
    return occupied
end

local function isVehicleStoredWithoutParking(row)
    local status = tostring(row and row.status or "")
    return status == VehicleStatuses.noParking or status == VehicleStatuses.stored
end

local function isUnparkedActiveVehicle(row)
    return row and tostring(row.status) == VehicleStatuses.active
        and (tonumber(row.house_id) or 0) == 0 and (tonumber(row.parking_slot) or 0) == 0
end

local function findFreeParking(houseId)
    local spaces = getHouseParkingSpaces(houseId)
    local occupied = findOccupiedSlots(houseId)
    table.sort(spaces, function(a, b) return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) end)
    for _, space in ipairs(spaces) do
        local slot = tonumber(space.slot) or 0
        if slot > 0 and not occupied[slot] then return space end
    end
    return false
end

local function publicParkingSummary(player)
    local house = getPlayerHouse(player)
    if not house or not house.id then return { hasHouse = false, total = 0, used = 0, free = 0 } end
    local spaces = getHouseParkingSpaces(house.id)
    local used = 0
    local occupied = findOccupiedSlots(house.id)
    for _ in pairs(occupied) do used = used + 1 end
    return { hasHouse = true, houseId = tonumber(house.id), total = #spaces, used = used, free = math.max(0, #spaces - used) }
end

local function isDeliveryClear(point)
    local radius = tonumber(CarConfig.deliveryClearRadius) or 4
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        local vx, vy, vz = getElementPosition(vehicle)
        if getElementInterior(vehicle) == (point.interior or 0) and getElementDimension(vehicle) == (point.dimension or 0)
            and getDistanceBetweenPoints3D(vx, vy, vz, point.x, point.y, point.z) <= radius then
            return false
        end
    end
    return true
end

local function shiftedDeliveryPoint(point)
    if isDeliveryClear(point) then return point end
    for i = 1, 6 do
        local candidate = {
            x = point.x + (i * 3),
            y = point.y,
            z = point.z,
            rotation = point.rotation or 0,
            interior = point.interior or 0,
            dimension = point.dimension or 0
        }
        if isDeliveryClear(candidate) then return candidate end
    end
    return false
end

local function createNamedBlip(x, y, z, icon, size, colorData, visibleDistance, name)
    colorData = colorData or {255, 255, 255, 255}
    local blip = createBlip(x, y, z, tonumber(icon) or 0, tonumber(size) or 2,
        tonumber(colorData[1]) or 255, tonumber(colorData[2]) or 255, tonumber(colorData[3]) or 255, tonumber(colorData[4]) or 255,
        0, tonumber(visibleDistance) or 250)
    if blip then
        setElementData(blip, "name", tostring(name or ""), true)
        setElementData(blip, "blip:name", tostring(name or ""), true)
        mapBlips[#mapBlips + 1] = blip
    end
    return blip
end

local function destroyMapBlips()
    for _, blip in ipairs(mapBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    mapBlips = {}
end

local function createMapBlips()
    destroyMapBlips()
    for _, dealership in ipairs(Dealerships or {}) do
        local p = dealership.playerSpawn or dealership.purchasedVehicleSpawn or ((dealership.vehicles or {})[1] and (dealership.vehicles or {})[1].position)
        if p then
            createNamedBlip(p.x, p.y, p.z, dealership.blipIcon, dealership.blipSize, dealership.blipColor, dealership.blipVisibleDistance, dealership.name)
        end
    end
    local market = CarConfig.usedMarket or {}
    local m = market.marker or {}
    createNamedBlip(m.x, m.y, m.z, market.blipIcon, market.blipSize, market.blipColor, market.blipVisibleDistance, market.name)
    for _, shop in ipairs(TuningShops or {}) do
        local b = shop.blip or shop.marker or {}
        createNamedBlip(b.x, b.y, b.z, b.icon or 27, b.size or 2, b.color or {79, 195, 247, 255}, b.visibleDistance or 250, shop.name)
    end
end

local function getVehicleUpgradesString(vehicle)
    local parts = {}
    for _, upgrade in ipairs(getVehicleUpgrades(vehicle) or {}) do
        parts[#parts + 1] = tostring(upgrade)
    end
    return table.concat(parts, ",")
end

local function applyVehicleUpgradesString(vehicle, value)
    for upgrade in tostring(value or ""):gmatch("%d+") do
        addVehicleUpgrade(vehicle, tonumber(upgrade))
    end
end

local supportedHandlingProperties = {
    mass = true,
    turnMass = true,
    dragCoeff = true,
    centerOfMass = true,
    percentSubmerged = true,
    tractionMultiplier = true,
    tractionLoss = true,
    tractionBias = true,
    numberOfGears = true,
    maxVelocity = true,
    engineAcceleration = true,
    engineInertia = true,
    driveType = true,
    engineType = true,
    brakeDeceleration = true,
    brakeBias = true,
    ABS = true,
    steeringLock = true,
    suspensionForceLevel = true,
    suspensionDamping = true,
    suspensionHighSpeedDamping = true,
    suspensionUpperLimit = true,
    suspensionLowerLimit = true,
    suspensionFrontRearBias = true,
    suspensionAntiDiveMultiplier = true,
    seatOffsetDistance = true,
    collisionDamageMultiplier = true,
    monetary = true,
    modelFlags = true,
    handlingFlags = true,
    headLight = true,
    tailLight = true,
    animGroup = true
}

local tuningFields = {
    suspension = "suspension_level",
    acceleration = "acceleration_level",
    max_speed = "max_speed_level"
}

local function clampTuneLevel(value, maxLevel)
    return math.max(0, math.min(tonumber(maxLevel) or 3, math.floor(tonumber(value) or 0)))
end

local function handlingValue(vehicle, base, property)
    if base and base[property] ~= nil then return base[property] end
    local current = isElement(vehicle) and getVehicleHandling(vehicle) or {}
    return current and current[property]
end

local function handlingDeltaValue(levels, level, property)
    local data = levels and levels[clampTuneLevel(level, 3)] or nil
    return data and tonumber(data[property]) or 0
end

local function tuningLevelsForCategory(category)
    if category == "acceleration" then return AccelerationLevels end
    if category == "max_speed" then return MaxSpeedLevels end
    return nil
end

local function isSuspensionTunable(model)
    return VehicleSuspensionLevels and VehicleSuspensionLevels[tonumber(model)] ~= nil
end

local function suspensionLevelValue(model, level, base)
    model = tonumber(model) or 0
    level = clampTuneLevel(level, 3)
    if level == 0 then
        return tonumber(base and base.suspensionLowerLimit), tonumber(base and base.suspensionUpperLimit)
    end

    local levels = VehicleSuspensionLevels and VehicleSuspensionLevels[model]
    local value = levels and levels[level]
    if type(value) == "table" then
        return tonumber(value.lowerLimit or value.suspensionLowerLimit), tonumber(value.upperLimit or value.suspensionUpperLimit)
    end
    return tonumber(value), nil
end

local function applySuspensionLevel(vehicle, model, level, base)
    if not isElement(vehicle) or not isSuspensionTunable(model) then return false end
    local lowerLimit, upperLimit = suspensionLevelValue(model, level, base)
    if lowerLimit ~= nil then setVehicleHandling(vehicle, "suspensionLowerLimit", lowerLimit) end
    if upperLimit ~= nil then setVehicleHandling(vehicle, "suspensionUpperLimit", upperLimit) end
    return lowerLimit ~= nil or upperLimit ~= nil
end

local function applyConfiguredHandling(vehicle, row)
    if not isElement(vehicle) then return false end
    local model = tonumber(row and row.model) or getElementModel(vehicle)
    local base = VehicleHandling and VehicleHandling[model] or nil
    if base then
        for property, value in pairs(base) do
            if supportedHandlingProperties[property] and value ~= nil then
                setVehicleHandling(vehicle, property, value)
            end
        end
    end

    local tune = TunableVehicles and TunableVehicles[model] or nil
    if row and tune then
        local maxLevel = tonumber(tune.maxLevel) or 3
        local maxSpeedLevel = clampTuneLevel(row.max_speed_level, maxLevel)
        local accelerationLevel = clampTuneLevel(row.acceleration_level, maxLevel)
        local suspensionLevel = clampTuneLevel(row.suspension_level, maxLevel)
        local maxSpeedMultiplier = tonumber(tune.maxSpeedMultiplier) or 1
        local accelerationMultiplier = tonumber(tune.accelerationMultiplier) or 1

        local baseMaxVelocity = tonumber(handlingValue(vehicle, base, "maxVelocity"))
        if baseMaxVelocity then
            setVehicleHandling(vehicle, "maxVelocity", baseMaxVelocity + handlingDeltaValue(MaxSpeedLevels, maxSpeedLevel, "maxVelocity") * maxSpeedMultiplier)
        end

        local baseAcceleration = tonumber(handlingValue(vehicle, base, "engineAcceleration"))
        if baseAcceleration then
            setVehicleHandling(vehicle, "engineAcceleration", baseAcceleration + handlingDeltaValue(AccelerationLevels, accelerationLevel, "engineAcceleration") * accelerationMultiplier)
        end

        applySuspensionLevel(vehicle, model, suspensionLevel, base)
    end
    return true
end

function applyConfiguredVehicleHandling(vehicle)
    return applyConfiguredHandling(vehicle, nil)
end

function applyPersonalVehicleHandling(vehicle)
    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    return applyConfiguredHandling(vehicle, row)
end

local function tuningPrice(tune, category, level)
    level = clampTuneLevel(level, tonumber(tune and tune.maxLevel) or 3)
    if category == "suspension" then
        local prices = tune and tune.prices and tune.prices.suspension
        if type(prices) == "table" and prices[level] ~= nil then return math.floor(tonumber(prices[level]) or 0) end
        if type(prices) == "number" then return math.floor(tonumber(prices) or 0) end
        return math.floor(tonumber(SuspensionLevelPrices and SuspensionLevelPrices[level]) or 0)
    end
    if level == 0 then
        local standard = tuningLevelsForCategory(category)
        local standardData = standard and standard[0]
        return math.floor(tonumber(standardData and standardData.price) or 0)
    end

    local prices = tune and tune.prices and tune.prices[category]
    if type(prices) == "table" and prices[level] ~= nil then return math.floor(tonumber(prices[level]) or 0) end
    if type(prices) == "number" then return math.floor(tonumber(prices) or 0) end

    local levels = tuningLevelsForCategory(category)
    local data = levels and levels[level]
    if data and data.price ~= nil then return math.floor(tonumber(data.price) or 0) end
    return nil
end

local function tuningSummary(row)
    if not row then return false end
    local model = tonumber(row.model) or 0
    local base = VehicleHandling and VehicleHandling[model] or {}
    local tune = TunableVehicles and TunableVehicles[model] or nil
    local maxLevel = tune and (tonumber(tune.maxLevel) or 3) or 0
    local levels = {
        suspension = clampTuneLevel(row.suspension_level, maxLevel),
        acceleration = clampTuneLevel(row.acceleration_level, maxLevel),
        max_speed = clampTuneLevel(row.max_speed_level, maxLevel)
    }
    local baseMaxVelocity = tonumber(base.maxVelocity) or 0
    local baseAcceleration = tonumber(base.engineAcceleration) or 0
    local baseSuspension = tonumber(base.suspensionLowerLimit) or 0
    local maxSpeedMultiplier = tune and (tonumber(tune.maxSpeedMultiplier) or 1) or 0
    local accelerationMultiplier = tune and (tonumber(tune.accelerationMultiplier) or 1) or 0
    local suspensionAvailable = tune ~= nil and isSuspensionTunable(model)
    local prices = { suspension = {}, acceleration = {}, max_speed = {} }
    local valueLevels = { suspension = {}, acceleration = {}, max_speed = {} }
    if tune then
        for level = 0, maxLevel do
            prices.suspension[level] = suspensionAvailable and (tuningPrice(tune, "suspension", level) or 0) or 0
            prices.acceleration[level] = tuningPrice(tune, "acceleration", level) or 0
            prices.max_speed[level] = tuningPrice(tune, "max_speed", level) or 0
            valueLevels.suspension[level] = suspensionAvailable and (suspensionLevelValue(model, level, base) or baseSuspension) or false
            valueLevels.acceleration[level] = baseAcceleration + handlingDeltaValue(AccelerationLevels, level, "engineAcceleration") * accelerationMultiplier
            valueLevels.max_speed[level] = baseMaxVelocity + handlingDeltaValue(MaxSpeedLevels, level, "maxVelocity") * maxSpeedMultiplier
        end
    end
    return {
        vehicleId = row.id,
        name = getVehicleDisplayName(row.model, row.custom_name or (base and base.name)),
        model = model,
        tunable = tune ~= nil,
        suspensionAvailable = suspensionAvailable,
        toner = {
            installed = math.max(0, math.min(100, math.floor((tonumber(row.toner_percent) or 0) / 10 + 0.5) * 10)),
            zones = {
                lob = math.max(0, math.min(100, math.floor((tonumber(row.toner_lob_percent) or 0) / 10 + 0.5) * 10)),
                front = math.max(0, math.min(100, math.floor((tonumber(row.toner_front_percent) or 0) / 10 + 0.5) * 10)),
                rear = math.max(0, math.min(100, math.floor((tonumber(row.toner_rear_percent) or tonumber(row.toner_percent) or 0) / 10 + 0.5) * 10))
            },
            min = 0,
            max = 100,
            step = 10,
            price = math.max(0, math.floor(tonumber(CarConfig.tonerPrice) or 0))
        },
        maxLevel = maxLevel,
        levels = levels,
        prices = prices,
        valueLevels = valueLevels,
        values = {
            maxVelocity = baseMaxVelocity + handlingDeltaValue(MaxSpeedLevels, levels.max_speed, "maxVelocity") * maxSpeedMultiplier,
            acceleration = baseAcceleration + handlingDeltaValue(AccelerationLevels, levels.acceleration, "engineAcceleration") * accelerationMultiplier,
            suspension = suspensionAvailable and (suspensionLevelValue(model, levels.suspension, base) or baseSuspension) or false
        },
        next = tune and {
            suspension = suspensionAvailable and levels.suspension < maxLevel and {
                level = levels.suspension + 1,
                price = tuningPrice(tune, "suspension", levels.suspension + 1),
                value = suspensionLevelValue(model, levels.suspension + 1, base) or baseSuspension
            } or false,
            acceleration = levels.acceleration < maxLevel and {
                level = levels.acceleration + 1,
                price = tuningPrice(tune, "acceleration", levels.acceleration + 1),
                value = baseAcceleration + handlingDeltaValue(AccelerationLevels, levels.acceleration + 1, "engineAcceleration") * accelerationMultiplier
            } or false,
            max_speed = levels.max_speed < maxLevel and {
                level = levels.max_speed + 1,
                price = tuningPrice(tune, "max_speed", levels.max_speed + 1),
                value = baseMaxVelocity + handlingDeltaValue(MaxSpeedLevels, levels.max_speed + 1, "maxVelocity") * maxSpeedMultiplier
            } or false
        } or {}
    }
end

local function parkingPointFor(row)
    if not row or isVehicleStoredWithoutParking(row) or not homeRunning() then return false end
    local houseId = tonumber(row.house_id) or 0
    local parkingSlot = tonumber(row.parking_slot) or 0
    if houseId == 0 or parkingSlot <= 0 then return false end
    if not accountOwnsHouse(row.owner_account_id, houseId) then return false end
    for _, space in ipairs(getHouseParkingSpaces(houseId)) do
        if tonumber(space.slot) == parkingSlot then return space end
    end
    return false
end

local function isPointClear(point, ignoreVehicle)
    local radius = tonumber(CarConfig.deliveryClearRadius) or 4
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        if vehicle ~= ignoreVehicle and isElement(vehicle) then
            local vx, vy, vz = getElementPosition(vehicle)
            if getElementInterior(vehicle) == (point.interior or 0) and getElementDimension(vehicle) == (point.dimension or 0)
                and getDistanceBetweenPoints3D(vx, vy, vz, point.x, point.y, point.z) <= radius then
                return false
            end
        end
    end
    return true
end

local function safeExitPoint(vehicle)
    if not vehicle or not isElement(vehicle) then return false end
    local showcase = showcaseByElement[vehicle]
    if showcase then
        local dealership = getDealershipById(showcase.dealershipId)
        local p = dealership and dealership.cancelExitPosition
        if p and p.x and p.y and p.z then
            return p.x, p.y, p.z, p.rotation or 0, p.interior or 0, p.dimension or 0
        end
    end
    local x, y, z = getElementPosition(vehicle)
    local _, _, rz = getElementRotation(vehicle)
    local rad = math.rad((rz or 0) + 90)
    return x + math.cos(rad) * 2.2, y + math.sin(rad) * 2.2, z + 0.35, rz or 0, getElementInterior(vehicle), getElementDimension(vehicle)
end

local function resetPlayerCamera(player)
    if not isElement(player) then return end
    setCameraTarget(player, player)
    triggerClientEvent(player, CarConfig.events.resetCamera, resourceRoot)
end

local function restoreShowcaseControls(player)
    if not isElement(player) then return end
    triggerClientEvent(player, CarConfig.events.setControlsEnabled, resourceRoot, true)
end

local function setShowcaseControlsEnabled(player, enabled)
    if not isElement(player) then return end
    triggerClientEvent(player, CarConfig.events.setControlsEnabled, resourceRoot, enabled == true)
end

local function finishDealershipSession(player)
    if not isElement(player) then return end
    restoreShowcaseControls(player)
    resetPlayerCamera(player)
    triggerClientEvent(player, CarConfig.events.closeDealership, resourceRoot)
end

local function movePlayerToSafeExit(player, exitPoint)
    if not isElement(player) or getPedOccupiedVehicle(player) or not exitPoint then return false end
    setElementInterior(player, exitPoint.interior or 0)
    setElementDimension(player, exitPoint.dimension or 0)
    setElementPosition(player, exitPoint.x, exitPoint.y, exitPoint.z)
    setPedRotation(player, exitPoint.rotation or 0)
    return true
end

local function leaveShowcaseVehicle(player, vehicle, moveToExit, callback)
    if not isElement(player) then return false end

    local exitPoint
    if isElement(vehicle) then
        local x, y, z, rotation, interior, dimension = safeExitPoint(vehicle)
        if x then
            exitPoint = {
                x = x, y = y, z = z,
                rotation = rotation or 0,
                interior = interior or 0,
                dimension = dimension or 0
            }
        end
    end

    local function complete(removed)
        if not isElement(player) then return end
        showcaseTransitions[player] = nil
        debugLog("[RP CAR] Player removed from showroom vehicle: " .. (removed and "YES" or "NO"))
        if removed and moveToExit then movePlayerToSafeExit(player, exitPoint) end
        if callback then
            callback(removed, exitPoint)
        else
            finishDealershipSession(player)
        end
    end

    local function checkExit(attempt)
        if not isElement(player) then return end
        local occupied = getPedOccupiedVehicle(player)
        if occupied ~= vehicle then
            complete(true)
            return
        end
        if attempt >= 2 or not isElement(vehicle) then
            complete(false)
            return
        end
        removePedFromVehicle(player)
        setTimer(checkExit, 100, 1, attempt + 1)
    end

    if not isElement(vehicle) or getPedOccupiedVehicle(player) ~= vehicle then
        complete(true)
        return true
    end

    showcaseTransitions[player] = true
    removePedFromVehicle(player)
    setTimer(checkExit, 100, 1, 1)
    return true
end

local function finishAnimatedExit(player, vehicle)
    if not isElement(player) then return end
    animatedExitPending[player] = nil
    showcaseTransitions[player] = nil
    if isElement(vehicle) then
        setElementFrozen(vehicle, true)
        setVehicleEngineState(vehicle, false)
    end
    finishDealershipSession(player)
end

local function beginAnimatedExit(player, vehicle)
    if not isElement(player) or not isElement(vehicle) or not showcaseByElement[vehicle] then
        finishDealershipSession(player)
        return false
    end

    animatedExitPending[player] = vehicle
    showcaseTransitions[player] = true
    setElementFrozen(vehicle, true)
    setVehicleEngineState(vehicle, false)
    resetPlayerCamera(player)
    triggerClientEvent(player, CarConfig.events.beginAnimatedExit, resourceRoot)

    setTimer(function(targetPlayer, showroomVehicle)
        if not isElement(targetPlayer) or animatedExitPending[targetPlayer] ~= showroomVehicle then return end
        if getPedOccupiedVehicle(targetPlayer) ~= showroomVehicle then
            debugLog("[RP CAR] Animated showroom exit: YES")
            finishAnimatedExit(targetPlayer, showroomVehicle)
            return
        end

        debugLog("[RP CAR] Animated showroom exit timed out; using fallback")
        animatedExitPending[targetPlayer] = nil
        showcaseTransitions[targetPlayer] = nil
        leaveShowcaseVehicle(targetPlayer, showroomVehicle, true)
    end, tonumber(CarConfig.animatedExitFallbackDelay) or 3500, 1, player, vehicle)
    return true
end

local function saveVehiclePosition(vehicle)
    local id = getVehicleDatabaseId(vehicle)
    if not id then return false end
    local row = RPCarDB.vehicles[id]
    if not row then return false end
    local x, y, z = getElementPosition(vehicle)
    local rx, ry, rz = getElementRotation(vehicle)
    local r, g, b = getVehicleColor(vehicle, true)
    return RPCarDB.updateVehicle(id, {
        x = x, y = y, z = z, rx = rx, ry = ry, rz = rz,
        interior = getElementInterior(vehicle),
        dimension = getElementDimension(vehicle),
        fuel = FuelSystem and FuelSystem.get(vehicle) or row.fuel,
        health = getElementHealth(vehicle),
        color_r = r or row.color_r,
        color_g = g or row.color_g,
        color_b = b or row.color_b,
        upgrades = getVehicleUpgradesString(vehicle),
        engine_on = row.engine_on,
        locked = row.locked,
        status = row.status
    })
end

local function applyPersonalVehicleState(vehicle, row)
    if not isElement(vehicle) or not row then return end
    local locked = tonumber(row.locked) == 1
    local engineOn = tonumber(row.engine_on) == 1 and (not FuelSystem or FuelSystem.canStart(vehicle))
    local lightsOn = tonumber(row.lights_on) == 1
    setVehicleEngineState(vehicle, engineOn)
    setVehicleLocked(vehicle, locked)
    setVehicleOverrideLights(vehicle, lightsOn and 2 or 1)
    setElementData(vehicle, "car:locked", locked, true)
    setElementData(vehicle, "car:engineOn", engineOn, true)
    setElementData(vehicle, "car:lightsOn", lightsOn, true)
    setElementData(vehicle, "rp_car:locked", locked, true)
    setElementData(vehicle, "rp_car:engineOn", engineOn, true)
    setElementData(vehicle, "rp_car:lightsOn", lightsOn, true)

    local data = personalRuntimeByElement[vehicle]
    if data then
        data.locked = locked
        data.engineOn = engineOn
        data.lightsOn = lightsOn
        data.status = tostring(row.status or "")
        data.houseId = tonumber(row.house_id) or 0
        data.parkingSlot = tonumber(row.parking_slot) or 0
        data.ownerAccountId = tonumber(row.owner_account_id)
    end
end

local function resetVehicleToParkingState(vehicleId, point)
    vehicleId = tonumber(vehicleId)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return false end

    local update = {
        health = 1000,
        engine_on = 0,
        locked = 1,
        lights_on = 0,
        status = VehicleStatuses.parked
    }
    if point then
        update.x = point.x
        update.y = point.y
        update.z = (tonumber(point.z) or 0) + (tonumber(CarConfig.parkingSpawnZOffset) or 0)
        update.rx = point.rx or 0
        update.ry = point.ry or 0
        update.rz = point.rz or 0
        update.interior = point.interior or 0
        update.dimension = point.dimension or 0
    end

    if not RPCarDB.updateVehicle(vehicleId, update) then return false end
    return RPCarDB.vehicles[vehicleId]
end

local function scheduleParkingFreeze(vehicle, vehicleId)
    if not isElement(vehicle) then return end
    setElementFrozen(vehicle, false)
    setTimer(function(targetVehicle, targetId)
        if not isElement(targetVehicle) then return end
        local row = RPCarDB.vehicles[tonumber(targetId) or 0]
        if not row then return end
        applyPersonalVehicleState(targetVehicle, row)
        if tostring(row.status or "") == VehicleStatuses.parked and tonumber(row.engine_on) ~= 1 then
            local x, y, z = getElementPosition(targetVehicle)
            local rx, ry, rz = getElementRotation(targetVehicle)
            RPCarDB.updateVehicle(targetId, {
                x = x, y = y, z = z,
                rx = rx or 0, ry = ry or 0, rz = rz or 0,
                interior = getElementInterior(targetVehicle),
                dimension = getElementDimension(targetVehicle),
                health = 1000,
                engine_on = 0,
                locked = 1,
                lights_on = 0,
                status = VehicleStatuses.parked
            })
            row = RPCarDB.vehicles[tonumber(targetId) or 0] or row
            applyPersonalVehicleState(targetVehicle, row)
            syncVehicleToner(targetVehicle, row)
            setElementVelocity(targetVehicle, 0, 0, 0)
            setElementAngularVelocity(targetVehicle, 0, 0, 0)
            handbrakeVehicles[targetVehicle] = true
            setElementData(targetVehicle, "car:handbrake", true, true)
            setElementFrozen(targetVehicle, true)
        end
    end, tonumber(CarConfig.parkingSettleDelay) or 1000, 1, vehicle, vehicleId)
end

local function createPersonalVehicle(row, parkingSpawn, parkingPoint)
    if not row or isVehicleStoredWithoutParking(row) then return false end
    if tostring(row.status or "") == VehicleStatuses.destroyed then return false end
    if elementByVehicleId[tonumber(row.id)] and isElement(elementByVehicleId[tonumber(row.id)]) then
        local existingVehicle = elementByVehicleId[tonumber(row.id)]
        setPersonalRuntime(existingVehicle, row)
        syncVehicleToner(existingVehicle, row)
        return existingVehicle
    end
    if parkingSpawn or tostring(row.status or "") == VehicleStatuses.parked then
        row = resetVehicleToParkingState(row.id, parkingPoint) or row
    end
    local vehicle = createVehicle(row.model, row.x, row.y, row.z, row.rx, row.ry, row.rz)
    if not vehicle then return false end
    setElementInterior(vehicle, row.interior or 0)
    setElementDimension(vehicle, row.dimension or 0)
    setElementHealth(vehicle, row.health or 1000)
    setVehicleColor(vehicle, row.color_r or 255, row.color_g or 255, row.color_b or 255)
    applyVehicleUpgradesString(vehicle, row.upgrades)
    applyConfiguredHandling(vehicle, row)
    local cacheCreated = setPersonalRuntime(vehicle, row)
    syncVehicleToner(vehicle, row)
    if FuelSystem then FuelSystem.attach(vehicle, row) end
    applyPersonalVehicleState(vehicle, row)
    outputDebugString("[RP CAR] Vehicle spawned", 3)
    outputDebugString("[RP CAR] Vehicle DB ID: " .. tostring(row.id), 3)
    outputDebugString("[RP CAR] Owner account ID: " .. tostring(row.owner_account_id), 3)
    outputDebugString("[RP CAR] Cache created: " .. (cacheCreated and "YES" or "NO"), 3)
    outputDebugString("[RP CAR] Element data set: " .. (getElementData(vehicle, "rp_car:id") and "YES" or "NO"), 3)
    if parkingSpawn or tostring(row.status or "") == VehicleStatuses.parked then
        scheduleParkingFreeze(vehicle, row.id)
    end

    return vehicle
end

local function destroyPersonalVehicle(id, saveFirst)
    id = tonumber(id)
    local vehicle = id and elementByVehicleId[id]
    if vehicle then
        if isElement(vehicle) and saveFirst then saveVehiclePosition(vehicle) end
        if FuelSystem then FuelSystem.detach(vehicle) end
        clearPersonalRuntime(vehicle, id)
        if isElement(vehicle) then destroyElement(vehicle) end
    end
    if id then elementByVehicleId[id] = nil end
end

local function clearVehicleParking(vehicleId, status, keepElement)
    vehicleId = tonumber(vehicleId)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return false end

    local vehicle = elementByVehicleId[vehicleId]
    local update = {
        house_id = 0,
        parking_slot = 0,
        health = 1000,
        engine_on = 0,
        locked = 1,
        lights_on = 0,
        status = status or VehicleStatuses.noParking
    }
    if isElement(vehicle) then
        if keepElement then
            -- Losing real estate removes a parking assignment, not car ownership
            -- or the ability to use a car that is already in the world.
            update.status = VehicleStatuses.active
            update.health = getElementHealth(vehicle)
            update.engine_on = getVehicleEngineState(vehicle) and 1 or 0
            update.locked = isVehicleLocked(vehicle) and 1 or 0
            update.lights_on = row.lights_on
        end
        local x, y, z = getElementPosition(vehicle)
        local rx, ry, rz = getElementRotation(vehicle)
        update.x, update.y, update.z = x, y, z
        update.rx, update.ry, update.rz = rx or 0, ry or 0, rz or 0
        update.interior = getElementInterior(vehicle)
        update.dimension = getElementDimension(vehicle)
    else
        update.x, update.y, update.z = 0, 0, 0
        update.rx, update.ry, update.rz = 0, 0, 0
        update.interior, update.dimension = 0, 0
    end

    local ok = RPCarDB.updateVehicle(vehicleId, update)
    if ok then
        respawnLocks[vehicleId] = nil
        if keepElement and isElement(vehicle) then
            setElementData(vehicle, "car:houseId", 0, false)
            setElementData(vehicle, "car:parkingSlot", 0, false)
            setPersonalRuntime(vehicle, RPCarDB.vehicles[vehicleId])
            applyPersonalVehicleState(vehicle, RPCarDB.vehicles[vehicleId])
            syncVehicleToner(vehicle, RPCarDB.vehicles[vehicleId])
        else
            destroyPersonalVehicle(vehicleId, false)
        end
    end
    return ok
end

local function validateVehicleParking(row)
    if not row or isVehicleStoredWithoutParking(row) then return false end
    local houseId = tonumber(row.house_id) or 0
    local parkingSlot = tonumber(row.parking_slot) or 0
    if houseId == 0 or parkingSlot <= 0 then return false end
    if not accountOwnsHouse(row.owner_account_id, houseId) then return false end
    local point = parkingPointFor(row)
    if not point then return false end
    local occupied, occupiedVehicleId = isHouseParkingSpaceOccupied(houseId, parkingSlot)
    if occupied and tonumber(occupiedVehicleId) ~= tonumber(row.id) then return false end
    return point
end

local function isRowNearParkingPoint(row, point)
    if not row or not point then return false end
    if tonumber(row.interior) ~= (tonumber(point.interior) or 0) then return false end
    if tonumber(row.dimension) ~= (tonumber(point.dimension) or 0) then return false end
    return getDistanceBetweenPoints3D(
        tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0,
        tonumber(point.x) or 0, tonumber(point.y) or 0, tonumber(point.z) or 0
    ) <= 3.5
end

local function respawnPersonalVehicleOnParking(vehicleId, attempt)
    vehicleId = tonumber(vehicleId)
    attempt = tonumber(attempt) or 1
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then respawnLocks[vehicleId] = nil; return false end

    local parking = validateVehicleParking(row)
    if not parking then
        clearVehicleParking(vehicleId, VehicleStatuses.noParking)
        respawnLocks[vehicleId] = nil
        return false
    end
    local point = {
        x = parking.x, y = parking.y, z = parking.z,
        rx = parking.rx or 0, ry = parking.ry or 0, rz = parking.rz or 0,
        interior = parking.interior or 0,
        dimension = parking.dimension or 0
    }

    if not isPointClear(point) then
        if attempt < (tonumber(CarConfig.personalVehicleRespawnMaxAttempts) or 6) then
            setTimer(respawnPersonalVehicleOnParking, tonumber(CarConfig.personalVehicleRespawnRetryDelay) or 5000, 1, vehicleId, attempt + 1)
        else
            RPCarDB.updateVehicle(vehicleId, {
                health = 1000,
                engine_on = 0,
                locked = 1,
                lights_on = 0,
                status = VehicleStatuses.noParking
            })
            respawnLocks[vehicleId] = nil
            debugLog("respawn parking occupied, vehicle kept unloaded: vehicleId=" .. tostring(vehicleId))
        end
        return false
    end

    destroyPersonalVehicle(vehicleId, false)
    local refreshed = resetVehicleToParkingState(vehicleId, point)
    if refreshed then createPersonalVehicle(refreshed, true) end
    respawnLocks[vehicleId] = nil
    return true
end

local function finishExplodedPersonalVehicle(vehicleId, explodedVehicle)
    vehicleId = tonumber(vehicleId)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    explodedVehicleCleanup[vehicleId] = nil

    if isElement(explodedVehicle) then
        clearPersonalRuntime(explodedVehicle, vehicleId)
        destroyElement(explodedVehicle)
    end

    if not row then
        respawnLocks[vehicleId] = nil
        return false
    end

    if not validateVehicleParking(row) then
        RPCarDB.updateVehicle(vehicleId, {
            house_id = 0,
            parking_slot = 0,
            health = 1000,
            engine_on = 0,
            locked = 1,
            lights_on = 0,
            status = VehicleStatuses.noParking
        })
        respawnLocks[vehicleId] = nil
        debugLog("exploded vehicle stored without parking: vehicleId=" .. tostring(vehicleId))
        return false
    end

    RPCarDB.updateVehicle(vehicleId, {
        health = 1000,
        engine_on = 0,
        locked = 1,
        lights_on = 0,
        status = VehicleStatuses.parked
    })
    return respawnPersonalVehicleOnParking(vehicleId, 1)
end

local function spawnShowcases()
    for vehicle in pairs(showcaseByElement) do
        if isElement(vehicle) then destroyElement(vehicle) end
    end
    showcaseByElement = {}

    for _, dealership in ipairs(Dealerships or {}) do
        for _, config in ipairs(dealership.vehicles or {}) do
            local p = config.position or {}
            local vehicle = createVehicle(config.model, p.x, p.y, p.z, 0, 0, p.rotation or 0)
            if vehicle then
                setElementInterior(vehicle, p.interior or 0)
                setElementDimension(vehicle, p.dimension or 0)
                setVehicleColor(vehicle, 255, 255, 255)
                applyConfiguredHandling(vehicle, config)
                setVehicleDamageProof(vehicle, true)
                setElementFrozen(vehicle, true)
                setVehicleEngineState(vehicle, false)
                setVehicleOverrideLights(vehicle, 1)
                setVehicleLocked(vehicle, false)
                setElementHealth(vehicle, 1000)
                setElementData(vehicle, "car:showcase", true, true)
                showcaseByElement[vehicle] = { dealershipId = dealership.id, vehicleId = config.id }
            end
        end
    end
end

local function spawnAllPersonalVehicles()
    if not coreRunning() or not homeRunning() then
        waitingForPropertyServices = true
        return -- Service unavailability is NOT loss of a car's parking/owner.
    end
    waitingForPropertyServices = false
    for _, row in pairs(RPCarDB.vehicles) do
        if isVehicleStoredWithoutParking(row) then
            destroyPersonalVehicle(row.id, false)
        elseif tostring(row.status or "") == VehicleStatuses.destroyed then
            if validateVehicleParking(row) then
                respawnLocks[row.id] = true
                respawnPersonalVehicleOnParking(row.id, 1)
            else
                clearVehicleParking(row.id, VehicleStatuses.noParking)
            end
        else
            local parking = validateVehicleParking(row)
            if parking then
                createPersonalVehicle(row, true, parking)
            elseif isUnparkedActiveVehicle(row) then
                createPersonalVehicle(row)
            else
                clearVehicleParking(row.id, VehicleStatuses.noParking)
            end
        end
    end
    -- Reattach owned cars orphaned by earlier property sales when space exists.
    for _,player in ipairs(getElementsByType("player")) do
        if isLogged(player) then recoverPlayerVehicleParking(player) end
    end

end

addEventHandler("onResourceStart", root, function(startedResource)
    if waitingForPropertyServices then
        setTimer(function()
            if not resourceStopping then spawnAllPersonalVehicles() end
        end,100,1)
    end
end)

local function openDealershipFor(player, vehicle)
    local data = showcaseByElement[vehicle]
    if not data then return end
    local config = getDealershipVehicle(data.dealershipId, data.vehicleId)
    if not config then return end
    triggerClientEvent(player, CarConfig.events.openDealership, resourceRoot, data.dealershipId, data.vehicleId, {
        name = config.customName,
        price = config.price,
        maxSpeed = config.maxSpeed,
        model = config.model,
        parking = publicParkingSummary(player)
    })
end

addEventHandler("onVehicleStartEnter", root, function(player, seat)
    if showcaseByElement[source] then
        if seat ~= 0 then cancelEvent(); return end
        return
    end

    local vehicleId = getVehicleDatabaseId(source)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if row and tonumber(row.locked) == 1 then
        setPersonalRuntime(source, row)
        applyPersonalVehicleState(source, row)
        return
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if showcaseByElement[source] then
        setElementFrozen(source, true)
        setVehicleEngineState(source, false)
        setShowcaseControlsEnabled(player, false)
        openDealershipFor(player, source)
        return
    end

    local vehicleId = getVehicleDatabaseId(source)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if row then
        setPersonalRuntime(source, row)
        applyPersonalVehicleState(source, row)
    end
end)

addEventHandler("onVehicleExit", root, function(player)
    if showcaseByElement[source] then
        if animatedExitPending[player] == source then
            debugLog("[RP CAR] Animated showroom exit: YES")
            finishAnimatedExit(player, source)
            return
        end
        if showcaseTransitions[player] then return end
        finishDealershipSession(player)
    end
end)

addEventHandler("onVehicleDamage", root, function()
    if showcaseByElement[source] then
        cancelEvent()
        setElementHealth(source, 1000)
    end
end)

addEventHandler("onVehicleExplode", root, function()
    if showcaseByElement[source] then
        cancelEvent()
        setElementHealth(source, 1000)
        return
    end

    local vehicleId = getVehicleDatabaseId(source)
    if vehicleId and not respawnLocks[vehicleId] then
        local row = RPCarDB.vehicles[vehicleId]
        if row then
            respawnLocks[vehicleId] = true
            explodedVehicleCleanup[vehicleId] = source
            RPCarDB.updateVehicle(vehicleId, {
                health = 1000,
                engine_on = 0,
                locked = 1,
                lights_on = 0,
                status = VehicleStatuses.destroyed
            })
            setTimer(finishExplodedPersonalVehicle, tonumber(CarConfig.VehicleRespawnAfterExplosion) or 5000, 1, vehicleId, source)
        end
    end
end)

addEventHandler("onElementDestroy", root, function()
    if resourceStopping or not coreRunning() or not homeRunning() then return end
    if getElementType(source) ~= "vehicle" then return end
    local tuningPlayer = tuningSessionByVehicle[source]
    if tuningPlayer then
        tuningSessionByVehicle[source] = nil
        tuningSessions[tuningPlayer] = nil
        if isElement(tuningPlayer) then
            triggerClientEvent(tuningPlayer, CarConfig.events.closeDealership, resourceRoot)
            triggerClientEvent(tuningPlayer, CarConfig.events.setControlsEnabled, resourceRoot, true)
            triggerClientEvent(tuningPlayer, CarConfig.events.resetCamera, resourceRoot)
        end
    end
    local vehicleId = personalByElement[source]
    if not vehicleId then return end
    clearPersonalRuntime(source, vehicleId)

    local row = RPCarDB.vehicles[vehicleId]
    if not row then return end
    if explodedVehicleCleanup[vehicleId] then return end
    if validateVehicleParking(row) then
        if not respawnLocks[vehicleId] then
            respawnLocks[vehicleId] = true
            RPCarDB.updateVehicle(vehicleId, {
                health = 1000,
                engine_on = 0,
                locked = 1,
                lights_on = 0,
                status = VehicleStatuses.parked
            })
            setTimer(respawnPersonalVehicleOnParking, tonumber(CarConfig.personalVehicleRespawnDelay) or 7000, 1, vehicleId, 1)
        end
    else
        RPCarDB.updateVehicle(vehicleId, {
            health = 1000,
            engine_on = 0,
            locked = 1,
            lights_on = 0,
            status = VehicleStatuses.noParking
        })
        respawnLocks[vehicleId] = nil
    end
end)

addEvent(CarConfig.events.closeDealership, true)
addEventHandler(CarConfig.events.closeDealership, root, function()
    if client ~= source then return end
    local vehicle = getPedOccupiedVehicle(client)
    if vehicle and showcaseByElement[vehicle] then
        beginAnimatedExit(client, vehicle)
    else
        finishDealershipSession(client)
    end
end)

addEvent(CarConfig.events.cancelDealership, true)
addEventHandler(CarConfig.events.cancelDealership, root, function()
    if client ~= source then return end
    debugLog("[RP CAR] Cancel requested: player=" .. tostring(rpName(client)))
    local vehicle = getPedOccupiedVehicle(client)
    if vehicle and showcaseByElement[vehicle] then
        beginAnimatedExit(client, vehicle)
    else
        finishDealershipSession(client)
    end
end)

addEvent(CarConfig.events.animatedExitComplete, true)
addEventHandler(CarConfig.events.animatedExitComplete, root, function()
    if client ~= source then return end
    local vehicle = animatedExitPending[client]
    if not vehicle then return end
    if getPedOccupiedVehicle(client) then return end
    debugLog("[RP CAR] Animated showroom exit confirmed by client")
    finishAnimatedExit(client, vehicle)
end)

addEvent(CarConfig.events.buyVehicle, true)
addEventHandler(CarConfig.events.buyVehicle, root, function(dealershipId, vehicleId)
    if client ~= source then return end
    local player = client
    if not isLogged(player) then return end
    if purchaseLocks[player] and getTickCount() - purchaseLocks[player] < CarConfig.purchaseCooldown then return end
    purchaseLocks[player] = getTickCount()

    local config, dealership = getDealershipVehicle(dealershipId, vehicleId)
    if not config or not dealership then notify(player, "Автомобиль не найден.", false); return end

    local currentVehicle = getPedOccupiedVehicle(player)
    local showcase = currentVehicle and showcaseByElement[currentVehicle]
    if not showcase or tonumber(showcase.dealershipId) ~= tonumber(dealershipId) or tonumber(showcase.vehicleId) ~= tonumber(vehicleId) then
        notify(player, "Сядьте в автомобиль автосалона.", false)
        return
    end

    local id = accountId(player)
    if not id then notify(player, "Ошибка аккаунта.", false); return end
    local price = tonumber(config.price) or 0
    if getPlayerBalance(player) < price then notify(player, "Недостаточно денег.", false); purchaseLocks[player] = nil; return end

    local house = getPlayerHouse(player)
    if not house or not house.id then notify(player, "Для покупки автомобиля необходимо иметь дом.", false); return end
    if not accountOwnsHouse(id, house.id) then
        notify(player, "Привязка к дому устарела. Покупка отменена без списания денег.", false)
        purchaseLocks[player] = nil
        return
    end
    local spaces = getHouseParkingSpaces(house.id)
    if #spaces <= 0 then notify(player, "У вашего дома нет парковочных мест.", false); return end
    if countPlayerVehicles(id) >= #spaces then notify(player, "Все парковочные места вашего дома заняты.", false); return end
    local parking = findFreeParking(house.id)
    if not parking then notify(player, "Все парковочные места вашего дома заняты.", false); return end

    local delivery = shiftedDeliveryPoint(dealership.purchasedVehicleSpawn or {})
    if not delivery then notify(player, "Точка выдачи занята. Попробуйте позже.", false); return end

    if not changePlayerMoney(player, -price) then
        purchaseLocks[player] = nil
        notify(player, "Ошибка денежной операции.", false)
        return
    end

    triggerClientEvent(player, CarConfig.events.closeDealership, resourceRoot)
    restoreShowcaseControls(player)
    resetPlayerCamera(player)
    removePedFromVehicle(player)

    local vehicleDbId = RPCarDB.createVehicle({
        owner_account_id = id,
        model = config.model,
        custom_name = config.customName,
        gov_price = price,
        color_r = 255, color_g = 255, color_b = 255,
        health = 1000,
        fuel = FuelConfig.initial,
        mileage = 0,
        engine_on = 1,
        locked = 0,
        lights_on = 0,
        house_id = house.id,
        parking_slot = parking.slot,
        x = delivery.x, y = delivery.y, z = delivery.z,
        rx = 0, ry = 0, rz = delivery.rotation or 0,
        interior = delivery.interior or 0,
        dimension = delivery.dimension or 0,
        status = VehicleStatuses.active
    })

    if not vehicleDbId then
        changePlayerMoney(player, price)
        purchaseLocks[player] = nil
        notify(player, "Не удалось сохранить автомобиль. Деньги возвращены.", false)
        return
    end

    local row = RPCarDB.vehicles[vehicleDbId]
    local personal = row and createPersonalVehicle(row)
    if personal then
        warpPedIntoVehicle(player, personal, 0)
        setCameraTarget(player, player)
        triggerClientEvent(player, CarConfig.events.resetCamera, resourceRoot)
    else
        RPCarDB.deleteVehicle(vehicleDbId)
        changePlayerMoney(player, price)
        purchaseLocks[player] = nil
        setElementPosition(player, delivery.x + 2, delivery.y, delivery.z)
        resetPlayerCamera(player)
        notify(player, "Не удалось создать личный автомобиль. Деньги возвращены.", false)
        return
    end
    purchaseLocks[player] = nil
    notify(player, "Автомобиль " .. tostring(config.customName) .. " куплен.", true)
end)

addEvent(CarConfig.events.buyVehicleRequest, true)
addEventHandler(CarConfig.events.buyVehicleRequest, root, function(dealershipId, vehicleId)
    if client ~= source then return end
    local player = client
    debugLog("[RP CAR] Purchase request received: player=" .. tostring(rpName(player)) .. ", dealership=" .. tostring(dealershipId) .. ", vehicle=" .. tostring(vehicleId))

    local function fail(message)
        purchaseLocks[player] = nil
        notify(player, message or "Покупка не выполнена.", false)
        debugLog("buy failed: " .. tostring(message))
        if isElement(player) then
            local occupiedVehicle = getPedOccupiedVehicle(player)
            if isElement(occupiedVehicle) and showcaseByElement[occupiedVehicle] then
                beginAnimatedExit(player, occupiedVehicle)
            else
                finishDealershipSession(player)
            end
        end
        return false
    end

    if not isLogged(player) then return fail("Авторизуйтесь для покупки автомобиля.") end
    if purchaseLocks[player] then return fail("Покупка уже обрабатывается.") end
    purchaseLocks[player] = true

    local config, dealership = getDealershipVehicle(dealershipId, vehicleId)
    if not config or not dealership then return fail("Автомобиль не найден.") end

    local showcaseVehicle = getPedOccupiedVehicle(player)
    local showcase = showcaseVehicle and showcaseByElement[showcaseVehicle]
    if not showcase or tonumber(showcase.dealershipId) ~= tonumber(dealershipId) or tonumber(showcase.vehicleId) ~= tonumber(vehicleId) then
        return fail("Сядьте в автомобиль автосалона.")
    end

    local id = accountId(player)
    if not id then return fail("Ошибка аккаунта.") end

    local price = tonumber(config.price) or 0
    if price <= 0 then return fail("Некорректная цена автомобиля.") end
    local balance = getPlayerBalance(player)
    debugLog("[RP CAR] Current balance: " .. tostring(balance))
    debugLog("[RP CAR] Price: " .. tostring(price))
    if balance < price then return fail("Недостаточно средств.") end

    local house = getPlayerHouse(player)
    if not house or not house.id then return fail("Для покупки автомобиля нужен дом.") end

    if not accountOwnsHouse(id, house.id) then return fail("Привязка к дому устарела. Покупка отменена.") end
    local spaces = getHouseParkingSpaces(house.id)
    if #spaces <= 0 then return fail("У вашего дома нет парковочных мест.") end
    if countPlayerVehicles(id) >= #spaces then return fail("У дома нет свободных парковочных мест.") end

    local parking = findFreeParking(house.id)
    if not parking then return fail("У дома нет свободных парковочных мест.") end

    local delivery = shiftedDeliveryPoint(dealership.purchasedVehicleSpawn or {})
    if not delivery then return fail("Точка выдачи занята. Попробуйте позже.") end

    local moneyDeducted = changePlayerMoney(player, -price)
    debugLog("[RP CAR] Money deducted: " .. (moneyDeducted and "YES" or "NO"))
    if not moneyDeducted then
        return fail("Ошибка денежной операции.")
    end

    local vehicleDbId = RPCarDB.createVehicle({
        owner_account_id = id,
        model = config.model,
        custom_name = config.customName,
        gov_price = price,
        color_r = 255, color_g = 255, color_b = 255,
        health = 1000,
        fuel = FuelConfig.initial,
        mileage = 0,
        engine_on = 1,
        locked = 0,
        lights_on = 0,
        house_id = house.id,
        parking_slot = parking.slot,
        x = delivery.x, y = delivery.y, z = delivery.z,
        rx = 0, ry = 0, rz = delivery.rotation or 0,
        interior = delivery.interior or 0,
        dimension = delivery.dimension or 0,
        status = VehicleStatuses.active
    })
    debugLog("[RP CAR] Vehicle record created: " .. (vehicleDbId and "YES" or "NO"))

    if not vehicleDbId then
        changePlayerMoney(player, price)
        return fail("Не удалось создать личный автомобиль. Деньги возвращены.")
    end

    local row = RPCarDB.vehicles[vehicleDbId]
    local personal = row and createPersonalVehicle(row)
    debugLog("[RP CAR] Personal vehicle spawned: " .. (personal and "YES" or "NO"))
    debugLog("[RP CAR] Personal vehicle created: " .. (personal and "YES" or "NO"))
    if not personal then
        RPCarDB.deleteVehicle(vehicleDbId)
        changePlayerMoney(player, price)
        return fail("Не удалось создать личный автомобиль. Деньги возвращены.")
    end

    if personal == showcaseVehicle then
        RPCarDB.deleteVehicle(vehicleDbId)
        changePlayerMoney(player, price)
        return fail("Не удалось создать отдельный личный автомобиль. Деньги возвращены.")
    end

    triggerClientEvent(player, CarConfig.events.closeDealership, resourceRoot)

    leaveShowcaseVehicle(player, showcaseVehicle, false, function(removed, exitPoint)
        if not isElement(player) then
            purchaseLocks[player] = nil
            return
        end
        if not removed then
            purchaseLocks[player] = nil
            finishDealershipSession(player)
            notify(player, "Автомобиль куплен, но не удалось выйти из выставочной машины.", false)
            return
        end

        local function tryWarp(attempt)
            if not isElement(player) or not isElement(personal) or personal == showcaseVehicle then
                purchaseLocks[player] = nil
                if isElement(player) then
                    movePlayerToSafeExit(player, exitPoint)
                    finishDealershipSession(player)
                    notify(player, "Не удалось посадить вас в купленный автомобиль.", false)
                end
                debugLog("[RP CAR] Player warped into purchased vehicle: NO")
                return
            end

            local warpResult = warpPedIntoVehicle(player, personal, 0)
            local warped = warpResult ~= false and getPedOccupiedVehicle(player) == personal
            if warped then
                purchaseLocks[player] = nil
                debugLog("[RP CAR] Player warped into purchased vehicle: YES")
                finishDealershipSession(player)
                debugLog("buy success: dbId=" .. tostring(vehicleDbId))
                notify(player, "Автомобиль " .. tostring(config.customName) .. " куплен.", true)
                return
            end

            if attempt < 2 then
                setTimer(tryWarp, 150, 1, attempt + 1)
                return
            end

            purchaseLocks[player] = nil
            debugLog("[RP CAR] Player warped into purchased vehicle: NO")
            movePlayerToSafeExit(player, exitPoint)
            finishDealershipSession(player)
            notify(player, "Автомобиль куплен, но автоматическая посадка не удалась.", false)
        end

        setTimer(tryWarp, 150, 1, 1)
    end)
end)

local function isPlayerVehicleOwner(player, vehicle)
    local data = getPersonalRuntime(vehicle)
    return ownsVehicleRuntime(player, data)
end

local function syncVehicleRuntimeState(vehicle, row)
    if not isElement(vehicle) or not row then return end
    setPersonalRuntime(vehicle, row)
    applyPersonalVehicleState(vehicle, row)
    if handbrakeVehicles[vehicle] then
        setElementFrozen(vehicle, true)
    elseif tonumber(row.engine_on) == 1 then
        setElementFrozen(vehicle, false)
    end
end

local function flashVehicleLights(vehicle, row)
    if not isElement(vehicle) or not row then return false end
    local vehicleId = getVehicleDatabaseId(vehicle)
    if not vehicleId then return false end

    local token = getTickCount()
    local interval = math.max(80, tonumber(CarConfig.headlightFlashInterval) or 140)
    local flashes = math.max(1, math.floor(tonumber(CarConfig.headlightFlashCount) or 2))
    local originalLightsOn = tonumber(row.lights_on) == 1
    lightFlashTokens[vehicleId] = token

    for step = 1, flashes * 2 do
        setTimer(function(targetVehicle, targetId, targetToken, turnOn, finalStep)
            if lightFlashTokens[targetId] ~= targetToken or not isElement(targetVehicle) then return end
            setVehicleOverrideLights(targetVehicle, turnOn and 2 or 1)
            if finalStep then
                setTimer(function(finalVehicle, finalId, finalToken, restoreOn)
                    if lightFlashTokens[finalId] ~= finalToken or not isElement(finalVehicle) then return end
                    setVehicleOverrideLights(finalVehicle, restoreOn and 2 or 1)
                    lightFlashTokens[finalId] = nil
                end, interval, 1, targetVehicle, targetId, targetToken, originalLightsOn)
            end
        end, interval * (step - 1), 1, vehicle, vehicleId, token, step % 2 == 1, step == flashes * 2)
    end
    return true
end

local function canControlVehicleEngine(player, vehicle, row)
    local data = getPersonalRuntime(vehicle)
    return isElement(player) and isElement(vehicle) and getPedOccupiedVehicle(player) == vehicle
        and getPedOccupiedVehicleSeat(player) == 0 and row
        and (ownsVehicleRuntime(player, data) or tonumber(row.engine_on) == 1)
end

local function canControlVehicleLights(player, vehicle, row)
    if not isElement(player) or not isElement(vehicle) then return false end
    return row and getPedOccupiedVehicle(player) == vehicle and getPedOccupiedVehicleSeat(player) == 0
end

addEvent(CarConfig.events.toggleEngine, true)
addEventHandler(CarConfig.events.toggleEngine, root, function()
    if client ~= source then return end
    local player = client
    if FactionVehicleAdapter and FactionVehicleAdapter.handle(player,'engine',nil) then return end
    if not CarInteraction.ready(player) then return end
    if tuningSessions[player] then return end
    local vehicle = getPedOccupiedVehicle(player)
    local runtime = vehicle and getPersonalRuntime(vehicle)
    local vehicleId = runtime and runtime.vehicleId
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    local allowed = isElement(vehicle) and row and not showcaseByElement[vehicle] and canControlVehicleEngine(player, vehicle, row)
    debugLog("[RP CAR] Permission granted: " .. (allowed and "YES" or "NO") .. " (engine)")
    if not allowed then return end

    local owner = ownsVehicleRuntime(player, runtime)
    local engineOn = owner and (tonumber(row.engine_on) == 1 and 0 or 1) or 0
    if engineOn == 1 and FuelSystem and not FuelSystem.canStart(vehicle) then
        notify(player, FuelSystem.get(vehicle) == 0 and "В автомобиле закончилось топливо" or "Дождитесь окончания заправки", false)
        return
    end
    if RPCarDB.updateVehicle(vehicleId, { engine_on = engineOn }) then
        row = RPCarDB.vehicles[vehicleId]
        syncVehicleRuntimeState(vehicle, row)
    end
end)

addEvent(CarConfig.events.toggleLights, true)
addEventHandler(CarConfig.events.toggleLights, root, function()
    if client ~= source then return end
    local player = client
    if FactionVehicleAdapter and FactionVehicleAdapter.handle(player,'lights',nil) then return end
    if not CarInteraction.ready(player) then return end
    if tuningSessions[player] then return end
    local vehicle = getPedOccupiedVehicle(player)
    local runtime = vehicle and getPersonalRuntime(vehicle)
    local vehicleId = runtime and runtime.vehicleId
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not isElement(vehicle) or not row or showcaseByElement[vehicle] then return end
    if not canControlVehicleLights(player, vehicle, row) then return end

    local lightsOn = tonumber(row.lights_on) == 1 and 0 or 1
    if RPCarDB.updateVehicle(vehicleId, { lights_on = lightsOn }) then
        lightFlashTokens[vehicleId] = nil
        syncVehicleRuntimeState(vehicle, RPCarDB.vehicles[vehicleId])
    end
end)

addEvent(CarConfig.events.toggleHandbrake, true)
addEventHandler(CarConfig.events.toggleHandbrake, root, function()
    if client ~= source then return end
    local player = client
    if FactionVehicleAdapter and FactionVehicleAdapter.handle(player,'brake',nil) then return end
    if not CarInteraction.ready(player) then return end
    if tuningSessions[player] then return end
    local vehicle = getPedOccupiedVehicle(player)
    if not isElement(vehicle) or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) or showcaseByElement[vehicle] then return end
    local runtime = getPersonalRuntime(vehicle)
    local vehicleId = runtime and runtime.vehicleId
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return end

    if handbrakeVehicles[vehicle] then
        handbrakeVehicles[vehicle] = nil
        setElementData(vehicle, "car:handbrake", false, true)
        setElementFrozen(vehicle, false)
        notify(player, "Ручник снят.", true)
        return
    end

    local vx, vy, vz = getElementVelocity(vehicle)
    local avx, avy, avz = getElementAngularVelocity(vehicle)
    local linearSpeed = math.sqrt(vx * vx + vy * vy + vz * vz)
    local angularSpeed = math.sqrt(avx * avx + avy * avy + avz * avz)
    if not isVehicleOnGround(vehicle) or linearSpeed > 0.01 or angularSpeed > 0.01 then
        notify(player, "Чтобы поставить ручник, полностью остановите автомобиль на поверхности.", false)
        return
    end

    setElementVelocity(vehicle, 0, 0, 0)
    setElementAngularVelocity(vehicle, 0, 0, 0)
    handbrakeVehicles[vehicle] = true
    setElementData(vehicle, "car:handbrake", true, true)
    setElementFrozen(vehicle, true)
    notify(player, "Ручник включён.", true)
end)

-- Resolve against server-owned rows: client aim can hit a neighbour/showroom car.
local function resolveLockVehicle(player, requested)
    local px, py, pz = getElementPosition(player)
    local limit = tonumber(CarConfig.lockServerDistance) or 25
    local function eligible(vehicle)
        if not isElement(vehicle) or showcaseByElement[vehicle] then return false end
        if getElementInterior(vehicle) ~= getElementInterior(player) or getElementDimension(vehicle) ~= getElementDimension(player) then return false end
        local data = getPersonalRuntime(vehicle)
        local row = data and RPCarDB.vehicles[data.vehicleId]
        if not ownsVehicleRow(player, row) then return false end
        local x, y, z = getElementPosition(vehicle)
        local distance = getDistanceBetweenPoints3D(px, py, pz, x, y, z)
        if distance > limit then return false end
        return distance, row
    end
    if type(requested) == "table" and not isElement(requested) then
        for index=1,math.min(64,#requested) do
            local vehicle = requested[index]
            local distance, row = eligible(vehicle)
            if distance then setPersonalRuntime(vehicle,row);return vehicle end
        end
        return false
    end
    local distance, row = eligible(requested)
    if distance then setPersonalRuntime(requested, row);return requested end
    return false -- Never substitute another car for the selected screen target.

end

addEvent(CarConfig.events.toggleLock, true)
addEventHandler(CarConfig.events.toggleLock, root, function(vehicle)
    debugLock("Lock request received")
    if client ~= source then return end
    local player = client
    if FactionVehicleAdapter and FactionVehicleAdapter.handle(player,'lock',vehicle) then return end
    if not CarInteraction.canToggleLock(player) then notify(player,"Дождитесь завершения посадки или выхода из машины.",false);return end
    if tuningSessions[player] then notify(player,"Сначала выйдите из тюнинг-ателье.",false);return end
    vehicle = resolveLockVehicle(player, vehicle)
    if not vehicle then
        notify(player, "Рядом нет доступного личного автомобиля. Подойдите ближе к своей машине.", false)
        return
    end
    debugLock("Vehicle valid: " .. (isElement(vehicle) and "YES" or "NO"))
    if not isElement(vehicle) then
        return
    end

    local runtime = getPersonalRuntime(vehicle)
    local vehicleId = runtime and runtime.vehicleId
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    debugLock("Personal vehicle: " .. (row and "YES" or "NO"))
    outputDebugString("[RP CAR] Player account ID: " .. tostring(accountId(player) or "nil"), 3)
    outputDebugString("[RP CAR] Vehicle owner account ID: " .. tostring(runtime and runtime.ownerAccountId or "nil"), 3)
    debugLock("Owner account ID: " .. tostring(runtime and runtime.ownerAccountId or row and row.owner_account_id or "nil"))
    debugLock("Player account ID: " .. tostring(accountId(player) or "nil"))
    local ownerOk = ownsVehicleRow(player, row) or false
    outputDebugString("[RP CAR] Owner check: " .. (ownerOk and "YES" or "NO"), 3)
    debugLock("Owner check: " .. (ownerOk and "YES" or "NO"))

    local px, py, pz = getElementPosition(player)
    local vx, vy, vz = getElementPosition(vehicle)
    if not row or showcaseByElement[vehicle] or not ownerOk or getElementInterior(player) ~= getElementInterior(vehicle) or getElementDimension(player) ~= getElementDimension(vehicle)
        or getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) > (tonumber(CarConfig.lockServerDistance) or 25) then
        debugLock("Permission granted: NO")
        return
    end
    debugLock("Permission granted: YES")

    local wasLocked = tonumber(row.locked) == 1
    debugLock("Previous lock state: " .. (wasLocked and "CLOSED" or "OPEN"))
    debugLock("Current lock state: " .. (wasLocked and "CLOSED" or "OPEN"))
    local locked = wasLocked and 0 or 1
    local expectedLocked = locked == 1
    setVehicleLocked(vehicle, expectedLocked)
    local actualLocked = expectedLocked
    if isVehicleLocked then
        actualLocked = isVehicleLocked(vehicle) == true
    end
    local success = actualLocked == expectedLocked
    debugLock("New lock state: " .. (expectedLocked and "CLOSED" or "OPEN"))
    debugLock("setVehicleLocked result: " .. (success and "SUCCESS" or "FAILED"))
    if not success then
        debugLock("Headlight flash triggered: NO")
        notify(player,"Не удалось изменить состояние замка автомобиля.",false)
        return
    end

    if not RPCarDB.updateVehicle(vehicleId, { locked = locked }) then
        setVehicleLocked(vehicle, wasLocked)
        debugLock("New lock state: " .. (wasLocked and "CLOSED" or "OPEN"))
        notify(player,"Не удалось сохранить замок автомобиля в базе данных.",false)
        debugLock("Database lock update: FAILED")
        debugLock("Headlight flash triggered: NO")
        return
    end

    row = RPCarDB.vehicles[vehicleId]
    syncVehicleRuntimeState(vehicle, row)
    triggerClientEvent(player, CarConfig.events.playLockSound, resourceRoot, vehicle)
    debugLock("Headlight flash triggered: YES")
    flashVehicleLights(vehicle, row)
    notify(player,expectedLocked and "Двери автомобиля закрыты." or "Двери автомобиля открыты.",true)
end)

local function openUsedMarket(player, vehicle)
    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return end
    triggerClientEvent(player, CarConfig.events.openUsedMarket, resourceRoot, {
        vehicleId = row.id,
        name = getVehicleDisplayName(row.model, row.custom_name),
        statePrice = math.floor((tonumber(row.gov_price) or 0) * (tonumber(CarConfig.stateVehicleSellPercent) or 50) / 100)
    })
end

local function handleUsedMarketHit(element)
    local player, vehicle
    if getElementType(element) == "vehicle" then
        vehicle = element
        player = getVehicleController(vehicle)
    elseif getElementType(element) == "player" then
        player = element
        vehicle = getPedOccupiedVehicle(player)
    end
    if not player or not vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then return end
    if not isPersonalVehicle(vehicle) then notify(player, "Это не личный автомобиль.", false); return end
    if not isPlayerVehicleOwner(player, vehicle) then notify(player, "Вы не владелец этого автомобиля.", false); return end
    openUsedMarket(player, vehicle)
end

local function getActiveTuningShop(player, vehicle)
    if not isElement(player) or not isElement(vehicle) then return false end
    local px, py, pz = getElementPosition(vehicle)
    local interior = getElementInterior(vehicle)
    local dimension = getElementDimension(vehicle)
    for _, shop in ipairs(TuningShops or {}) do
        local m = shop.marker or {}
        if interior == (m.interior or 0) and dimension == (m.dimension or 0)
            and getDistanceBetweenPoints3D(px, py, pz, m.x, m.y, m.z) <= (tonumber(shop.distance) or tonumber(m.size) or 5) then
            return shop
        end
    end
    return false
end

local function normalizeTuningSection(section)
    section = tostring(section or "menu")
    if section == "performance" or section == "toner" then return section end
    return "menu"
end

local function clampTonerPercent(value)
    value = tonumber(value) or 0
    value = math.floor(value / 10 + 0.5) * 10
    return math.max(0, math.min(100, value))
end

local function tonerStateFromRow(row)
    return {
        lob = clampTonerPercent(row and row.toner_lob_percent),
        front = clampTonerPercent(row and row.toner_front_percent),
        rear = clampTonerPercent((row and row.toner_rear_percent) or (row and row.toner_percent))
    }
end

local function normalizeTonerSelection(selection, fallback)
    fallback = fallback or {}
    if type(selection) ~= "table" then
        local value = clampTonerPercent(selection)
        return { lob = value, front = value, rear = value }
    end
    return {
        lob = clampTonerPercent(selection.lob ~= nil and selection.lob or fallback.lob),
        front = clampTonerPercent(selection.front ~= nil and selection.front or fallback.front),
        rear = clampTonerPercent(selection.rear ~= nil and selection.rear or fallback.rear)
    }
end

local function tuningSectionAllowed(data, section)
    section = normalizeTuningSection(section)
    if section == "menu" then return true end
    if section == "performance" then return data and data.tunable == true end
    if section == "toner" then return data ~= nil end
    return false
end

local function openTuningFor(player, vehicle)
    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return false end
    local data = tuningSummary(row)
    local session = tuningSessions[player]
    local shopMode = normalizeTuningSection(session and session.shopMode or "menu")
    if not data or not tuningSectionAllowed(data, shopMode) then
        notify(player, "Этот автомобиль нельзя улучшать.", false)
        return false
    end
    data.shopMode = shopMode
    if session then
        data.camera = session.camera
        data.cameraTarget = session.camera and session.camera.target
        data.cameraSettings = session.camera and {
            minDistance = session.camera.minDistance,
            maxDistance = session.camera.maxDistance,
            defaultDistance = session.camera.defaultDistance,
            minPitch = session.camera.minPitch,
            maxPitch = session.camera.maxPitch,
            rotateSpeed = session.camera.rotateSpeed,
            verticalSpeed = session.camera.verticalSpeed,
            zoomStep = session.camera.zoomStep,
            smoothing = session.camera.smoothing,
            collisionPadding = session.camera.collisionPadding,
            groundClearance = session.camera.groundClearance,
            targetOffset = session.camera.targetOffset
        }
    end
    triggerClientEvent(player, CarConfig.events.openTuning, resourceRoot, data)
    return true
end

local function tuningDimensionFor(player)
    local cfg = CarConfig.TuningPreview or CarConfig.TuningZone or CarConfig.tuningInterior or {}
    return (tonumber(cfg.dimensionBase) or 10000) + (accountId(player) or math.random(1000, 9999))
end

local function rotatedOffset(origin, rotation, offset)
    local rz = math.rad(tonumber(rotation) or 0)
    local ox, oy, oz = tonumber(offset and offset.x) or 0, tonumber(offset and offset.y) or 0, tonumber(offset and offset.z) or 0
    local cosR, sinR = math.cos(rz), math.sin(rz)
    return {
        x = origin.x + ox * cosR - oy * sinR,
        y = origin.y + ox * sinR + oy * cosR,
        z = origin.z + oz
    }
end

local function cameraForTuningPosition(position)
    local cameraCfg = CarConfig.TuningCamera or {}
    local rotation = position.rz or position.rotation or 0
    local target = rotatedOffset(position, rotation, cameraCfg.targetOffset or { x = 0, y = 0, z = 0.85 })
    local camera = rotatedOffset(position, rotation, cameraCfg.positionOffset or { x = -4.2, y = -5.0, z = 2.1 })
    return {
        x = camera.x, y = camera.y, z = camera.z,
        lookX = target.x, lookY = target.y, lookZ = target.z,
        target = target,
        targetOffset = cameraCfg.targetOffset or { x = 0, y = 0, z = 0.85 },
        minDistance = tonumber(cameraCfg.minDistance) or 4.0,
        maxDistance = tonumber(cameraCfg.maxDistance) or 9.0,
        defaultDistance = tonumber(cameraCfg.defaultDistance) or 6.2,
        minPitch = tonumber(cameraCfg.minPitch) or -0.12,
        maxPitch = tonumber(cameraCfg.maxPitch) or 1.18,
        rotateSpeed = tonumber(cameraCfg.rotateSpeed) or 0.010,
        verticalSpeed = tonumber(cameraCfg.verticalSpeed) or 0.012,
        zoomStep = tonumber(cameraCfg.zoomStep) or 0.55,
        smoothing = tonumber(cameraCfg.smoothing) or 12,
        collisionPadding = tonumber(cameraCfg.collisionPadding) or 0.3,
        groundClearance = tonumber(cameraCfg.groundClearance) or 0.35
    }
end

local function rowWithTuningLevels(row, selectedLevels, maxLevel)
    if not row then return false end
    local preview = {}
    for key, value in pairs(row) do preview[key] = value end
    selectedLevels = type(selectedLevels) == "table" and selectedLevels or {}
    if isSuspensionTunable(row.model) then
        preview.suspension_level = clampTuneLevel(selectedLevels.suspension or row.suspension_level, maxLevel)
    else
        preview.suspension_level = clampTuneLevel(row.suspension_level, maxLevel)
    end
    preview.acceleration_level = clampTuneLevel(selectedLevels.acceleration or row.acceleration_level, maxLevel)
    preview.max_speed_level = clampTuneLevel(selectedLevels.max_speed or row.max_speed_level, maxLevel)
    return preview
end

local function settleSuspensionPreviewVehicle(vehicle)
    if not isElement(vehicle) then return false end
    local x, y, z = getElementPosition(vehicle)
    local rx, ry, rz = getElementRotation(vehicle)
    setElementFrozen(vehicle, false)
    if FuelSystem then FuelSystem.resetSample(vehicle) end
    setElementPosition(vehicle, x, y, z + 0.04)
    setElementRotation(vehicle, rx or 0, ry or 0, rz or 0)
    setElementVelocity(vehicle, 0, 0, -0.08)
    setElementAngularVelocity(vehicle, 0, 0, 0)

    setTimer(function(targetVehicle)
        if not isElement(targetVehicle) then return end
        setElementFrozen(targetVehicle, false)
        setElementVelocity(targetVehicle, 0, 0, -0.035)
        setElementAngularVelocity(targetVehicle, 0, 0, 0)
    end, 180, 1, vehicle)

    setTimer(function(targetVehicle)
        if not isElement(targetVehicle) then return end
        setElementVelocity(targetVehicle, 0, 0, 0)
        setElementAngularVelocity(targetVehicle, 0, 0, 0)
    end, 650, 1, vehicle)
    return true
end

local function restoreTuningVehicle(player, session)
    if not session or not isElement(session.vehicle) then return false end
    local vehicle = session.vehicle
    local p = session.exitPoint or session.returnPoint
    if not p then return false end

    setElementFrozen(vehicle, false)
    setElementInterior(vehicle, p.interior or 0)
    setElementDimension(vehicle, p.dimension or 0)
    if FuelSystem then FuelSystem.resetSample(vehicle) end
    setElementPosition(vehicle, p.x, p.y, (tonumber(p.z) or 0) + 0.08)
    setElementRotation(vehicle, 0, 0, p.rotation or 0)
    setElementVelocity(vehicle, 0, 0, 0)
    setElementAngularVelocity(vehicle, 0, 0, 0)
    setVehicleEngineState(vehicle, false)
    if session.vehicleId then
        RPCarDB.updateVehicle(session.vehicleId, {
            x = p.x,
            y = p.y,
            z = p.z,
            rz = p.rotation or 0,
            interior = p.interior or 0,
            dimension = p.dimension or 0,
            engine_on = 0,
            lights_on = 0
        })
        local row = RPCarDB.vehicles[session.vehicleId]
        if row then
            setPersonalRuntime(vehicle, row)
            applyPersonalVehicleState(vehicle, row)
        end
    end
    applyPersonalVehicleHandling(vehicle)
    if isElement(player) then
        setElementInterior(player, p.interior or 0)
        setElementDimension(player, p.dimension or 0)
        warpPedIntoVehicle(player, vehicle, 0)
    end
    return true
end

local function finishTuningSession(player, silent)
    local session = tuningSessions[player]
    if not session then return false end
    tuningSessions[player] = nil
    if isElement(session.vehicle) then
        tuningSessionByVehicle[session.vehicle] = nil
    end
    restoreTuningVehicle(player, session)
    if isElement(player) then
        local row = session.vehicleId and RPCarDB.vehicles[session.vehicleId]
        if row and isElement(session.vehicle) then
            triggerClientEvent(player, CarConfig.events.applyTonerPreview, resourceRoot, session.vehicle, tonerStateFromRow(row))
        end
        triggerClientEvent(player, CarConfig.events.closeDealership, resourceRoot)
        triggerClientEvent(player, CarConfig.events.setControlsEnabled, resourceRoot, true)
        triggerClientEvent(player, CarConfig.events.resetCamera, resourceRoot)
        if not silent then notify(player, "Вы покинули тюнинг-ателье.", true) end
    end
    return true
end

local function beginTuningSession(player, vehicle, shop)
    if tuningSessions[player] then
        openTuningFor(player, vehicle)
        return true
    end
    if tuningSessionByVehicle[vehicle] then return false end

    local row = RPCarDB.vehicles[getVehicleDatabaseId(vehicle) or 0]
    if not row then return false end
    local data = tuningSummary(row)
    local shopMode = "menu"
    if not data or (not data.tunable and not data.toner) then return false end

    local cfg = CarConfig.TuningPreview or CarConfig.TuningZone or CarConfig.tuningInterior or {}
    local p = cfg.vehiclePosition or cfg.vehicle or {}
    local dimension = tuningDimensionFor(player)
    local interior = tonumber(cfg.interior) or 0
    local returnPositions = cfg.returnPositions or {}
    local exitPoint = returnPositions[tonumber(shop.id) or 0] or shop.exitPoint or shop.marker or {}
    local cameraData = cameraForTuningPosition(p)

    tuningSessions[player] = {
        vehicle = vehicle,
        vehicleId = row.id,
        shopId = shop.id,
        shopMode = shopMode,
        returnPoint = shop.marker,
        exitPoint = exitPoint,
        originalLevels = {
            suspension = clampTuneLevel(row.suspension_level, data.maxLevel or 3),
            acceleration = clampTuneLevel(row.acceleration_level, data.maxLevel or 3),
            max_speed = clampTuneLevel(row.max_speed_level, data.maxLevel or 3)
        },
        dimension = dimension,
        interior = interior,
        camera = cameraData
    }
    tuningSessionByVehicle[vehicle] = player

    setElementFrozen(vehicle, false)
    setVehicleEngineState(vehicle, false)
    setElementInterior(vehicle, interior)
    setElementDimension(vehicle, dimension)
    if FuelSystem then FuelSystem.resetSample(vehicle) end
    setElementPosition(vehicle, p.x, p.y, (tonumber(p.z) or 0) + (tonumber(cfg.teleportZOffset) or 0.15))
    setElementRotation(vehicle, p.rx or 0, p.ry or 0, p.rz or p.rotation or 0)
    setElementVelocity(vehicle, 0, 0, 0)
    setElementAngularVelocity(vehicle, 0, 0, 0)
    setElementInterior(player, interior)
    setElementDimension(player, dimension)
    warpPedIntoVehicle(player, vehicle, 0)

    setTimer(function(targetPlayer, targetVehicle)
        local session = tuningSessions[targetPlayer]
        if not session or session.vehicle ~= targetVehicle or not isElement(targetVehicle) then return end
        setElementVelocity(targetVehicle, 0, 0, 0)
        setElementAngularVelocity(targetVehicle, 0, 0, 0)
    end, tonumber(cfg.settleDelay) or 900, 1, player, vehicle)

    data.camera = tuningSessions[player].camera
    data.shopMode = shopMode
    data.cameraTarget = data.camera.target
    data.cameraSettings = {
        minDistance = data.camera.minDistance,
        maxDistance = data.camera.maxDistance,
        defaultDistance = data.camera.defaultDistance,
        minPitch = data.camera.minPitch,
        maxPitch = data.camera.maxPitch,
        rotateSpeed = data.camera.rotateSpeed,
        verticalSpeed = data.camera.verticalSpeed,
        zoomStep = data.camera.zoomStep,
        smoothing = data.camera.smoothing,
        collisionPadding = data.camera.collisionPadding,
        groundClearance = data.camera.groundClearance,
        targetOffset = data.camera.targetOffset
    }
    triggerClientEvent(player, CarConfig.events.setControlsEnabled, resourceRoot, false)
    triggerClientEvent(player, CarConfig.events.openTuning, resourceRoot, data)
    triggerClientEvent(player, CarConfig.events.setTuningCamera, resourceRoot, data.camera)
    return true
end

local function handleTuningShopHit(element, matchingDimension)
    if not matchingDimension then return end
    local player, vehicle
    if getElementType(element) == "vehicle" then
        vehicle = element
        player = getVehicleController(vehicle)
    elseif getElementType(element) == "player" then
        player = element
        vehicle = getPedOccupiedVehicle(player)
    end
    if not isElement(player) or not isElement(vehicle) or getPedOccupiedVehicle(player) ~= vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then return end
    if showcaseByElement[vehicle] or not isPersonalVehicle(vehicle) or not isPlayerVehicleOwner(player, vehicle) then return end
    local shop = getActiveTuningShop(player, vehicle)
    if not shop then return end
    beginTuningSession(player, vehicle, shop)
end

local function destroyTuningMarkers()
    for _, marker in pairs(tuningMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    tuningMarkers = {}
end

local function createTuningMarkers()
    destroyTuningMarkers()
    for _, shop in ipairs(TuningShops or {}) do
        local m = shop.marker or {}
        if m.x and m.y and m.z then
            local color = {79, 195, 247, 115}
            local marker = createMarker(m.x, m.y, m.z - 1, "cylinder", tonumber(m.size) or 3, color[1], color[2], color[3], color[4])
            if marker then
                setElementInterior(marker, m.interior or 0)
                setElementDimension(marker, m.dimension or 0)
                setElementData(marker, "car:tuningShopId", shop.id, false)
                setElementData(marker, "car:tuningShopType", "all", false)
                addEventHandler("onMarkerHit", marker, handleTuningShopHit)
                tuningMarkers[shop.id] = marker
            end
        end
    end
end

addEvent(CarConfig.events.usedMarketAction, true)
addEventHandler(CarConfig.events.usedMarketAction, root, function(action)
    if client ~= source then return end
    local player = client
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) or not isPlayerVehicleOwner(player, vehicle) then
        notify(player, "Вы должны быть за рулём своего автомобиля.", false)
        return
    end
    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then notify(player, "Запись автомобиля не найдена.", false); return end

    if action == "sell_state" then
        local refund = math.floor((tonumber(row.gov_price) or 0) * (tonumber(CarConfig.stateVehicleSellPercent) or 50) / 100)
        if not creditAccountOrPlayer(row.owner_account_id, player, refund) then
            notify(player, "Ошибка денежной операции. Автомобиль не продан.", false)
            return
        end
        if not RPCarDB.deleteVehicle(row.id) then
            changePlayerMoney(player, -refund)
            notify(player, "Не удалось удалить автомобиль. Продажа отменена.", false)
            return
        end
        destroyPersonalVehicle(row.id, false)
        notify(player, "Автомобиль продан государству за " .. CarConfig.formatMoney(refund) .. ".", true)
    end
end)

addEvent(CarConfig.events.previewTuning, true)
addEventHandler(CarConfig.events.previewTuning, root, function(selectedLevels)
    if client ~= source or not isLogged(client) or type(selectedLevels) ~= "table" then return end
    local player = client
    local session = tuningSessions[player]
    if not session or session.shopMode ~= "performance" then return end
    local vehicle = session and session.vehicle
    if not isElement(vehicle) or getPedOccupiedVehicle(player) ~= vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then return end
    if showcaseByElement[vehicle] or not isPersonalVehicle(vehicle) or not isPlayerVehicleOwner(player, vehicle) then return end

    local vehicleId = session.vehicleId or getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return end
    local tune = TunableVehicles and TunableVehicles[tonumber(row.model)] or nil
    if not tune then return end

    local previewRow = rowWithTuningLevels(row, selectedLevels, tonumber(tune.maxLevel) or 3)
    if not previewRow then return end
    local suspensionChanged = tonumber(previewRow.suspension_level) ~= tonumber(row.suspension_level)
    session.previewLevels = {
        suspension = previewRow.suspension_level,
        acceleration = previewRow.acceleration_level,
        max_speed = previewRow.max_speed_level
    }
    setElementFrozen(vehicle, false)
    setVehicleEngineState(vehicle, false)
    applyConfiguredHandling(vehicle, previewRow)
    if suspensionChanged then
        settleSuspensionPreviewVehicle(vehicle)
    else
        setElementVelocity(vehicle, 0, 0, 0)
        setElementAngularVelocity(vehicle, 0, 0, 0)
    end
end)

addEvent(CarConfig.events.tuningAction, true)
addEventHandler(CarConfig.events.tuningAction, root, function(selectedLevels)
    if client ~= source or not isLogged(client) then return end
    local player = client
    if tuningLocks[player] then return end
    tuningLocks[player] = true

    local function finish(message, good, refreshVehicle)
        tuningLocks[player] = nil
        if message then notify(player, message, good == true) end
        local restoreVehicle = refreshVehicle or (tuningSessions[player] and tuningSessions[player].vehicle)
        if isElement(restoreVehicle) then
            applyPersonalVehicleHandling(restoreVehicle)
            if refreshVehicle then openTuningFor(player, refreshVehicle) end
        end
    end

    if type(selectedLevels) ~= "table" then return finish("Некорректные уровни улучшений.", false) end

    local vehicle = getPedOccupiedVehicle(player)
    if not isElement(vehicle) or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then
        return finish("Вы должны быть за рулём личного автомобиля.", false)
    end
    if showcaseByElement[vehicle] or not isPersonalVehicle(vehicle) or not isPlayerVehicleOwner(player, vehicle) then
        return finish("Вы не владелец этого автомобиля.", false)
    end
    local session = tuningSessions[player]
    if not session or session.shopMode ~= "performance" then return finish(nil, false, vehicle) end
    if not session or session.vehicle ~= vehicle then
        return finish("Автомобиль не находится в тюнинг-ателье.", false)
    end

    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return finish("Запись автомобиля не найдена.", false) end

    local tune = TunableVehicles and TunableVehicles[tonumber(row.model)] or nil
    if not tune then return finish("Этот автомобиль нельзя улучшать.", false, vehicle) end

    local maxLevel = tonumber(tune.maxLevel) or 3
    local update = {}
    local totalPrice = 0
    local changed = false
    for category, field in pairs(tuningFields) do
        if category == "suspension" and not isSuspensionTunable(row.model) then
            if clampTuneLevel(selectedLevels[category], maxLevel) ~= clampTuneLevel(row[field], maxLevel) then
                return finish("Suspension is unavailable for this model.", false, vehicle)
            end
        else
        local currentLevel = clampTuneLevel(row[field], maxLevel)
        local desiredLevel = clampTuneLevel(selectedLevels[category], maxLevel)
        if desiredLevel ~= currentLevel then
            local price = tuningPrice(tune, category, desiredLevel)
            if not price or price < 0 then return finish("Цена уровня тюнинга не настроена.", false, vehicle) end
            totalPrice = totalPrice + price
            update[field] = desiredLevel
            changed = true
        end
        end
    end

    if not changed then return finish("Этот уровень уже установлен.", false, vehicle) end
    if totalPrice > 0 then
        if getPlayerBalance(player) < totalPrice then return finish("Недостаточно средств.", false, vehicle) end
        if not changePlayerMoney(player, -totalPrice) then return finish("Ошибка денежной операции.", false, vehicle) end
    end

    if not RPCarDB.updateVehicle(vehicleId, update) then
        if totalPrice > 0 then changePlayerMoney(player, totalPrice) end
        return finish("Не удалось сохранить улучшение. Деньги возвращены.", false, vehicle)
    end

    row = RPCarDB.vehicles[vehicleId]
    setPersonalRuntime(vehicle, row)
    applyConfiguredHandling(vehicle, row)
    if update.suspension_level ~= nil then
        settleSuspensionPreviewVehicle(vehicle)
    end
    if session then
        session.previewLevels = nil
        session.originalLevels = {
            suspension = clampTuneLevel(row.suspension_level, maxLevel),
            acceleration = clampTuneLevel(row.acceleration_level, maxLevel),
            max_speed = clampTuneLevel(row.max_speed_level, maxLevel)
        }
    end
    notify(player, "Улучшения установлены за " .. CarConfig.formatMoney(totalPrice) .. ".", true)
    finish(nil, true, vehicle)
end)

local function getValidatedTuningVehicle(player)
    local vehicle = getPedOccupiedVehicle(player)
    if not isElement(vehicle) or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then return false, false end
    if showcaseByElement[vehicle] or not isPersonalVehicle(vehicle) or not isPlayerVehicleOwner(player, vehicle) then return false, false end
    local session = tuningSessions[player]
    if not session or session.vehicle ~= vehicle then return false, false end
    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return false, false end
    return vehicle, row
end

local function isTonerTuningSession(player)
    local session = tuningSessions[player]
    return session and session.shopMode == "toner"
end

local function restoreTonerPreview(player, vehicle, row)
    if isElement(player) and isElement(vehicle) and row then
        triggerClientEvent(player, CarConfig.events.applyTonerPreview, resourceRoot, vehicle, tonerStateFromRow(row))
    end
end

addEvent(CarConfig.events.tuningSection, true)
addEventHandler(CarConfig.events.tuningSection, root, function(section)
    if client ~= source or not isLogged(client) then return end
    local player = client
    local session = tuningSessions[player]
    if not session or not isElement(session.vehicle) then return end
    local vehicle, row = getValidatedTuningVehicle(player)
    if not vehicle or not row then return end
    local data = tuningSummary(row)
    local nextSection = normalizeTuningSection(section)

    if session.shopMode == "toner" and nextSection ~= "toner" then
        restoreTonerPreview(player, vehicle, row)
    elseif session.shopMode == "performance" and nextSection ~= "performance" then
        applyPersonalVehicleHandling(vehicle)
    end

    if not tuningSectionAllowed(data, nextSection) then
        notify(player, "Р­С‚РѕС‚ СЂР°Р·РґРµР» С‚СЋРЅРёРЅРіР° РЅРµРґРѕСЃС‚СѓРїРµРЅ.", false)
        return
    end

    session.shopMode = nextSection
    openTuningFor(player, vehicle)
end)

addEvent(CarConfig.events.previewToner, true)
addEventHandler(CarConfig.events.previewToner, root, function(selection)
    if client ~= source or not isLogged(client) then return end
    if not isTonerTuningSession(client) then return end
    local vehicle, row = getValidatedTuningVehicle(client)
    if not vehicle or not row then return end
    triggerClientEvent(client, CarConfig.events.applyTonerPreview, resourceRoot, vehicle, normalizeTonerSelection(selection, tonerStateFromRow(row)))
end)

addEvent(CarConfig.events.tonerAction, true)
addEventHandler(CarConfig.events.tonerAction, root, function(selection)
    if client ~= source or not isLogged(client) then return end
    local player = client
    if not isTonerTuningSession(player) then return end
    if tuningLocks[player] then return end
    tuningLocks[player] = true

    local function finish(message, good, refreshVehicle)
        tuningLocks[player] = nil
        if message then notify(player, message, good == true) end
        if isElement(refreshVehicle) then openTuningFor(player, refreshVehicle) end
    end

    local vehicle, row = getValidatedTuningVehicle(player)
    if not vehicle or not row then return finish("РђРІС‚РѕРјРѕР±РёР»СЊ РЅРµ РЅР°С…РѕРґРёС‚СЃСЏ РІ С‚СЋРЅРёРЅРі-Р°С‚РµР»СЊРµ.", false) end

    local current = tonerStateFromRow(row)
    local desired = normalizeTonerSelection(selection, current)
    local changedZones = 0
    for _, zone in ipairs({"lob", "front", "rear"}) do
        if desired[zone] ~= current[zone] then changedZones = changedZones + 1 end
    end
    if changedZones <= 0 then
        restoreTonerPreview(player, vehicle, row)
        return finish("Р­С‚Р° С‚РѕРЅРёСЂРѕРІРєР° СѓР¶Рµ СѓСЃС‚Р°РЅРѕРІР»РµРЅР°.", false, vehicle)
    end

    local price = math.max(0, math.floor(tonumber(CarConfig.tonerPrice) or 0)) * changedZones
    local moneyCharged = false
    if price > 0 then
        if getPlayerBalance(player) < price then
            restoreTonerPreview(player, vehicle, row)
            return finish("РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ СЃСЂРµРґСЃС‚РІ.", false, vehicle)
        end
        if not changePlayerMoney(player, -price) then
            restoreTonerPreview(player, vehicle, row)
            return finish("РћС€РёР±РєР° РґРµРЅРµР¶РЅРѕР№ РѕРїРµСЂР°С†РёРё.", false, vehicle)
        end
        moneyCharged = true
    end

    if not RPCarDB.updateVehicle(row.id, {
        toner_percent = desired.rear,
        toner_lob_percent = desired.lob,
        toner_front_percent = desired.front,
        toner_rear_percent = desired.rear
    }) then
        if moneyCharged then changePlayerMoney(player, price) end
        restoreTonerPreview(player, vehicle, row)
        return finish("РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕС…СЂР°РЅРёС‚СЊ С‚РѕРЅРёСЂРѕРІРєСѓ. Р”РµРЅСЊРіРё РІРѕР·РІСЂР°С‰РµРЅС‹.", false, vehicle)
    end

    row = RPCarDB.vehicles[row.id]
    setPersonalRuntime(vehicle, row)
    triggerClientEvent(root, CarConfig.events.applyTonerPreview, resourceRoot, vehicle, tonerStateFromRow(row))
    notify(player, "РўРѕРЅРёСЂРѕРІРєР° СѓСЃС‚Р°РЅРѕРІР»РµРЅР° Р·Р° " .. CarConfig.formatMoney(price) .. ".", true)
    finish(nil, true, vehicle)
end)

addEvent(CarConfig.events.exitTuning, true)
addEventHandler(CarConfig.events.exitTuning, root, function()
    if client ~= source then return end
    finishTuningSession(client)
end)

addEvent(CarConfig.events.sellStateVehicle, true)
addEventHandler(CarConfig.events.sellStateVehicle, root, function()
    if client ~= source then return end
    local player = client
    debugLog("[RP CAR] State sale request received: player=" .. tostring(rpName(player)))

    if not isLogged(player) then notify(player, "Авторизуйтесь для продажи автомобиля.", false); return end

    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then
        notify(player, "Вы должны быть за рулём своего автомобиля.", false)
        return
    end
    if not isPersonalVehicle(vehicle) then notify(player, "Это не личный автомобиль.", false); return end
    if not isPlayerVehicleOwner(player, vehicle) then notify(player, "Вы не владелец этого автомобиля.", false); return end

    local vehicleId = getVehicleDatabaseId(vehicle)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then notify(player, "Запись автомобиля не найдена.", false); return end

    local refund = math.floor((tonumber(row.gov_price) or 0) * (tonumber(CarConfig.stateVehicleSellPercent) or 50) / 100)
    if refund <= 0 then notify(player, "Некорректная цена выкупа.", false); return end

    debugLog("[RP CAR] Sale amount: " .. tostring(refund))
    local moneyCredited = creditAccountOrPlayer(row.owner_account_id, player, refund)
    debugLog("[RP CAR] Money credited: " .. (moneyCredited and "YES" or "NO"))
    if not moneyCredited then
        notify(player, "Ошибка денежной операции. Автомобиль не продан.", false)
        debugLog("sell state failed: money operation")
        return
    end

    local vehicleDeleted = RPCarDB.deleteVehicle(row.id)
    debugLog("[RP CAR] Vehicle deleted: " .. (vehicleDeleted and "YES" or "NO"))
    if not vehicleDeleted then
        local rollback = changePlayerMoney(player, -refund)
        debugLog("[RP CAR] Sale rollback: " .. (rollback and "YES" or "NO"))
        notify(player, rollback and "Не удалось удалить автомобиль. Продажа отменена." or "Критическая ошибка продажи. Обратитесь к администрации.", false)
        debugLog("sell state warning: db delete failed after credit, vehicleId=" .. tostring(row.id))
        return
    end
    destroyPersonalVehicle(row.id, false)

    notify(player, "Автомобиль продан государству за " .. CarConfig.formatMoney(refund) .. ".", true)
    debugLog("sell state success: vehicleId=" .. tostring(row.id))
end)

local function resolvePlayerById(id)
    id = tonumber(id)
    if not id then return false end
    for _, player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player, "rp:id")) == id then return player end
    end
    return false
end

local function vehicleExitPoint(vehicle)
    local x, y, z, rotation, interior, dimension = safeExitPoint(vehicle)
    if not x then return false end
    return {
        x = x, y = y, z = z,
        rotation = rotation or 0,
        interior = interior or 0,
        dimension = dimension or 0
    }
end

local function ejectPassengerCommand(player, targetId)
    if not isLogged(player) then return end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or (not CarInteraction.ready(player) or getPedOccupiedVehicleSeat(player) ~= 0) then
        notify(player, "Вы должны быть водителем транспорта.", false)
        return
    end

    local target = resolvePlayerById(targetId)
    if not target then notify(player, "Игрок с таким ID не найден.", false); return end
    if target == player then notify(player, "Нельзя высадить самого себя.", false); return end
    if getPedOccupiedVehicle(target) ~= vehicle then
        notify(player, "Игрок с указанным ID не находится в вашем транспорте.", false)
        return
    end

    triggerClientEvent(target, CarConfig.events.forceExitVehicle, resourceRoot)
    local exitPoint = vehicleExitPoint(vehicle)
    setTimer(function(driver, passenger, sourceVehicle, point)
        if not isElement(passenger) or getPedOccupiedVehicle(passenger) ~= sourceVehicle then return end
        removePedFromVehicle(passenger)
        setTimer(function(targetPlayer, fallbackPoint)
            if isElement(targetPlayer) and not getPedOccupiedVehicle(targetPlayer) then
                movePlayerToSafeExit(targetPlayer, fallbackPoint)
            end
        end, 100, 1, passenger, point)
    end, 2200, 1, player, target, vehicle, exitPoint)

    notify(player, "Вы высадили игрока " .. rpName(target) .. " из транспорта.", true)
    notify(target, "Водитель высадил вас из транспорта.", false)
    return true
end

addCommandHandler("eject", function(player, _, targetId)
    ejectPassengerCommand(player, targetId)
end)

addEvent("car:ejectCommand", true)
addEventHandler("car:ejectCommand", root, function(targetId)
    ejectPassengerCommand(source, targetId)
end)

addEvent(CarConfig.events.offerVehicle, true)
addEventHandler(CarConfig.events.offerVehicle, root, function(targetId, price)
    if client ~= source then return end
    local seller = client
    price = math.floor(tonumber(price) or 0)
    if price <= 0 then notify(seller, "Введите корректную цену.", false); return end
    local vehicle = getPedOccupiedVehicle(seller)
    if not vehicle or (not CarInteraction.ready(seller) or getPedOccupiedVehicleSeat(seller) ~= 0) or not isPlayerVehicleOwner(seller, vehicle) then
        notify(seller, "Вы должны быть за рулём своего автомобиля.", false)
        return
    end
    local buyer = resolvePlayerById(targetId)
    if not buyer or buyer == seller or not isLogged(buyer) then notify(seller, "Покупатель не найден.", false); return end
    local sx, sy, sz = getElementPosition(seller)
    local bx, by, bz = getElementPosition(buyer)
    if getElementInterior(seller) ~= getElementInterior(buyer) or getElementDimension(seller) ~= getElementDimension(buyer)
        or getDistanceBetweenPoints3D(sx, sy, sz, bx, by, bz) > (tonumber(CarConfig.sellDistance) or 5) then
        notify(seller, "Покупатель слишком далеко.", false)
        return
    end
    local buyerHouse = getPlayerHouse(buyer)
    if not buyerHouse or not buyerHouse.id then notify(seller, "У покупателя нет дома.", false); return end
    if not findFreeParking(buyerHouse.id) then notify(seller, "У покупателя нет свободной парковки.", false); return end
    if getPlayerBalance(buyer) < price then notify(seller, "У покупателя недостаточно денег.", false); return end

    local vehicleId = getVehicleDatabaseId(vehicle)
    local offerId = tostring(vehicleId) .. ":" .. tostring(getTickCount())
    sellOffers[offerId] = {
        seller = seller,
        buyer = buyer,
        vehicleId = vehicleId,
        price = price,
        expires = getTickCount() + (tonumber(CarConfig.sellOfferTimeout) or 30000)
    }
    triggerClientEvent(buyer, CarConfig.events.receiveOffer, resourceRoot, offerId, {
        seller = rpName(seller),
        vehicle = getElementData(vehicle, "car:customName") or "Автомобиль",
        price = price
    })
    notify(seller, "Предложение отправлено игроку.", true)
    setTimer(function(id)
        if sellOffers[id] then sellOffers[id] = nil end
    end, tonumber(CarConfig.sellOfferTimeout) or 30000, 1, offerId)
end)

addEvent(CarConfig.events.answerOffer, true)
addEventHandler(CarConfig.events.answerOffer, root, function(offerId, accepted)
    if client ~= source then return end
    local buyer = client
    local offer = sellOffers[tostring(offerId or "")]
    if not offer or offer.buyer ~= buyer or getTickCount() > offer.expires then
        notify(buyer, "Предложение больше не активно.", false)
        return
    end
    sellOffers[offerId] = nil
    local seller = offer.seller
    if not accepted then
        notify(buyer, "Вы отказались от покупки.", true)
        if isElement(seller) then notify(seller, "Покупатель отказался.", false) end
        return
    end
    if not isElement(seller) or not isLogged(seller) then notify(buyer, "Продавец офлайн.", false); return end
    local row = RPCarDB.vehicles[offer.vehicleId]
    if not row then notify(buyer, "Автомобиль не найден.", false); return end
    local vehicle = elementByVehicleId[row.id]
    if not vehicle or not isElement(vehicle) or not isPlayerVehicleOwner(seller, vehicle) then notify(buyer, "Автомобиль недоступен.", false); return end
    if getPlayerBalance(buyer) < offer.price then notify(buyer, "Недостаточно денег.", false); return end
    local house = getPlayerHouse(buyer)
    if not house or not house.id then notify(buyer, "Для покупки автомобиля необходимо иметь дом.", false); return end
    local parking = findFreeParking(house.id)
    if not parking then notify(buyer, "Все парковочные места вашего дома заняты.", false); return end

    local buyerId, sellerId = accountId(buyer), accountId(seller)
    if not buyerId or not sellerId then
        notify(buyer, "Ошибка аккаунта участника сделки.", false)
        return
    end
    if not changePlayerMoney(buyer, -offer.price) then
        notify(buyer, "Ошибка списания денег.", false)
        return
    end
    if not creditAccountOrPlayer(sellerId, seller, offer.price) then
        changePlayerMoney(buyer, offer.price)
        notify(buyer, "Не удалось начислить деньги продавцу. Сделка отменена.", false)
        notify(seller, "Ошибка денежной операции. Сделка отменена.", false)
        return
    end

    local ownershipUpdated = RPCarDB.updateVehicle(row.id, {
        owner_account_id = buyerId,
        house_id = house.id,
        parking_slot = parking.slot
    })
    if not ownershipUpdated then
        changePlayerMoney(seller, -offer.price)
        changePlayerMoney(buyer, offer.price)
        notify(buyer, "Не удалось сохранить сделку. Деньги возвращены.", false)
        notify(seller, "Не удалось сохранить сделку. Продажа отменена.", false)
        return
    end
    row = RPCarDB.vehicles[row.id] or row
    setPersonalRuntime(vehicle, row)
    applyConfiguredHandling(vehicle, row)
    applyPersonalVehicleState(vehicle, row)
    notify(buyer, "Вы купили автомобиль.", true)
    notify(seller, "Автомобиль продан игроку " .. rpName(buyer) .. ".", true)
end)

addEventHandler("onPlayerQuit", root, function()
    purchaseLocks[source] = nil
    tuningLocks[source] = nil
    finishTuningSession(source, true)
    showcaseTransitions[source] = nil
    animatedExitPending[source] = nil
    for offerId, offer in pairs(sellOffers) do
        if offer.seller == source or offer.buyer == source then
            sellOffers[offerId] = nil
        end
    end
    despawnPlayerVehicles(source)
end)

addEvent("auth:spawned", true)
addEventHandler("auth:spawned", root, function(player)
    if client and client ~= player then return end
    if isElement(player) then
        spawnPlayerVehicles(player)
        setTimer(syncAllVehicleToners, 800, 1, player)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    if not RPCarDB.init() then return end
    createMapBlips()
    createTuningMarkers()
    spawnShowcases()
    spawnAllPersonalVehicles()
    setTimer(syncAllVehicleToners, 800, 1)
    setTimer(syncAllVehicleToners, 2000, 1)
    setTimer(syncAllVehicleToners, 4500, 1)
    local m = CarConfig.usedMarket.marker
    usedMarketMarker = createMarker(m.x, m.y, m.z - 1, "cylinder", m.size, 79, 195, 247, 120)
    setElementInterior(usedMarketMarker, m.interior or 0)
    setElementDimension(usedMarketMarker, m.dimension or 0)
    addEventHandler("onMarkerHit", usedMarketMarker, handleUsedMarketHit)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    resourceStopping = true
    local sessionPlayers = {}
    for player in pairs(tuningSessions) do
        sessionPlayers[#sessionPlayers + 1] = player
    end
    for _, player in ipairs(sessionPlayers) do
        if isElement(player) then finishTuningSession(player, true) end
    end
    for vehicle in pairs(personalByElement) do
        if isElement(vehicle) then saveVehiclePosition(vehicle) end
    end
    destroyTuningMarkers()
    destroyMapBlips()
end)

addCommandHandler("carinfo", function(player)
    if not isAdmin(player, "adminVehicles") then notify(player, "Недостаточно прав.", false); return end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle then notify(player, "Вы должны находиться в автомобиле.", false); return end
    local id = getVehicleDatabaseId(vehicle)
    local row = id and RPCarDB.vehicles[id]
    if not row then notify(player, "Это не личный автомобиль.", false); return end
    notify(player, "ID: " .. tostring(row.id) .. ", владелец: " .. tostring(row.owner_account_id) .. ", дом: " .. tostring(row.house_id) .. ", парковка: " .. tostring(row.parking_slot) .. ".", true)
end)

addCommandHandler("carsave", function(player)
    if not isAdmin(player, "adminVehicles") then notify(player, "Недостаточно прав.", false); return end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or not isPersonalVehicle(vehicle) then notify(player, "Вы должны находиться в личном автомобиле.", false); return end
    local ok = saveVehiclePosition(vehicle)
    notify(player, ok and "Автомобиль сохранён." or "Не удалось сохранить автомобиль.", ok)
end)

addCommandHandler("cardel", function(player, _, vehicleId)
    if not isAdmin(player, "adminVehicles") then notify(player, "Недостаточно прав.", false); return end
    local id = tonumber(vehicleId)
    if not id then
        local vehicle = getPedOccupiedVehicle(player)
        id = vehicle and getVehicleDatabaseId(vehicle)
    end
    if not id or not RPCarDB.vehicles[id] then notify(player, "Личный автомобиль не найден.", false); return end
    destroyPersonalVehicle(id, false)
    RPCarDB.deleteVehicle(id)
    notify(player, "Автомобиль удалён.", true)
end)

function releaseHouseVehicles(houseId, ownerId, reason)
    houseId = tonumber(houseId) or 0
    ownerId = tonumber(ownerId) or 0
    if houseId == 0 then return 0 end

    local ids = {}
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.house_id) == houseId and (ownerId <= 0 or tonumber(row.owner_account_id) == ownerId) then
            ids[#ids + 1] = row.id
        end
    end

    local released = 0
    for _, vehicleId in ipairs(ids) do
        if clearVehicleParking(vehicleId, VehicleStatuses.noParking, true) then
            released = released + 1
            debugLog("vehicle released from house: vehicleId=" .. tostring(vehicleId) .. ", house=" .. tostring(houseId) .. ", reason=" .. tostring(reason))
        end
    end
    return released
end

addEvent("car:onHouseDetached", true)
addEventHandler("car:onHouseDetached", root, function(houseId, ownerId, reason)
    releaseHouseVehicles(houseId, ownerId, reason)
end)

local function placeVehicleOnParking(vehicleId, parking, status)
    vehicleId = tonumber(vehicleId)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row or not parking then return false end

    local vehicle = elementByVehicleId[vehicleId]
    if isElement(vehicle) then
        local x, y, z = getElementPosition(vehicle)
        local rx, ry, rz = getElementRotation(vehicle)
        local update = {
            house_id = tonumber(parking.house_id) or tonumber(row.house_id) or 0,
            parking_slot = tonumber(parking.slot) or 0,
            x = x,
            y = y,
            z = z,
            rx = rx or 0,
            ry = ry or 0,
            rz = rz or 0,
            interior = getElementInterior(vehicle),
            dimension = getElementDimension(vehicle),
            health = math.max(500, tonumber(getElementHealth(vehicle)) or tonumber(row.health) or 1000),
            status = status == VehicleStatuses.parked and VehicleStatuses.active or (status or VehicleStatuses.active)
        }

        if not RPCarDB.updateVehicle(vehicleId, update) then return false end
        row = RPCarDB.vehicles[vehicleId]
        setPersonalRuntime(vehicle, row)
        applyConfiguredHandling(vehicle, row)
        applyPersonalVehicleState(vehicle, row)
        return true
    end

    local update = {
        house_id = tonumber(parking.house_id) or tonumber(row.house_id) or 0,
        parking_slot = tonumber(parking.slot) or 0,
        x = parking.x,
        y = parking.y,
        z = parking.z,
        rx = parking.rx or 0,
        ry = parking.ry or 0,
        rz = parking.rz or 0,
        interior = parking.interior or 0,
        dimension = parking.dimension or 0,
        health = math.max(500, tonumber(row.health) or 1000),
        status = status or VehicleStatuses.parked
    }

    if not RPCarDB.updateVehicle(vehicleId, update) then return false end
    row = RPCarDB.vehicles[vehicleId]
    return createPersonalVehicle(row, true, parking) ~= false
end

function assignHouseVehicles(ownerId, houseId, reason)
    ownerId = tonumber(ownerId) or 0
    houseId = tonumber(houseId) or 0
    if ownerId <= 0 or houseId == 0 or not accountOwnsHouse(ownerId, houseId) then return 0 end

    local candidates = {}
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.owner_account_id) == ownerId then
            local noHouse = (tonumber(row.house_id) or 0) == 0 or (tonumber(row.parking_slot) or 0) <= 0
            if noHouse or isVehicleStoredWithoutParking(row) or tostring(row.status or "") == VehicleStatuses.destroyed then
                candidates[#candidates + 1] = row
            end
        end
    end
    table.sort(candidates, function(a, b)
        local pa, pb = tonumber(a.gov_price) or 0, tonumber(b.gov_price) or 0
        if pa == pb then return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end
        return pa < pb
    end)

    local assigned = 0
    for _, row in ipairs(candidates) do
        local parking = findFreeParking(houseId)
        if not parking then break end
        parking.house_id = houseId
        if placeVehicleOnParking(row.id, parking, VehicleStatuses.parked) then
            assigned = assigned + 1
            debugLog("vehicle assigned to new house: vehicleId=" .. tostring(row.id) .. ", house=" .. tostring(houseId) .. ", reason=" .. tostring(reason))
        end
    end
    return assigned
end

function getPlayerVehicles(player)
    local id = accountId(player)
    if not id then return {} end
    local list = {}
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.owner_account_id) == id then list[#list + 1] = row end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function getVehicleOwner(vehicle)
    local data = getPersonalRuntime(vehicle)
    if data and data.ownerAccountId then return data.ownerAccountId end
    local id = getVehicleDatabaseId(vehicle)
    local row = id and RPCarDB.vehicles[id]
    return row and row.owner_account_id or false
end

function getVehicleDatabaseId(vehicle)
    if not isElement(vehicle) then return false end
    local data = getPersonalRuntime(vehicle)
    if data and data.vehicleId then return data.vehicleId end
    return tonumber(personalByElement[vehicle]) or tonumber(getElementData(vehicle, "car:vehicleId")) or tonumber(getElementData(vehicle, "rp_car:id")) or false
end

function isPersonalVehicle(vehicle)
    return getVehicleDatabaseId(vehicle) ~= false
end

function getVehicleHouseId(vehicle)
    local row = RPCarDB.vehicles[getVehicleDatabaseId(vehicle) or 0]
    return row and row.house_id or false
end

function getVehicleParkingSpace(vehicle)
    local row = RPCarDB.vehicles[getVehicleDatabaseId(vehicle) or 0]
    return row and row.parking_slot or false
end

function savePersonalVehicle(vehicle)
    return saveVehiclePosition(vehicle)
end

recoverPlayerVehicleParking = function(player)
    local ownerId = accountId(player)
    local house = getPlayerHouse(player)
    if not ownerId or not house or not accountOwnsHouse(ownerId, house.id) then return 0 end
    return assignHouseVehicles(ownerId, house.id, "restore_owned_parking")
end

function spawnPlayerVehicles(player)
    if not coreRunning() or not homeRunning() then return {} end
    recoverPlayerVehicleParking(player)
    local spawned = {}
    for _, row in ipairs(getPlayerVehicles(player)) do
        local vehicle = false
        if isVehicleStoredWithoutParking(row) then
            vehicle = false
        elseif tostring(row.status or "") == VehicleStatuses.destroyed then
            if validateVehicleParking(row) then
                respawnLocks[row.id] = true
                respawnPersonalVehicleOnParking(row.id, 1)
                vehicle = elementByVehicleId[row.id]
            else
                clearVehicleParking(row.id, VehicleStatuses.noParking)
            end
        else
            local parking = validateVehicleParking(row)
            if parking then
                vehicle = createPersonalVehicle(row, true, parking)
            elseif isUnparkedActiveVehicle(row) then
                vehicle = createPersonalVehicle(row)
            else
                clearVehicleParking(row.id, VehicleStatuses.noParking)
            end
        end
        if vehicle then spawned[#spawned + 1] = vehicle end
    end
    return spawned
end

function despawnPlayerVehicles(player)
    local id = accountId(player)
    if not id then return false end
    for vehicle, vehicleId in pairs(personalByElement) do
        local row = RPCarDB.vehicles[vehicleId]
        if row and tonumber(row.owner_account_id) == id and isElement(vehicle) then
            saveVehiclePosition(vehicle)
            clearPersonalRuntime(vehicle, vehicleId)
            destroyElement(vehicle)
        end
    end
    return true
end

function transferVehicleOwnership(vehicleId, newOwner)
    vehicleId = tonumber(vehicleId)
    local row = vehicleId and RPCarDB.vehicles[vehicleId]
    if not row then return false end
    local ownerId = tonumber(newOwner)
    if isElement(newOwner) then ownerId = accountId(newOwner) end
    if not ownerId then return false end
    if not RPCarDB.updateVehicle(vehicleId, { owner_account_id = ownerId }) then return false end
    local vehicle = elementByVehicleId[vehicleId]
    local updated = RPCarDB.vehicles[vehicleId]
    if isElement(vehicle) and updated then
        setPersonalRuntime(vehicle, updated)
        applyConfiguredHandling(vehicle, updated)
        applyPersonalVehicleState(vehicle, updated)
    end
    return true
end

function isHouseParkingSpaceOccupied(houseId, parkingSlot)
    houseId = tonumber(houseId) or 0
    parkingSlot = tonumber(parkingSlot) or 0
    for _, row in pairs(RPCarDB.vehicles) do
        if tonumber(row.house_id) == houseId and tonumber(row.parking_slot) == parkingSlot then return true, row.id end
    end
    return false
end

function getFreeHouseParkingSpace(houseId)
    return findFreeParking(houseId)
end

-- Explicit user diagnostics; never changes ownership, money or vehicle state.
local controlsDiagnosticTicks = setmetatable({}, {__mode="k"})
addEvent("car:controlsDiagnostic",true)
addEventHandler("car:controlsDiagnostic",root,function()
    if not client or source~=client then return end
    local now=getTickCount()
    if controlsDiagnosticTicks[client] and now-controlsDiagnosticTicks[client]<2000 then return end
    controlsDiagnosticTicks[client]=now
    local vehicle=getPedOccupiedVehicle(client)
    local runtime=vehicle and getPersonalRuntime(vehicle)
    local row=runtime and RPCarDB.vehicles[runtime.vehicleId]
    outputChatBox("[carcontrols] server: account="..tostring(accountId(client))..", ready="..tostring(CarInteraction.ready(client))
        ..", vehicleId="..tostring(runtime and runtime.vehicleId)..", owner="..tostring(row and row.owner_account_id)
        ..", status="..tostring(row and row.status)..", house="..tostring(row and row.house_id)
        ..", showroom="..tostring(vehicle and showcaseByElement[vehicle]~=nil)
        ..", tuning="..tostring(tuningSessions[client]~=nil),client,255,220,120)
end)
