local UI = {
    screen = { guiGetScreenSize() },
    scale = 1,
    mode = false,
    data = {},
    hitboxes = {},
    input = nil,
    fields = {},
    offer = nil,
    tuningSelected = nil,
    tonerSelected = nil,
    tonerOriginal = nil,
    tuningCamera = nil,
    tuningPanel = nil,
    tuningDrag = nil
}

local CAR_UI_NAME = "car"
local carMenuFont = nil

UI.scale = math.max(0.85, math.min(1, math.min(UI.screen[1] / 1920, UI.screen[2] / 1080)))

local function s(value)
    return math.floor((tonumber(value) or 0) * UI.scale + 0.5)
end

local function crisp(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function rgba(name, alpha)
    local c = CarConfig.colors[name] or {255, 255, 255, 255}
    return tocolor(c[1], c[2], c[3], alpha or c[4] or 255)
end

local function debugLog(message)
    if CarConfig.DebugMode then
        outputDebugString("[RPCar:Client] " .. tostring(message), 3)
    end
end

local function coreClientRunning()
    local resource = getResourceFromName("rp_core")
    return resource and getResourceState(resource) == "running"
end

local function acquireCarUI()
    if coreClientRunning() and exports.rp_core.openUI then
        return exports.rp_core:openUI(CAR_UI_NAME, true, "no_binds_when_editing")
    end
    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    return true
end

local function releaseCarUI()
    if coreClientRunning() and exports.rp_core.closeUI then
        exports.rp_core:closeUI(CAR_UI_NAME)
        return
    end
    showCursor(false)
    guiSetInputMode("allow_binds")
end

local function isInputBlocked()
    if UI.mode then return true end
    if isChatBoxInputActive and isChatBoxInputActive() then return true end
    if isConsoleActive and isConsoleActive() then return true end
    if isMainMenuActive and isMainMenuActive() then return true end
    if isMTAWindowActive and isMTAWindowActive() then return true end
    if coreClientRunning() then
        local okText, textActive = pcall(function() return exports.rp_core:isTextInputActive() end)
        if okText and textActive then return true end
        local okUI, uiActive = pcall(function() return exports.rp_core:isAnyBlockingUIOpen() end)
        if okUI and uiActive and isCursorShowing() then return true end
    end
    return false
end

local function debugKey(message)
    local text = tostring(message)
    if CarConfig.DebugMode or text:find("N pressed", 1, true) or text:find("Any UI open", 1, true)
        or text:find("Text input active", 1, true) or text:find("Active UI name", 1, true)
        or text:find("Target vehicle", 1, true) or text:find("Distance", 1, true)
        or text:find("Lock event sent", 1, true) then
        outputDebugString("[RP CAR CLIENT] " .. text, 3)
    end
end

local function getCoreUIState()
    local anyOpen, textActive, activeName = false, false, "none"
    if coreClientRunning() then
        local okOpen, openValue = pcall(function() return exports.rp_core:isAnyBlockingUIOpen() end)
        if okOpen then anyOpen = openValue == true end
        local okText, textValue = pcall(function() return exports.rp_core:isTextInputActive() end)
        if okText then textActive = textValue == true end
        local okName, nameValue = pcall(function() return exports.rp_core:getActiveUIName() end)
        if okName and nameValue then activeName = tostring(nameValue) end
    end
    return anyOpen, textActive, activeName
end

local function roundedRect(x, y, w, h, radius, color)
    if DXUtils and DXUtils.roundedRect then
        DXUtils.roundedRect(x, y, w, h, radius, color)
        return
    end
    dxDrawRectangle(x, y, w, h, color)
end

local function inBox(cx, cy, box)
    return cx >= box.x and cx <= box.x + box.w and cy >= box.y and cy <= box.y + box.h
end

local function reset()
    UI.mode = false
    UI.data = {}
    UI.hitboxes = {}
    UI.fields = {}
    UI.input = nil
    UI.tuningSelected = nil
    UI.tonerSelected = nil
    UI.tonerOriginal = nil
    UI.tuningCamera = nil
    UI.tuningPanel = nil
    UI.tuningDrag = nil
    releaseCarUI()
end

local function open(mode, data)
    if not UI.mode and not acquireCarUI() then return false end
    UI.mode = mode
    UI.data = data or {}
    UI.hitboxes = {}
    UI.input = nil
    return true
end

local function close()
    if type(setCameraTarget) == "function" then setCameraTarget(localPlayer) end
    reset()
end

local showroomControls = {
    "forwards", "backwards", "left", "right", "jump", "sprint", "crouch",
    "fire", "aim_weapon", "enter_exit",
    "accelerate", "brake_reverse", "vehicle_left", "vehicle_right", "handbrake",
    "vehicle_fire", "vehicle_secondary_fire", "horn"
}
local savedShowroomControls
local animatedExitActive = false
local keyDebounce = {}

local function setControlsEnabled(enabled)
    if enabled == true then
        if not savedShowroomControls then return end
        for control, wasEnabled in pairs(savedShowroomControls) do
            toggleControl(control, wasEnabled)
        end
        savedShowroomControls = nil
        return
    end

    if savedShowroomControls then return end
    savedShowroomControls = {}
    for _, control in ipairs(showroomControls) do
        savedShowroomControls[control] = isControlEnabled(control)
        toggleControl(control, false)
    end
end

local function completeAnimatedExit()
    if not animatedExitActive then return end
    animatedExitActive = false
    setPedControlState("enter_exit", false)
    setControlsEnabled(true)
    if type(setCameraTarget) == "function" then setCameraTarget(localPlayer) end
    triggerServerEvent(CarConfig.events.animatedExitComplete, localPlayer)
end

local function beginAnimatedExit()
    close()
    if type(setCameraTarget) == "function" then setCameraTarget(localPlayer) end

    if not isPedInVehicle(localPlayer) then
        setControlsEnabled(true)
        triggerServerEvent(CarConfig.events.animatedExitComplete, localPlayer)
        return
    end

    animatedExitActive = true
    toggleControl("enter_exit", true)
    setPedControlState("enter_exit", true)
    setTimer(function()
        setPedControlState("enter_exit", false)
    end, 180, 1)

    setTimer(function()
        if animatedExitActive and not isPedInVehicle(localPlayer) then
            completeAnimatedExit()
        end
    end, 100, 40)
end

local function button(id, text, x, y, w, h, enabled)
    enabled = enabled ~= false
    local cx, cy = getCursorPosition()
    cx, cy = cx and cx * UI.screen[1] or -1, cy and cy * UI.screen[2] or -1
    local hover = enabled and inBox(cx, cy, { x = x, y = y, w = w, h = h })
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    local background = enabled and (hover and tocolor(17, 17, 17, 255) or tocolor(14, 14, 14, 255)) or tocolor(14, 14, 14, 255)
    local textColor = enabled and tocolor(245, 245, 245, 255) or tocolor(47, 47, 47, 255)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 255))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, background)
    dxDrawRectangle(x + s(3), y + 1, w - s(6), 1, tocolor(18, 18, 18, 255))
    dxDrawRectangle(x + s(3), y + h - 2, w - s(6), 1, tocolor(5, 5, 5, 255))
    dxDrawText(text, x + s(5), y, x + w - s(5), y + h, textColor, 1, "default-bold", "center", "center", true)
    if enabled then
        UI.hitboxes[id] = { x = x, y = y, w = w, h = h }
    end
