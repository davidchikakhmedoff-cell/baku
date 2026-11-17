DXUtils = {}
RPUIManager = RPUIManager or {
    active = nil,
    cursorOwners = {},
    inputModeOwners = {}
}

local screenW, screenH = guiGetScreenSize()
local scaleX, scaleY = screenW / AuthConfig.design.width, screenH / AuthConfig.design.height
local scale = math.min(scaleX, scaleY)

function DXUtils.screen()
    return screenW, screenH, scale
end

function DXUtils.s(value)
    return math.floor(value * scale + 0.5)
end

function DXUtils.color(rgb, alpha)
    return tocolor(rgb[1], rgb[2], rgb[3], alpha or 255)
end

function DXUtils.lerp(from, to, progress)
    return from + (to - from) * math.max(0, math.min(1, progress))
end

function DXUtils.inBox(x, y, width, height)
    local cursorX, cursorY = getCursorPosition()
    if not cursorX then return false end

    cursorX, cursorY = cursorX * screenW, cursorY * screenH
    return cursorX >= x and cursorX <= x + width and cursorY >= y and cursorY <= y + height
end

function DXUtils.roundedRect(x, y, width, height, radius, color)
    radius = math.min(radius, width / 2, height / 2)
    dxDrawRectangle(x + radius, y, width - radius * 2, height, color)
    dxDrawRectangle(x, y + radius, radius, height - radius * 2, color)
    dxDrawRectangle(x + width - radius, y + radius, radius, height - radius * 2, color)
    dxDrawCircle(x + radius, y + radius, radius, 180, 270, color, color, 16)
    dxDrawCircle(x + width - radius, y + radius, radius, 270, 360, color, color, 16)
    dxDrawCircle(x + radius, y + height - radius, radius, 90, 180, color, color, 16)
    dxDrawCircle(x + width - radius, y + height - radius, radius, 0, 90, color, color, 16)
end

function DXUtils.shadow(x, y, width, height, radius, alpha)
    for i = 5, 1, -1 do
        DXUtils.roundedRect(x - i * 2, y - i * 2, width + i * 4, height + i * 4, radius + i * 2, tocolor(0, 0, 0, (alpha or 70) / i))
    end
end

function DXUtils.setRadarVisible(visible)
    if type(setPlayerHudComponentVisible) == "function" then
        setPlayerHudComponentVisible("radar", visible and true or false)
    end
end

function RPUIManager.canOpen(name)
    return not RPUIManager.active or RPUIManager.active == name
end

function RPUIManager.acquire(name, options)
    if not RPUIManager.canOpen(name) then return false, RPUIManager.active end

    RPUIManager.active = name
    options = options or {}

    if options.cursor then
        RPUIManager.cursorOwners[name] = true
        showCursor(true)
    end

    if options.inputMode then
        RPUIManager.inputModeOwners[name] = options.inputMode
        guiSetInputMode(options.inputMode)
    end

    return true
end

function RPUIManager.release(name)
    if RPUIManager.active == name then
        RPUIManager.active = nil
    end

    RPUIManager.cursorOwners[name] = nil
    RPUIManager.inputModeOwners[name] = nil

    local hasCursorOwner = false
    for _ in pairs(RPUIManager.cursorOwners) do
        hasCursorOwner = true
        break
    end
    showCursor(hasCursorOwner)

    local inputMode = "allow_binds"
    for _, mode in pairs(RPUIManager.inputModeOwners) do
        inputMode = mode
        break
    end
    guiSetInputMode(inputMode)
end

function RPUIManager.isActive(name)
    return RPUIManager.active == name
end

function RPUIManager.isAnyBlockingOpen()
    if RPUIManager.active and not RPUIManager.cursorOwners[RPUIManager.active] and not RPUIManager.inputModeOwners[RPUIManager.active] then
        RPUIManager.active = nil
    end
    return RPUIManager.active ~= nil
end

function RPUIManager.isTextInputActive()
    if DXInput and DXInput.active then return true end
    if isChatBoxInputActive and isChatBoxInputActive() then return true end
    if isConsoleActive and isConsoleActive() then return true end
    if isMainMenuActive and isMainMenuActive() then return true end
    if isMTAWindowActive and isMTAWindowActive() then return true end
    return false
end

function canOpenUI(name)
    return RPUIManager.canOpen(name)
end

function openUI(name, cursor, inputMode)
    return RPUIManager.acquire(name, { cursor = cursor == true, inputMode = inputMode })
end

function closeUI(name)
    RPUIManager.release(name)
    return true
end

function isAnyBlockingUIOpen()
    return RPUIManager.isAnyBlockingOpen()
end

function isTextInputActive()
    return RPUIManager.isTextInputActive()
end

function getActiveUIName()
    return RPUIManager.active
end
