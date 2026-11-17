-- Minimal vehicle HUD. No changes to controls, handling or persistent vehicle data.
local authorized = false
local lastVehicle, displayedSpeed, lastTick = nil, 0, nil
local screenW, screenH, scale, numberFont, labelFont, unitFont, fuelFont
local white, muted = tocolor(245, 247, 250), tocolor(155, 163, 173, 255)
local brakeColor, doorColor, lightColor = tocolor(239, 83, 80), tocolor(242, 166, 74), tocolor(103, 196, 216)

local function reset()
    lastVehicle, displayedSpeed, lastTick = nil, 0, nil
end

local function layout()
    screenW, screenH = guiGetScreenSize()
    scale = math.min(screenW / 1920, screenH / 1080)
    if isElement(numberFont) then destroyElement(numberFont) end
    if isElement(labelFont) then destroyElement(labelFont) end
    if isElement(unitFont) then destroyElement(unitFont) end
    if isElement(fuelFont) then destroyElement(fuelFont) end
    labelFont = dxCreateFont(":rp_core/CompactC.ttf", math.max(11, math.floor(13 * scale + 0.5)), false, "antialiased")
    unitFont = dxCreateFont(":rp_core/CompactC.ttf", math.max(13, math.floor(16 * scale + 0.5)), false, "antialiased")
    fuelFont = dxCreateFont("fonts/DejaVuSans.ttf", math.max(14, math.floor(18 * scale + 0.5)), false, "antialiased")
    numberFont = dxCreateFont(":rp_core/CompactC.ttf", math.max(12, math.floor(69 * scale)), false, "cleartype")
end

local function line(x1, y1, x2, y2, color)
    dxDrawLine(math.floor(x1 + 0.5), math.floor(y1 + 0.5), math.floor(x2 + 0.5), math.floor(y2 + 0.5), color, math.max(1, 1.75 * scale))
end