end

local function field(id, placeholder, x, y, w, h)
    UI.fields[id] = UI.fields[id] or ""
    local active = UI.input == id
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    roundedRect(x, y, w, h, s(6), rgba("button"))
    if active then dxDrawRectangle(x, y + h - s(2), w, s(2), rgba("primary", 230)) end
    local text = UI.fields[id] ~= "" and UI.fields[id] or placeholder
    dxDrawText(text, x + s(10), y, x + w - s(10), y + h, UI.fields[id] ~= "" and rgba("text") or rgba("muted"), 1, "default", "left", "center", true)
    UI.hitboxes["field:" .. id] = { x = x, y = y, w = w, h = h, field = id }
end

local function panel(title, height)
    local w = s(CarConfig.ui.width)
    local h = s(height)
    local x = crisp((UI.screen[1] - w) / 2)
    local y = crisp((UI.screen[2] - h) / 2)
    roundedRect(x, y, w, h, s(CarConfig.ui.radius), rgba("window", 238))
    dxDrawText(title, x + s(22), y + s(12), x + w - s(22), y + s(42), rgba("text"), 1.18, "default-bold", "left", "center", true)
    dxDrawRectangle(x + s(22), y + s(50), w - s(44), s(2), rgba("primary", 190))
    return x, y, w, h
end

local function infoLine(label, value, x, y, w)
    dxDrawText(label, crisp(x), crisp(y), crisp(x + w * 0.46), crisp(y + s(22)), rgba("muted"), 1, "default", "left", "center", true)
    dxDrawText(tostring(value or "-"), crisp(x + w * 0.46), crisp(y), crisp(x + w), crisp(y + s(22)), rgba("text"), 1, "default-bold", "right", "center", true)
end

local function windowHeight(rowCount, buttonCount, extra)
    return s(78) + rowCount * s(27) + (extra or 0) + buttonCount * (s(CarConfig.ui.buttonHeight) + s(CarConfig.ui.gap)) + s(20)
end

local function drawRows(rows, x, y, w)
    local yy = y
    for _, row in ipairs(rows) do
        infoLine(row[1], row[2], x, yy, w)
        yy = yy + s(27)
    end
    return yy
end

local function drawActions(actions, x, y, w)
    local btnH = s(CarConfig.ui.buttonHeight)
    local gap = s(CarConfig.ui.gap)
    for index, action in ipairs(actions) do
        button(action[1], action[2], x, y + (index - 1) * (btnH + gap), w, btnH, action[3] ~= false)
    end
end

local function compactPanel(title, width, height)
    local w, h = s(width), s(height)
    local x = crisp((UI.screen[1] - w) / 2)
    local y = crisp((UI.screen[2] - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    local titleScale = 1
    dxDrawText(title, x + s(10), y + s(5), x + w - s(10), y + s(36), rgba("text"), titleScale, carMenuFont or "default-bold", "left", "center", true)
    return x, y, w, h
end

local function compactButton(id, text, x, y, w, h, enabled)
    button(id, text, x, y, w, h, enabled)
end

local function compactGroup(label, value, left, top, right)
    dxDrawText(label, left, top, right, top + s(13), rgba("primary"), 0.9, "default-bold", "left", "center", true)
    dxDrawText(tostring(value or "-"), left, top + s(10), right, top + s(28), rgba("text"), 1, "default-bold", "left", "center", true)
end

local function compactField(id, label, placeholder, x, y, w, h)
    UI.fields[id] = UI.fields[id] or ""
    local active = UI.input == id
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    dxDrawText(label, x, y - s(17), x + w, y - s(2), rgba("primary"), 0.9, "default-bold", "left", "center", true)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 255))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, active and tocolor(12, 12, 12, 255) or tocolor(9, 9, 9, 255))
    local value = UI.fields[id]
    local shown = value ~= "" and value or placeholder
    dxDrawText(shown, x + s(10), y, x + w - s(10), y + h, value ~= "" and rgba("text") or tocolor(100, 100, 100, 255), 1, "default-bold", "left", "center", true)
    if active and (getTickCount() % 1000) < 520 then
        local cursorX = math.min(x + s(10) + dxGetTextWidth(value, 1, "default-bold"), x + w - s(10))
        dxDrawRectangle(cursorX, y + s(6), 1, h - s(12), rgba("text"))
    end
    UI.hitboxes["field:" .. id] = { x = x, y = y, w = w, h = h, field = id }
end

local function drawDealership()
    local d = UI.data
    local p = d.parking or {}
    local x, y, w, h = compactPanel("АВТОСАЛОН", 400, 220)
    compactGroup("автомобиль", tostring(d.name or "Автомобиль"), x + s(14), y + s(47), x + s(190))
    compactGroup("цена", CarConfig.formatMoney(d.price), x + s(14), y + s(82), x + s(190))
    compactGroup("макс. скорость", tostring(d.maxSpeed or 0) .. " км/ч", x + s(228), y + s(47), x + w - s(14))
    compactGroup("свободные парковки", tostring(p.free or 0), x + s(228), y + s(82), x + w - s(14))
    local buttonY = y + h - s(35)
    compactButton("buy", "Купить", x + s(5), buttonY, s(110), s(30), true)
    compactButton("cancel", "Отмена", x + w - s(115), buttonY, s(110), s(30), true)
