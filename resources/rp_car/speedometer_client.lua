-- Minimal vehicle HUD. No changes to controls, handling or persistent vehicle data.
local authorized = false
local lastVehicle, displayedSpeed, lastTick = nil, 0, nil
local screenW, screenH, scale, numberFont
local white, muted = tocolor(245, 247, 250), tocolor(130, 137, 146, 210)
local brakeColor, doorColor, lightColor = tocolor(239, 83, 80), tocolor(242, 166, 74), tocolor(103, 196, 216)

local function reset()
    lastVehicle, displayedSpeed, lastTick = nil, 0, nil
end

local function layout()
    screenW, screenH = guiGetScreenSize()
    scale = math.min(screenW / 1920, screenH / 1080)
    if isElement(numberFont) then destroyElement(numberFont) end
    numberFont = dxCreateFont(":rp_core/CompactC.ttf", math.max(12, math.floor(64 * scale)), false, "cleartype")
end

local function line(x1, y1, x2, y2, color)
    dxDrawLine(x1, y1, x2, y2, color, math.max(1, 1.5 * scale))
end

local function text(value, x, y, w, h, color, size, font, align)
    -- Small shadow keeps white digits legible against bright roads without a panel.
    dxDrawText(value, x + 1, y + 1, x + w + 1, y + h + 1, tocolor(0, 0, 0, 150), size, font, align, "center")
    dxDrawText(value, x, y, x + w, y + h, color, size, font, align, "center")
end

local function doorsOpen(vehicle)
    -- IDs 2..5 are passenger doors; bonnet and boot are deliberately excluded.
    for door = 2, 5 do
        -- State 4 means missing: a missing door must not count as open.
        if getVehicleDoorState(vehicle, door) ~= 4 and (getVehicleDoorOpenRatio(vehicle, door) or 0) > 0.05 then
            return true
        end
    end
    return false
end

local function lightsOn(vehicle)
    local override = getVehicleOverrideLights(vehicle)
    if override == 1 then return false end
    if getVehicleLightState(vehicle, 0) == 1 and getVehicleLightState(vehicle, 1) == 1 then return false end
    if override == 2 then return true end
    -- Stock GTA automatic headlights follow the game clock. rp_car uses explicit overrides.
    local hour = getTime()
    return getVehicleEngineState(vehicle) and (hour >= 20 or hour < 6)
end

local function drawIndicators(vehicle, x, y)
    local unit = scale
    local brake = getElementData(vehicle, "car:handbrake") == true or getPedControlState(localPlayer, "handbrake")
    local color = brake and brakeColor or muted
    text("P", x, y - 3 * unit, 22 * unit, 24 * unit, color, unit, "default-bold", "center")
    line(x - 3 * unit, y, x - 3 * unit, y + 17 * unit, color)
    line(x + 25 * unit, y, x + 25 * unit, y + 17 * unit, color)
    text("BRAKE", x - 13 * unit, y + 25 * unit, 48 * unit, 14 * unit, muted, 0.7 * unit, "default-bold", "center")

    x = x + 73 * unit
    color = doorsOpen(vehicle) and doorColor or muted
    line(x, y + 18 * unit, x, y, color)
    line(x, y, x + 17 * unit, y + 3 * unit, color)
    line(x + 17 * unit, y + 3 * unit, x + 22 * unit, y + 18 * unit, color)
    line(x + 22 * unit, y + 18 * unit, x, y + 18 * unit, color)
    line(x + 5 * unit, y + 5 * unit, x + 14 * unit, y + 7 * unit, color)
    line(x + 13 * unit, y + 12 * unit, x + 17 * unit, y + 12 * unit, color)
    text("DOOR", x - 13 * unit, y + 25 * unit, 48 * unit, 14 * unit, muted, 0.7 * unit, "default-bold", "center")

    x = x + 73 * unit
    color = lightsOn(vehicle) and lightColor or muted
    line(x + 12 * unit, y, x + 12 * unit, y + 18 * unit, color)
    line(x + 12 * unit, y, x + 24 * unit, y + 5 * unit, color)
    line(x + 24 * unit, y + 5 * unit, x + 24 * unit, y + 13 * unit, color)
    line(x + 24 * unit, y + 13 * unit, x + 12 * unit, y + 18 * unit, color)
    for beam = 0, 2 do
        line(x, y + (3 + beam * 6) * unit, x + 7 * unit, y + (3 + beam * 6) * unit, color)
    end
    text("LIGHT", x - 11 * unit, y + 25 * unit, 48 * unit, 14 * unit, muted, 0.7 * unit, "default-bold", "center")
end

local function render()
    local w, h = guiGetScreenSize()
    if w ~= screenW or h ~= screenH then layout() end
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not authorized or isPedDead(localPlayer) or not vehicle or getPedOccupiedVehicleSeat(localPlayer) ~= 0
        or getVehicleType(vehicle) ~= "Automobile" then
        reset()
        return
    end
    local vx, vy, vz = getElementVelocity(vehicle)
    local target = math.max(0, math.sqrt(vx * vx + vy * vy + vz * vz) * 180)
    local now = getTickCount()
    if vehicle ~= lastVehicle then
        displayedSpeed = target
        lastVehicle = vehicle
    else
        local dt = math.max(0, now - (lastTick or now))
        displayedSpeed = displayedSpeed + (target - displayedSpeed) * (1 - math.exp(-dt / 65))
        if math.abs(target - displayedSpeed) < 0.1 then displayedSpeed = target end
    end
    lastTick = now
    local x, y = screenW - 258 * scale, screenH - 205 * scale
    text(string.format("%03d", math.floor(displayedSpeed + 0.5)), x, y, 210 * scale, 90 * scale,
        white, numberFont and 1 or 3.8 * scale, numberFont or "default-bold", "right")
    text("KM/H", x, y + 88 * scale, 208 * scale, 20 * scale, muted, 0.85 * scale, "default-bold", "right")
    line(x + 8 * scale, y + 123 * scale, x + 210 * scale, y + 123 * scale, tocolor(170, 180, 190, 55))
    drawIndicators(vehicle, x + 27 * scale, y + 139 * scale)
end

addEvent("car:speedometerSession", true)
addEventHandler("car:speedometerSession", resourceRoot, function(loggedIn)
    authorized = loggedIn == true
    reset()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    layout()
    triggerServerEvent("car:requestSpeedometerSession", resourceRoot)
end)
addEventHandler("onClientRender", root, render)
addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientRender", root, render)
    if isElement(numberFont) then destroyElement(numberFont) end
    numberFont = nil
end)