local function text(value, x, y, w, h, color, size, font, align)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    -- Keep the shadow on large digits only; small labels render in one clean pass.
    if value:match("^%d+$") then
        dxDrawText(value, x + 1, y + 1, x + w + 1, y + h + 1, tocolor(0, 0, 0, 150), size, font, align, "center")
    end
    dxDrawText(value, x, y, x + w, y + h, color, size, font, align, "center")
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
    local brake = getElementData(vehicle, "car:handbrake") == true
    local color = brake and brakeColor or muted
    text("P", x, y - 3 * unit, 22 * unit, 24 * unit, color, 1, unitFont or "default", "center")
    line(x - 3 * unit, y, x - 3 * unit, y + 17 * unit, color)
    line(x + 25 * unit, y, x + 25 * unit, y + 17 * unit, color)
    text("BRAKE", x - 13 * unit, y + 25 * unit, 48 * unit, 14 * unit, color, 1, labelFont or "default-bold", "center")

    x = x + 54 * unit
    -- N toggles the actual lock; door angles do not affect this indicator.
    color = isVehicleLocked(vehicle) and doorColor or muted
    line(x, y + 18 * unit, x, y, color)
    line(x, y, x + 17 * unit, y + 3 * unit, color)
    line(x + 17 * unit, y + 3 * unit, x + 22 * unit, y + 18 * unit, color)
    line(x + 22 * unit, y + 18 * unit, x, y + 18 * unit, color)
    line(x + 5 * unit, y + 5 * unit, x + 14 * unit, y + 7 * unit, color)
    line(x + 13 * unit, y + 12 * unit, x + 17 * unit, y + 12 * unit, color)
    text("DOOR", x - 13 * unit, y + 25 * unit, 48 * unit, 14 * unit, color, 1, labelFont or "default-bold", "center")

    x = x + 54 * unit
    color = lightsOn(vehicle) and lightColor or muted
    line(x + 12 * unit, y, x + 12 * unit, y + 18 * unit, color)
    line(x + 12 * unit, y, x + 24 * unit, y + 5 * unit, color)
    line(x + 24 * unit, y + 5 * unit, x + 24 * unit, y + 13 * unit, color)
    line(x + 24 * unit, y + 13 * unit, x + 12 * unit, y + 18 * unit, color)
    for beam = 0, 2 do
        line(x, y + (3 + beam * 6) * unit, x + 7 * unit, y + (3 + beam * 6) * unit, color)
    end
    text("LIGHT", x - 11 * unit, y + 25 * unit, 48 * unit, 14 * unit, color, 1, labelFont or "default-bold", "center")

    x = x + 54 * unit
    color = getVehicleEngineState(vehicle) and lightColor or muted
    -- Engine block silhouette, with intake and shaft.
    line(x + 3 * unit, y + 5 * unit, x + 8 * unit, y, color)
    line(x + 8 * unit, y, x + 17 * unit, y, color)
    line(x + 17 * unit, y, x + 20 * unit, y + 5 * unit, color)
    line(x + 20 * unit, y + 5 * unit, x + 24 * unit, y + 5 * unit, color)
    line(x + 24 * unit, y + 5 * unit, x + 24 * unit, y + 17 * unit, color)
    line(x + 24 * unit, y + 17 * unit, x + 3 * unit, y + 17 * unit, color)
    line(x + 3 * unit, y + 17 * unit, x + 3 * unit, y + 5 * unit, color)
    line(x - 1 * unit, y + 8 * unit, x + 3 * unit, y + 8 * unit, color)
    line(x - 1 * unit, y + 13 * unit, x + 3 * unit, y + 13 * unit, color)
    text("ENG", x - 13 * unit, y + 25 * unit, 48 * unit, 14 * unit, color, 1, labelFont or "default-bold", "center")
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
    local x, y = screenW - 258 * scale, screenH - 225 * scale
    text(string.format("%03d", math.floor(displayedSpeed + 0.5)), x, y, 210 * scale, 90 * scale,
        white, numberFont and 1 or 3.8 * scale, numberFont or "default-bold", "right")
    text("KM/H", x, y + 88 * scale, 208 * scale, 20 * scale, muted, 1, unitFont or "default-bold", "right")
    local fuel = tonumber(getElementData(vehicle, "car:fuel"))
    local capacity = tonumber(getElementData(vehicle, "car:fuelCapacity"))
    local fuelWhite = tocolor(255, 255, 255, 255)
    -- Outline pump replaces the plain FUEL label, keeping the readout light.
    local px, py = x + 15 * scale, y + 116 * scale
    line(px, py, px + 12 * scale, py, fuelWhite)
    line(px + 12 * scale, py, px + 12 * scale, py + 19 * scale, fuelWhite)
    line(px + 12 * scale, py + 19 * scale, px, py + 19 * scale, fuelWhite)
    line(px, py + 19 * scale, px, py, fuelWhite)
    line(px + 3 * scale, py + 5 * scale, px + 9 * scale, py + 5 * scale, fuelWhite)
    line(px + 12 * scale, py + 8 * scale, px + 17 * scale, py + 11 * scale, fuelWhite)
    line(px + 17 * scale, py + 11 * scale, px + 17 * scale, py + 17 * scale, fuelWhite)
    line(px + 17 * scale, py + 17 * scale, px + 21 * scale, py + 17 * scale, fuelWhite)
    line(px + 21 * scale, py + 17 * scale, px + 21 * scale, py + 4 * scale, fuelWhite)
    line(px + 21 * scale, py + 4 * scale, px + 17 * scale, py, fuelWhite)
    text(fuel and string.format("%.1f L", fuel) or "-- L", x + 45 * scale, y + 112 * scale, 163 * scale, 26 * scale,
        fuelWhite, 1, fuelFont or "default-bold", "right")
    local ratio = fuel and capacity and capacity > 0 and math.max(0, math.min(1, fuel / capacity)) or 0
    -- Ten slim segments give an at-a-glance tank level without a background panel.
    for segment = 0, 9 do
        local left = x + (8 + segment * 20.2) * scale
        local right = left + 16.2 * scale
        line(left, y + 144 * scale, right, y + 144 * scale, tocolor(255, 255, 255, 45))
        local fill = math.max(0, math.min(1, ratio * 10 - segment))
        if fill > 0 then
            line(left, y + 144 * scale, left + (right - left) * fill, y + 144 * scale, fuelWhite)
        end
    end
    drawIndicators(vehicle, x + 27 * scale, y + 159 * scale)
end

addEvent("car:speedometerSession", true)
addEventHandler("car:speedometerSession", resourceRoot, function(loggedIn, accountId)
    CarLockAccountId = loggedIn == true and tonumber(accountId) or nil
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
    if isElement(labelFont) then destroyElement(labelFont) end
    if isElement(unitFont) then destroyElement(unitFont) end
    if isElement(fuelFont) then destroyElement(fuelFont) end
    numberFont, labelFont, unitFont, fuelFont = nil, nil, nil, nil
end)