end

local function drawConfirmPurchase()
    local x, y, w, h = compactPanel("ПОКУПКА АВТОМОБИЛЯ", 400, 170)
    compactGroup("автомобиль", tostring(UI.data.name or "Автомобиль"), x + s(14), y + s(47), x + s(190))
    compactGroup("стоимость", CarConfig.formatMoney(UI.data.price), x + s(228), y + s(47), x + w - s(14))
    local buttonY = y + h - s(35)
    compactButton("buy_confirm", "Купить", x + s(5), buttonY, s(110), s(30), true)
    compactButton("back_dealership", "Назад", x + w - s(115), buttonY, s(110), s(30), true)
end

local function drawUsedMarket()
    local d = UI.data
    local x, y, w = compactPanel("БАЗАР АВТОМОБИЛЕЙ", 270, 205)
    compactGroup("автомобиль", tostring(d.name or "Автомобиль"), x + s(14), y + s(47), x + s(120))
    compactGroup("выкуп государством", CarConfig.formatMoney(d.statePrice), x + s(140), y + s(47), x + w - s(14))
    compactButton("state_confirm", "Продать государству", x + s(10), y + s(90), w - s(20), s(30), true)
    compactButton("sell_player", "Продать игроку", x + s(10), y + s(125), w - s(20), s(30), true)
    compactButton("cancel", "Отмена", x + s(10), y + s(160), w - s(20), s(30), true)
end

local function drawConfirmState()
    local x, y, w, h = compactPanel("ПРОДАЖА ГОСУДАРСТВУ", 400, 170)
    compactGroup("сумма выкупа", CarConfig.formatMoney(UI.data.statePrice), x + s(14), y + s(47), x + s(190))
    dxDrawText("Продажа необратима", x + s(228), y + s(43), x + w - s(14), y + s(84), rgba("muted"), 1, "default-bold", "left", "center", true)
    local buttonY = y + h - s(35)
    compactButton("state_sell", "Продать", x + s(5), buttonY, s(110), s(30), true)
    compactButton("back_market", "Отмена", x + w - s(115), buttonY, s(110), s(30), true)
end

local function drawSellPlayer()
    local x, y, w, h = compactPanel("ПРОДАЖА ИГРОКУ", 400, 210)
    compactField("target", "ID покупателя", "введите ID", x + s(14), y + s(64), w - s(28), s(30))
    compactField("price", "цена продажи", "введите цену", x + s(14), y + s(114), w - s(28), s(30))
    local buttonY = y + h - s(35)
    compactButton("offer_player", "Предложить", x + s(5), buttonY, s(160), s(30), true)
    compactButton("back_market", "Назад", x + w - s(115), buttonY, s(110), s(30), true)
end

local function drawOffer()
    local d = UI.offer or {}
    local x, y, w, h = compactPanel("ПРЕДЛОЖЕНИЕ", 400, 205)
    compactGroup("продавец", tostring(d.seller or "-"), x + s(14), y + s(47), x + s(190))
    compactGroup("автомобиль", tostring(d.vehicle or "-"), x + s(14), y + s(82), x + s(190))
    compactGroup("цена", CarConfig.formatMoney(d.price), x + s(228), y + s(47), x + w - s(14))
    local buttonY = y + h - s(35)
    compactButton("offer_accept", "Купить", x + s(5), buttonY, s(110), s(30), true)
    compactButton("offer_decline", "Отказаться", x + w - s(115), buttonY, s(110), s(30), true)
end

local tuningTitles = {
    suspension = "Подвеска",
    acceleration = "Ускорение",
    max_speed = "Макс. скорость"
}

local function getSelectedTuningLevel(key)
    local selected = UI.tuningSelected or {}
    local current = UI.data and UI.data.levels and UI.data.levels[key] or 0
    return tonumber(selected[key]) or tonumber(current) or 0
end

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function setupTuningCamera(data)
    data = data or UI.data or {}
    local target = data.cameraTarget or (data.camera and {
        x = data.camera.lookX,
        y = data.camera.lookY,
        z = data.camera.lookZ
    }) or nil
    if not target or not target.x or not target.y or not target.z then
        local vehicle = getPedOccupiedVehicle(localPlayer)
        if vehicle then
            local x, y, z = getElementPosition(vehicle)
            target = { x = x, y = y, z = z + 0.85 }
        end
    end
    if not target then return end

    local settings = data.cameraSettings or data.camera or CarConfig.TuningCamera or {}
    local camera = data.camera or {}
    local dx = tonumber(camera.x) and (camera.x - target.x) or -4.2
    local dy = tonumber(camera.y) and (camera.y - target.y) or -5.0
    local dz = tonumber(camera.z) and (camera.z - target.z) or 2.1
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local horizontalDistance = math.sqrt(dx * dx + dy * dy)
    local pitch = atan2(dz, horizontalDistance)
    local minDistance = tonumber(settings.minDistance) or 3.35
    local maxDistance = tonumber(settings.maxDistance) or 11.5
    local initialDistance = math.max(minDistance, math.min(maxDistance, tonumber(settings.defaultDistance) or distance or 6.2))
    local minPitch = tonumber(settings.minPitch) or -0.12
    local maxPitch = tonumber(settings.maxPitch) or 1.18
    pitch = math.max(minPitch, math.min(maxPitch, pitch))
    local yaw = atan2(dy, dx)
    UI.tuningCamera = {
        vehicle = getPedOccupiedVehicle(localPlayer),
        fallbackTarget = target,
        targetOffset = settings.targetOffset or camera.targetOffset or (CarConfig.TuningCamera and CarConfig.TuningCamera.targetOffset) or { x = 0, y = 0, z = 0.85 },
        yaw = yaw,
        pitch = pitch,
        distance = initialDistance,
        renderYaw = yaw,
        renderPitch = pitch,
        renderDistance = initialDistance,
        minDistance = minDistance,
        maxDistance = maxDistance,
        minPitch = minPitch,
        maxPitch = maxPitch,
        rotateSpeed = tonumber(settings.rotateSpeed) or 0.010,
        verticalSpeed = tonumber(settings.verticalSpeed) or 0.012,
        zoomStep = tonumber(settings.zoomStep) or 0.55,
        smoothing = tonumber(settings.smoothing) or 12,
        collisionPadding = tonumber(settings.collisionPadding) or 0.3,
        groundClearance = tonumber(settings.groundClearance) or 0.35,
        lastTick = getTickCount()
    }
