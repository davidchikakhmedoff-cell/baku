local SHADER_PATH = "toner/Assets/shaders/toner.fx"

local TONER_ZONES = {
    lob = {
        data = {"car:tonerLobPercent", "rp_car:tonerLobPercent"},
        textures = {"lob_steklo", "windscreen_oklobb", "windscreen_dummy"}
    },
    front = {
        data = {"car:tonerFrontPercent", "rp_car:tonerFrontPercent"},
        textures = {"pered_steklo", "window_lf", "window_rf"}
    },
    rear = {
        data = {"car:tonerRearPercent", "rp_car:tonerRearPercent", "car:tonerPercent", "rp_car:tonerPercent"},
        textures = {"zad_steklo", "windscreen_okzad"}
    }
}

local shaders = {}
local queuedVehicles = {}

local function debugToner(message)
    if CarConfig and CarConfig.DebugMode then
        outputDebugString("[RP CAR TONER] " .. tostring(message), 3)
    end
end

local function clampPercent(value)
    value = tonumber(value) or 0
    value = math.floor(value / 10 + 0.5) * 10
    return math.max(0, math.min(100, value))
end

local function normalizeState(state)
    if type(state) ~= "table" then
        local value = clampPercent(state)
        return { lob = value, front = value, rear = value }
    end
    return {
        lob = clampPercent(state.lob),
        front = clampPercent(state.front),
        rear = clampPercent(state.rear)
    }
end

local function removeZoneShader(vehicle, zone)
    local vehicleShaders = shaders[vehicle]
    local shader = vehicleShaders and vehicleShaders[zone]
    if not shader then return end

    if isElement(shader) then
        for _, textureName in ipairs(TONER_ZONES[zone].textures) do
            engineRemoveShaderFromWorldTexture(shader, textureName, vehicle)
        end
        destroyElement(shader)
    end
    vehicleShaders[zone] = nil
end

local function removeAllShaders(vehicle)
    if not shaders[vehicle] then return end
    for zone in pairs(TONER_ZONES) do
        removeZoneShader(vehicle, zone)
    end
    shaders[vehicle] = nil
end

local function ensureZoneShader(vehicle, zone)
    shaders[vehicle] = shaders[vehicle] or {}
    local shader = shaders[vehicle][zone]
    if shader and isElement(shader) then return shader end

    shader = dxCreateShader(SHADER_PATH, 0, 0, false, "vehicle")
    if not shader then
        debugToner("Shader create failed: " .. SHADER_PATH)
        return false
    end
    shaders[vehicle][zone] = shader
    return shader
end

local function applyZone(vehicle, zone, percent)
    percent = clampPercent(percent)
    if percent <= 0 then
        removeZoneShader(vehicle, zone)
        return true
    end

    local shader = ensureZoneShader(vehicle, zone)
    if not shader then return false end

    local alpha = 0.18 + (percent / 100) * 0.82
    if percent >= 100 then alpha = 1 end
    dxSetShaderValue(shader, "alpha", math.min(1, alpha))
    for _, textureName in ipairs(TONER_ZONES[zone].textures) do
        engineApplyShaderToWorldTexture(shader, textureName, vehicle, true)
    end
    debugToner("Applied " .. tostring(zone) .. " toner " .. tostring(percent) .. "%")
    return true
end

function applyVehicleToner(vehicle, state)
    if not isElement(vehicle) then return false end
    state = normalizeState(state)
    for zone in pairs(TONER_ZONES) do
        applyZone(vehicle, zone, state[zone])
    end
    return true
end

local function getElementZonePercent(vehicle, zone)
    for _, dataName in ipairs(TONER_ZONES[zone].data) do
        local value = getElementData(vehicle, dataName)
        if value ~= nil then return clampPercent(value) end
    end
    return 0
end

local function applyElementToner(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    applyVehicleToner(vehicle, {
        lob = getElementZonePercent(vehicle, "lob"),
        front = getElementZonePercent(vehicle, "front"),
        rear = getElementZonePercent(vehicle, "rear")
    })
end

local function hasTonerData(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return false end
    for _, zone in pairs(TONER_ZONES) do
        for _, dataName in ipairs(zone.data) do
            if getElementData(vehicle, dataName) ~= nil then
                return true
            end
        end
    end
    return false
end

local function queueElementToner(vehicle, delay)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    delay = tonumber(delay) or 100
    local key = "element:" .. tostring(vehicle) .. ":" .. tostring(delay)
    if queuedVehicles[key] then return end
    queuedVehicles[key] = true
    setTimer(function(target, timerKey)
        queuedVehicles[timerKey] = nil
        if isElement(target) then
            applyElementToner(target)
        end
    end, delay, 1, vehicle, key)
end

local function queueVehicleTonerState(vehicle, state, delay)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    delay = tonumber(delay) or 100
    state = normalizeState(state)
    local key = "state:" .. tostring(vehicle) .. ":" .. tostring(delay)
    if queuedVehicles[key] then return end
    queuedVehicles[key] = true
    setTimer(function(target, tonerState, timerKey)
        queuedVehicles[timerKey] = nil
        if isElement(target) then
            applyVehicleToner(target, tonerState)
        end
    end, delay, 1, vehicle, state, key)
end

local function reapplyAllToners(reason, recreateShaders)
    debugToner("Reapply all toners: " .. tostring(reason))
    for _, vehicle in ipairs(getElementsByType("vehicle", root, true)) do
        if hasTonerData(vehicle) then
            if recreateShaders then
                removeAllShaders(vehicle)
            end
            applyElementToner(vehicle)
            queueElementToner(vehicle, 250)
            queueElementToner(vehicle, 1000)
        end
    end
end

addEvent(CarConfig.events.applyTonerPreview, true)
addEventHandler(CarConfig.events.applyTonerPreview, root, function(vehicle, state)
    applyVehicleToner(vehicle, state)
    queueVehicleTonerState(vehicle, state, 150)
    queueVehicleTonerState(vehicle, state, 500)
    queueVehicleTonerState(vehicle, state, 1500)
    queueVehicleTonerState(vehicle, state, 3000)
end)

addEventHandler("onClientElementDataChange", root, function(dataName)
    if not isElement(source) or getElementType(source) ~= "vehicle" then return end
    for _, zone in pairs(TONER_ZONES) do
        for _, zoneDataName in ipairs(zone.data) do
            if dataName == zoneDataName then
                applyElementToner(source)
                queueElementToner(source, 150)
                return
            end
        end
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    applyElementToner(source)
    queueElementToner(source, 250)
    queueElementToner(source, 1200)
end)

addEventHandler("onClientVehicleRespawn", root, function()
    applyElementToner(source)
    queueElementToner(source, 250)
    queueElementToner(source, 1200)
end)

addEventHandler("onClientVehicleEnter", root, function(player)
    if player ~= localPlayer then return end
    applyElementToner(source)
    queueElementToner(source, 150)
    queueElementToner(source, 800)
end)

addEventHandler("onClientElementDestroy", root, function()
    removeAllShaders(source)
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    reapplyAllToners("resource start", true)
    setTimer(reapplyAllToners, 500, 1, "resource start delayed 1", false)
    setTimer(reapplyAllToners, 1500, 1, "resource start delayed 2", false)
    setTimer(reapplyAllToners, 3500, 1, "resource start delayed 3", false)
    setTimer(reapplyAllToners, 4000, 0, "watchdog", false)
end)

addEventHandler("onClientRestore", root, function()
    setTimer(reapplyAllToners, 100, 1, "client restore", true)
    setTimer(reapplyAllToners, 1000, 1, "client restore delayed", false)
end)