end

local function currentTuningTarget(camera)
    local vehicle = camera.vehicle
    local offset = camera.targetOffset or { x = 0, y = 0, z = 0.85 }
    if isElement(vehicle) then
        local matrix = getElementMatrix(vehicle)
        if matrix then
            return {
                x = matrix[4][1] + (tonumber(offset.x) or 0) * matrix[1][1] + (tonumber(offset.y) or 0) * matrix[2][1] + (tonumber(offset.z) or 0.85) * matrix[3][1],
                y = matrix[4][2] + (tonumber(offset.x) or 0) * matrix[1][2] + (tonumber(offset.y) or 0) * matrix[2][2] + (tonumber(offset.z) or 0.85) * matrix[3][2],
                z = matrix[4][3] + (tonumber(offset.x) or 0) * matrix[1][3] + (tonumber(offset.y) or 0) * matrix[2][3] + (tonumber(offset.z) or 0.85) * matrix[3][3]
            }
        end
        local x, y, z = getElementPosition(vehicle)
        return { x = x, y = y, z = z + (tonumber(offset.z) or 0.85) }
    end
    return camera.fallbackTarget
end

local function shortestAngleDifference(target, current)
    return (target - current + math.pi) % (math.pi * 2) - math.pi
end

local function applyTuningCamera()
    local camera = UI.tuningCamera
    if UI.mode ~= "tuning" or not camera or type(setCameraMatrix) ~= "function" then return end
    local target = currentTuningTarget(camera)
    if not target then return end

    local now = getTickCount()
    local delta = math.min(0.1, math.max(0.001, (now - (camera.lastTick or now)) / 1000))
    camera.lastTick = now
    local alpha = 1 - math.exp(-(tonumber(camera.smoothing) or 12) * delta)
    camera.renderYaw = camera.renderYaw + shortestAngleDifference(camera.yaw, camera.renderYaw) * alpha
    camera.renderPitch = camera.renderPitch + (camera.pitch - camera.renderPitch) * alpha
    camera.renderDistance = camera.renderDistance + (camera.distance - camera.renderDistance) * alpha

    local horizontal = math.cos(camera.renderPitch) * camera.renderDistance
    local x = target.x + math.cos(camera.renderYaw) * horizontal
    local y = target.y + math.sin(camera.renderYaw) * horizontal
    local z = target.z + math.sin(camera.renderPitch) * camera.renderDistance

    if type(processLineOfSight) == "function" then
        local hit, hitX, hitY, hitZ = processLineOfSight(
            target.x, target.y, target.z, x, y, z,
            true, false, false, true, true, false, false, false, camera.vehicle
        )
        if hit then
            local hitDistance = getDistanceBetweenPoints3D(target.x, target.y, target.z, hitX, hitY, hitZ)
            local safeDistance = math.max((camera.minDistance or 3.35) * 0.55, hitDistance - (camera.collisionPadding or 0.3))
            local ratio = math.min(1, safeDistance / math.max(0.001, camera.renderDistance))
            x = target.x + (x - target.x) * ratio
            y = target.y + (y - target.y) * ratio
            z = target.z + (z - target.z) * ratio
        end
    end

    if type(getGroundPosition) == "function" then
        local ground = getGroundPosition(x, y, z + 2)
        if ground and z < ground + (camera.groundClearance or 0.35) then
            z = ground + (camera.groundClearance or 0.35)
        end
    end
    setCameraMatrix(x, y, z, target.x, target.y, target.z)
end

local function requestTuningPreview()
    if UI.mode ~= "tuning" then return end
    triggerServerEvent(CarConfig.events.previewTuning, localPlayer, UI.tuningSelected or {})
end

local function tuningTotalCost()
    local d = UI.data or {}
    local prices = d.prices or {}
    local total = 0
    for key in pairs(tuningTitles) do
        if not (key == "suspension" and d.suspensionAvailable == false) then
        local current = tonumber(d.levels and d.levels[key]) or 0
        local selected = getSelectedTuningLevel(key)
        if selected ~= current then
            total = total + (tonumber(prices[key] and prices[key][selected]) or 0)
        end
        end
    end
    return total
end

local function getTonerData()
    return (UI.data and UI.data.toner) or {}
end

local function getSelectedTonerPercent()
    local toner = getTonerData()
    return tonumber(UI.tonerSelected) or tonumber(toner.installed) or 0
end

local function getSelectedTonerZone(zone)
    local toner = getTonerData()
    local selected = type(UI.tonerSelected) == "table" and UI.tonerSelected or {}
    local zones = toner.zones or {}
    return tonumber(selected[zone]) or tonumber(zones[zone]) or 0
end

local function getSelectedTonerState()
    return {
        lob = getSelectedTonerZone("lob"),
        front = getSelectedTonerZone("front"),
        rear = getSelectedTonerZone("rear")
    }
end

local function tonerTotalCost()
    local toner = getTonerData()
    local zones = toner.zones or {}
    local changes = 0
    for _, zone in ipairs({"lob", "front", "rear"}) do
        if getSelectedTonerZone(zone) ~= (tonumber(zones[zone]) or 0) then
            changes = changes + 1
        end
    end
    return (tonumber(toner.price) or tonumber(CarConfig.tonerPrice) or 0) * changes
end

local function requestTonerPreview()
    local state = getSelectedTonerState()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle and type(applyVehicleToner) == "function" then
        applyVehicleToner(vehicle, state)
    end
    triggerServerEvent(CarConfig.events.previewToner, localPlayer, state)
end

local function restoreTonerOriginalPreview()
    if UI.mode ~= "tuning" or tostring(UI.data and UI.data.shopMode or "") ~= "toner" then return end
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle and type(applyVehicleToner) == "function" and type(UI.tonerOriginal) == "table" then
        applyVehicleToner(vehicle, UI.tonerOriginal)
    end
end

local function drawTuningSelector(key, title, x, y, w)
    local d = UI.data or {}
    local current = tonumber(d.levels and d.levels[key]) or 0
    if key == "suspension" and d.suspensionAvailable == false then
        button("unavailable:" .. key, title .. ": Недоступно", x, y, w, s(34), false)
        return
    end
    local selected = getSelectedTuningLevel(key)
    local label = string.format("%s: уровень %d", title, selected)

    local arrowW = s(44)
    button("tuneDec:" .. key, "<<", x, y, arrowW, s(34))
    button("tuneInc:" .. key, ">>", x + w - arrowW, y, arrowW, s(34))
    dxDrawRectangle(crisp(x + arrowW + s(8)), crisp(y), crisp(w - arrowW * 2 - s(16)), s(34), tocolor(0, 0, 0, 255))
    dxDrawRectangle(crisp(x + arrowW + s(8)) + 1, crisp(y) + 1, crisp(w - arrowW * 2 - s(16)) - 2, s(34) - 2, tocolor(14, 14, 14, 255))
    dxDrawText(label, x + arrowW + s(12), y, x + w - arrowW - s(12), y + s(34), rgba("text"), 1, "default-bold", "center", "center", true)
end

local function drawTuningSectionMenu(data)
    local w, h = s(360), s(286)
    local x = crisp(UI.screen[1] - w - s(34))
    local y = crisp((UI.screen[2] - h) / 2)
    UI.tuningPanel = { x = x, y = y, w = w, h = h }

    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawText("ТЮНИНГ-АТЕЛЬЕ", x + s(22), y + s(12), x + w - s(22), y + s(42), rgba("text"), 1, carMenuFont or "default-bold", "left", "center", true)
    dxDrawText(tostring(data.name or "Автомобиль"), x + s(22), y + s(58), x + w - s(22), y + s(82), rgba("muted"), 1, "default-bold", "left", "center", true)

    drawActions({
        {"section_performance", "Техническая часть"},
        {"section_toner", "Тонировка", false},
        {"tune_exit", "Выйти"}
    }, x + s(22), y + s(98), w - s(44))
end

local function drawTonerSelector(zone, title, x, y, w)
    local selected = getSelectedTonerZone(zone)
    local label = string.format("%s: %d%%", title, selected)
    local arrowW = s(44)
    button("tonerDec:" .. zone, "<<", x, y, arrowW, s(34))
    button("tonerInc:" .. zone, ">>", x + w - arrowW, y, arrowW, s(34))
    dxDrawRectangle(crisp(x + arrowW + s(8)), crisp(y), crisp(w - arrowW * 2 - s(16)), s(34), tocolor(0, 0, 0, 255))
    dxDrawRectangle(crisp(x + arrowW + s(8)) + 1, crisp(y) + 1, crisp(w - arrowW * 2 - s(16)) - 2, s(34) - 2, tocolor(14, 14, 14, 255))
    dxDrawText(label, x + arrowW + s(12), y, x + w - arrowW - s(12), y + s(34), rgba("text"), 1, "default-bold", "center", "center", true)
end

local function drawToner()
    local d = UI.data or {}
    local toner = getTonerData()
    local w, h = s(428), s(540)
    local x = crisp(UI.screen[1] - w - s(34))
    local y = crisp((UI.screen[2] - h) / 2)
    UI.tuningPanel = { x = x, y = y, w = w, h = h }

    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawText("ТОНИРОВКА", x + s(22), y + s(12), x + w - s(22), y + s(42), rgba("text"), 1, carMenuFont or "default-bold", "left", "center", true)
    dxDrawText(tostring(d.name or "Автомобиль"), x + s(22), y + s(58), x + w - s(22), y + s(82), rgba("muted"), 1, "default-bold", "left", "center", true)

    local yy = y + s(98)
    drawTonerSelector("lob", "Лобовое стекло", x + s(22), yy, w - s(44))
    yy = yy + s(42)
    drawTonerSelector("front", "Передние стекла", x + s(22), yy, w - s(44))
    yy = yy + s(42)
    drawTonerSelector("rear", "Задняя полусфера", x + s(22), yy, w - s(44))
    yy = yy + s(46)
    dxDrawText(string.format("Установлено: %d%%", tonumber(toner.installed) or 0), x + s(22), yy, x + w - s(22), yy + s(24), rgba("muted"), 1, "default-bold", "left", "center", true)
    yy = yy + s(28)
    dxDrawText("Стоимость: " .. CarConfig.formatMoney(tonerTotalCost()), x + s(22), yy, x + w - s(22), yy + s(24), rgba("primary"), 1, "default-bold", "left", "center", true)
    yy = yy + s(40)

    drawActions({
        {"toner_apply", "Применить тонировку"},
        {"section_menu", "Назад"},
        {"tune_exit", "Выйти"}
    }, x + s(22), yy, w - s(44))
end

local function drawTuning()
    local d = UI.data or {}
    local shopMode = tostring(d.shopMode or "performance")
    if shopMode == "menu" then
        drawTuningSectionMenu(d)
        return
    elseif shopMode == "toner" then
        drawToner()
        return
    end
    local w, h = s(428), s(418)
    local x = crisp(UI.screen[1] - w - s(34))
    local y = crisp((UI.screen[2] - h) / 2)
    UI.tuningPanel = { x = x, y = y, w = w, h = h }

    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawText("ТЮНИНГ", x + s(22), y + s(12), x + w - s(22), y + s(42), rgba("text"), 1, carMenuFont or "default-bold", "left", "center", true)
    dxDrawText(tostring(d.name or "Автомобиль"), x + s(22), y + s(58), x + w - s(22), y + s(82), rgba("muted"), 1, "default-bold", "left", "center", true)

    local yyNew = y + s(92)
    drawTuningSelector("suspension", "Подвеска", x + s(22), yyNew, w - s(44))
    drawTuningSelector("acceleration", "Ускорение", x + s(22), yyNew + s(42), w - s(44))
    drawTuningSelector("max_speed", "Макс. скорость", x + s(22), yyNew + s(84), w - s(44))
    dxDrawText("Стоимость: " .. CarConfig.formatMoney(tuningTotalCost()), x + s(22), yyNew + s(136), x + w - s(22), yyNew + s(160), rgba("primary"), 1, "default-bold", "left", "center", true)
    drawActions({ {"tune_apply", "Применить изменения"} }, x + s(22), yyNew + s(174), w - s(44))

    drawActions({
        {"section_menu", "Назад"},
        {"tune_exit", "Выйти"}
    }, x + s(22), yyNew + s(222), w - s(44))
end
local function drawTuningHint()
    local w, h = s(484), s(62)
    local x, y = s(34), UI.screen[2] - h - s(34)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawText("Зажмите #4FC3F7ЛКМ#FFFFFF и двигайте мышь - вращение камеры", x + s(14), y + s(8), x + w - s(14), y + s(32), rgba("text"), 1.05, "default-bold", "left", "center", true, false, false, true)
    dxDrawText("#4FC3F7Колесо мыши#FFFFFF - приближение", x + s(14), y + s(31), x + w - s(14), y + s(55), rgba("text"), 1.05, "default-bold", "left", "center", true, false, false, true)
    do return end
    dxDrawText("Зажмите ЛКМ и двигайте мышь - вращение камеры", x + s(14), y + s(6), x + w - s(14), y + s(28), rgba("text"), 1, "default", "left", "center", true)
    dxDrawText("Колесо мыши - приближение", x + s(14), y + s(27), x + w - s(14), y + s(49), rgba("muted"), 1, "default", "left", "center", true)
end

local function render()
    UI.hitboxes = {}
    if UI.mode == "tuning" then applyTuningCamera() end
    if UI.mode == "dealership" then drawDealership()
    elseif UI.mode == "confirm_purchase" then drawConfirmPurchase()
    elseif UI.mode == "used_market" then drawUsedMarket()
    elseif UI.mode == "confirm_state" then drawConfirmState()
    elseif UI.mode == "sell_player" then drawSellPlayer()
    elseif UI.mode == "offer" then drawOffer()
    elseif UI.mode == "tuning" then drawTuning(); drawTuningHint()
    end
end
addEventHandler("onClientRender", root, render)

addEvent(CarConfig.events.openDealership, true)
addEventHandler(CarConfig.events.openDealership, resourceRoot, function(dealershipId, vehicleId, data)
    data = data or {}
    data.dealershipId = dealershipId
    data.vehicleId = vehicleId
    if not open("dealership", data) then
        triggerServerEvent(CarConfig.events.cancelDealership, localPlayer)
    end
end)

addEvent(CarConfig.events.closeDealership, true)
addEventHandler(CarConfig.events.closeDealership, resourceRoot, close)

addEvent(CarConfig.events.resetCamera, true)
addEventHandler(CarConfig.events.resetCamera, resourceRoot, function()
    if type(setCameraTarget) == "function" then setCameraTarget(localPlayer) end
end)

addEvent(CarConfig.events.playLockSound, true)
addEventHandler(CarConfig.events.playLockSound, resourceRoot, function(vehicle)
    local sound
    if isElement(vehicle) then
        local x, y, z = getElementPosition(vehicle)
        sound = playSound3D("siqnald.mp3", x, y, z, false)
        if sound then setSoundMaxDistance(sound, 22) end
    else
        sound = playSound("siqnald.mp3", false)
    end
    if sound then setSoundVolume(sound, 0.8) end
end)

addEvent(CarConfig.events.setControlsEnabled, true)
addEventHandler(CarConfig.events.setControlsEnabled, resourceRoot, function(enabled)
    setControlsEnabled(enabled)
end)

addEvent(CarConfig.events.beginAnimatedExit, true)
addEventHandler(CarConfig.events.beginAnimatedExit, resourceRoot, beginAnimatedExit)

addEvent(CarConfig.events.forceExitVehicle, true)
addEventHandler(CarConfig.events.forceExitVehicle, resourceRoot, function()
    if not isPedInVehicle(localPlayer) then return end
    toggleControl("enter_exit", true)
    setPedControlState("enter_exit", true)
    setTimer(function()
        setPedControlState("enter_exit", false)
    end, 180, 1)
end)

addEventHandler("onClientVehicleExit", root, function(player)
    if player == localPlayer and animatedExitActive then
        completeAnimatedExit()
    end
end)

addEvent(CarConfig.events.openUsedMarket, true)
addEventHandler(CarConfig.events.openUsedMarket, resourceRoot, function(data)
    open("used_market", data or {})
end)

addEvent(CarConfig.events.openTuning, true)
addEventHandler(CarConfig.events.openTuning, resourceRoot, function(data)
    data = data or {}
    UI.tuningSelected = {
        suspension = tonumber(data.levels and data.levels.suspension) or 0,
        acceleration = tonumber(data.levels and data.levels.acceleration) or 0,
        max_speed = tonumber(data.levels and data.levels.max_speed) or 0
    }
    local tonerZones = data.toner and data.toner.zones or {}
    UI.tonerSelected = {
        lob = tonumber(tonerZones.lob) or 0,
        front = tonumber(tonerZones.front) or 0,
        rear = tonumber(tonerZones.rear) or 0
    }
    UI.tonerOriginal = {
        lob = UI.tonerSelected.lob,
        front = UI.tonerSelected.front,
        rear = UI.tonerSelected.rear
    }
    setupTuningCamera(data)
    open("tuning", data or {})
    applyTuningCamera()
end)

addEvent(CarConfig.events.setTuningCamera, true)
addEventHandler(CarConfig.events.setTuningCamera, resourceRoot, function(camera)
    if type(camera) ~= "table" then return end
    setupTuningCamera({
        camera = camera,
        cameraTarget = camera.target,
        cameraSettings = camera
    })
    applyTuningCamera()
end)

addEvent(CarConfig.events.receiveOffer, true)
addEventHandler(CarConfig.events.receiveOffer, resourceRoot, function(offerId, data)
    UI.offer = data or {}
    UI.offer.id = offerId
    open("offer", {})
end)

function getLookedVehicle()
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    if not cx or not lx then return false end
    local dx, dy, dz = lx - cx, ly - cy, lz - cz
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length <= 0 then return false end
    local distance = tonumber(CarConfig.lockAimDistance) or 12
    local ex, ey, ez = cx + dx / length * distance, cy + dy / length * distance, cz + dz / length * distance
    local hit, hitX, hitY, hitZ, element = processLineOfSight(cx, cy, cz, ex, ey, ez, true, true, false, true, false, false, false, false, localPlayer)
    if hit and isElement(element) and getElementType(element) == "vehicle" then
        return element
    end
    local bestVehicle, bestScore
    local playerInterior = getElementInterior(localPlayer)
    local playerDimension = getElementDimension(localPlayer)
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        if getElementInterior(vehicle) == playerInterior
            and getElementDimension(vehicle) == playerDimension then
            local vx, vy, vz = getElementPosition(vehicle)
            local tx, ty, tz = vx - cx, vy - cy, (vz + 0.7) - cz
            local targetLength = math.sqrt(tx * tx + ty * ty + tz * tz)
            if targetLength > 0.01 and targetLength <= distance then
                local dot = (dx / length) * (tx / targetLength) + (dy / length) * (ty / targetLength) + (dz / length) * (tz / targetLength)
                local side = math.sqrt(math.max(0, 1 - dot * dot)) * targetLength
                if dot > 0.88 and side <= 4.0 then
                    local score = dot * 100 - targetLength
                    if not bestScore or score > bestScore then
                        bestVehicle, bestScore = vehicle, score
                    end
                end
            end
        end
    end
    if bestVehicle then return bestVehicle end
    return false
end

local function handleVehicleControlKey(keyName, sourceName)
    local ready = keyName == "n" and CarInteraction.canToggleLock(localPlayer)
        or (keyName ~= "n" and CarInteraction.ready(localPlayer))
    if not ready then return false end
    if keyName == "n" then
        outputDebugString("[RP CAR CLIENT] N pressed", 3)
    end
    local now = getTickCount()
    local debounceDelay = keyName == "n" and 650 or 250
    if keyDebounce[keyName] and now - keyDebounce[keyName] < debounceDelay then return false end
    keyDebounce[keyName] = now

    local label = keyName == "2" and "2" or string.upper(keyName)
    debugKey(keyName == "n" and "N pressed" or ("Key " .. label .. " pressed"))
    if keyName == "n" then
        local anyOpen, textActive, activeName = getCoreUIState()
        debugKey("Any UI open: " .. tostring(anyOpen))
        debugKey("Text input active: " .. tostring(textActive))
        debugKey("Active UI name: " .. tostring(activeName))
    end
    local blocked = isInputBlocked()
    debugKey("Blocked by UI: " .. (blocked and "YES" or "NO"))
    if blocked then return false end

    if keyName == "2" then
        debugKey("Vehicle found: " .. (getPedOccupiedVehicle(localPlayer) and "YES" or "NO"))
        triggerServerEvent(CarConfig.events.toggleEngine, localPlayer)
        return true
    elseif keyName == "l" then
        debugKey("Vehicle found: " .. (getPedOccupiedVehicle(localPlayer) and "YES" or "NO"))
        triggerServerEvent(CarConfig.events.toggleLights, localPlayer)
        return true
    elseif keyName == "b" then
        debugKey("Vehicle found: " .. (getPedOccupiedVehicle(localPlayer) and "YES" or "NO"))
        triggerServerEvent(CarConfig.events.toggleHandbrake, localPlayer)
        return true
    elseif keyName == "n" then
        local vehicle = getLookedVehicle()
        debugKey("Target vehicle found: " .. (vehicle and "YES" or "NO"))
        if vehicle then
            local px, py, pz = getElementPosition(localPlayer)
            local vx, vy, vz = getElementPosition(vehicle)
            debugKey("Distance: " .. string.format("%.2f", getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)))
            triggerServerEvent(CarConfig.events.toggleLock, localPlayer, vehicle)
            debugKey("Lock event sent: YES")
            return true
        end
        -- The server can find the nearest owned car when camera aim misses.
        triggerServerEvent(CarConfig.events.toggleLock, localPlayer)
        debugKey("Lock event sent: YES (server target lookup)")
        return true
    end

    return false
end

local function bindVehicleKeys()
    bindKey("2", "down", function() handleVehicleControlKey("2", "bind") end)
    bindKey("n", "down", function()
        outputDebugString("[RP CAR CLIENT] N pressed", 3)
        handleVehicleControlKey("n", "bind")
    end)
    bindKey("l", "down", function() handleVehicleControlKey("l", "bind") end)
    bindKey("b", "down", function() handleVehicleControlKey("b", "bind") end)
end

addEventHandler("onClientClick", root, function(buttonName, state, cx, cy)
    if buttonName ~= "left" or state ~= "down" or not UI.mode then return end
    for id, box in pairs(UI.hitboxes) do
        if inBox(cx, cy, box) then
            if box.field then UI.input = box.field; return end
            if id == "cancel" then
                debugLog("cancel clicked in mode " .. tostring(UI.mode))
                if UI.mode == "dealership" or UI.mode == "confirm_purchase" then triggerServerEvent(CarConfig.events.cancelDealership, localPlayer) end
                close()
            elseif id == "buy" then
                debugLog("buy clicked, opening confirmation")
                open("confirm_purchase", UI.data)
            elseif id == "buy_confirm" then
                debugLog("buy confirm clicked: dealership=" .. tostring(UI.data.dealershipId) .. ", vehicle=" .. tostring(UI.data.vehicleId))
                triggerServerEvent(CarConfig.events.buyVehicleRequest, localPlayer, UI.data.dealershipId, UI.data.vehicleId)
            elseif id == "back_dealership" then
                open("dealership", UI.data)
            elseif id == "state_confirm" then
                open("confirm_state", UI.data)
            elseif id == "state_sell" then
                debugLog("sell state clicked")
                triggerServerEvent(CarConfig.events.sellStateVehicle, localPlayer)
                close()
            elseif id == "sell_player" then
                UI.fields = {}
                open("sell_player", UI.data)
            elseif id == "back_market" then
                open("used_market", UI.data)
            elseif id == "offer_player" then
                triggerServerEvent(CarConfig.events.offerVehicle, localPlayer, tonumber(UI.fields.target), tonumber(UI.fields.price))
                close()
            elseif id == "section_performance" then
                triggerServerEvent(CarConfig.events.tuningSection, localPlayer, "performance")
            elseif id == "section_toner" then
                triggerServerEvent(CarConfig.events.tuningSection, localPlayer, "toner")
            elseif id == "section_menu" then
                restoreTonerOriginalPreview()
                triggerServerEvent(CarConfig.events.tuningSection, localPlayer, "menu")
            elseif id:sub(1, 9) == "tonerDec:" then
                local zone = id:match("^tonerDec:(.+)$") or "rear"
                local toner = getTonerData()
                local step = tonumber(toner.step) or 10
                UI.tonerSelected = type(UI.tonerSelected) == "table" and UI.tonerSelected or getSelectedTonerState()
                UI.tonerSelected[zone] = math.max(tonumber(toner.min) or 0, getSelectedTonerZone(zone) - step)
                requestTonerPreview()
            elseif id:sub(1, 9) == "tonerInc:" then
                local zone = id:match("^tonerInc:(.+)$") or "rear"
                local toner = getTonerData()
                local step = tonumber(toner.step) or 10
                UI.tonerSelected = type(UI.tonerSelected) == "table" and UI.tonerSelected or getSelectedTonerState()
                UI.tonerSelected[zone] = math.min(tonumber(toner.max) or 100, getSelectedTonerZone(zone) + step)
                requestTonerPreview()
            elseif id:sub(1, 8) == "tuneDec:" then
                local key = id:sub(9)
                if key == "suspension" and UI.data and UI.data.suspensionAvailable == false then return end
                UI.tuningSelected = UI.tuningSelected or {}
                local selected = getSelectedTuningLevel(key)
                UI.tuningSelected[key] = math.max(0, selected - 1)
                requestTuningPreview()
            elseif id:sub(1, 8) == "tuneInc:" then
                local key = id:sub(9)
                if key == "suspension" and UI.data and UI.data.suspensionAvailable == false then return end
                UI.tuningSelected = UI.tuningSelected or {}
                local selected = getSelectedTuningLevel(key)
                local maxLevel = tonumber(UI.data.maxLevel) or 3
                UI.tuningSelected[key] = math.min(maxLevel, selected + 1)
                requestTuningPreview()
            elseif id == "tune_apply" then
                triggerServerEvent(CarConfig.events.tuningAction, localPlayer, UI.tuningSelected or {})
            elseif id == "toner_apply" then
                triggerServerEvent(CarConfig.events.tonerAction, localPlayer, getSelectedTonerState())
            elseif id == "tune_exit" then
                restoreTonerOriginalPreview()
                triggerServerEvent(CarConfig.events.exitTuning, localPlayer)
                close()
            elseif id == "offer_accept" then
                triggerServerEvent(CarConfig.events.answerOffer, localPlayer, UI.offer and UI.offer.id, true)
                close()
            elseif id == "offer_decline" then
                triggerServerEvent(CarConfig.events.answerOffer, localPlayer, UI.offer and UI.offer.id, false)
                close()
            end
            return
        end
    end
    UI.input = nil
end)

addEventHandler("onClientCursorMove", root, function(_, _, absoluteX, absoluteY)
    if UI.mode ~= "tuning" or not UI.tuningCamera then return end
    if not getKeyState("mouse1") then
        UI.tuningDrag = nil
        return
    end
    local panelBox = UI.tuningPanel
    if panelBox and inBox(absoluteX, absoluteY, panelBox) then
        UI.tuningDrag = nil
        return
    end
    if UI.tuningDrag then
        local dx = absoluteX - UI.tuningDrag.x
        local dy = absoluteY - UI.tuningDrag.y
        UI.tuningCamera.yaw = UI.tuningCamera.yaw - dx * (UI.tuningCamera.rotateSpeed or 0.010)
        UI.tuningCamera.yaw = (UI.tuningCamera.yaw + math.pi) % (math.pi * 2) - math.pi
        UI.tuningCamera.pitch = math.max(
            UI.tuningCamera.minPitch or -0.12,
            math.min(UI.tuningCamera.maxPitch or 1.18, UI.tuningCamera.pitch - dy * (UI.tuningCamera.verticalSpeed or 0.009))
        )
    end
    UI.tuningDrag = { x = absoluteX, y = absoluteY }
end)

addEventHandler("onClientCharacter", root, function(char)
    if not UI.mode or not UI.input then return end
    local text = UI.fields[UI.input] or ""
    if #text >= 16 then return end
    if UI.input == "target" or UI.input == "price" then
        if not tostring(char):match("%d") then return end
    end
    UI.fields[UI.input] = text .. char
end)

addEventHandler("onClientKey", root, function(key, press)
    if not press then return end
    if key == "n" then
        outputDebugString("[RP CAR CLIENT] N pressed", 3)
    end

    if not UI.mode then
        if key == "2" or key == "l" or key == "n" or key == "b" then
            if handleVehicleControlKey(key, "key") then cancelEvent() end
            if key == "2" and not isInputBlocked() then cancelEvent() end
            return
        end
        return
    end

    if key == "2" or key == "l" or key == "n" or key == "b" then
        debugKey(key == "n" and "N pressed" or ("Key " .. string.upper(key) .. " pressed"))
        if key == "n" then
            local anyOpen, textActive, activeName = getCoreUIState()
            debugKey("Any UI open: " .. tostring(anyOpen))
            debugKey("Text input active: " .. tostring(textActive))
            debugKey("Active UI name: " .. tostring(activeName))
        end
        debugKey("Blocked by UI: YES")
        if key == "2" then
            cancelEvent()
        end
        return
    end

    if UI.mode == "tuning" and (key == "mouse_wheel_up" or key == "mouse_wheel_down") and UI.tuningCamera then
        local step = tonumber(UI.tuningCamera.zoomStep) or 0.55
        if key == "mouse_wheel_up" then
            UI.tuningCamera.distance = math.max(UI.tuningCamera.minDistance or 4.0, UI.tuningCamera.distance - step)
        else
            UI.tuningCamera.distance = math.min(UI.tuningCamera.maxDistance or 9.0, UI.tuningCamera.distance + step)
        end
        cancelEvent()
        return
    end

    if key == "backspace" and UI.input then
        local text = UI.fields[UI.input] or ""
        UI.fields[UI.input] = text:sub(1, math.max(0, #text - 1))
        cancelEvent()
    elseif key == "escape" then
        debugLog("escape in mode " .. tostring(UI.mode))
        if UI.mode == "dealership" or UI.mode == "confirm_purchase" then
            triggerServerEvent(CarConfig.events.cancelDealership, localPlayer)
        elseif UI.mode == "tuning" then
            triggerServerEvent(CarConfig.events.exitTuning, localPlayer)
        end
        close()
        cancelEvent()
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    animatedExitActive = false
    setPedControlState("enter_exit", false)
    setControlsEnabled(true)
    close()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    carMenuFont = dxCreateFont(":rp_core/CompactC.ttf", s(14), false, "cleartype")
    bindVehicleKeys()
end)
