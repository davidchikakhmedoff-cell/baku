RPNotificationsClient = RPNotificationsClient or {
    items = {},
    hudSuppressed = false
}

local function s(value)
    return DXUtils and DXUtils.s(value) or value
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function withoutColorCodes(text)
    return tostring(text or ""):gsub("#%x%x%x%x%x%x", "")
end

local function priceNumber(text, prefix)
    local number = text:match(prefix and "^%$%d+" or "^%d+")
    if not number then return nil end
    while true do
        local tail = text:sub(#number + 1)
        local group = tail:match("^[ ,]%d%d%d")
        if not group or tail:sub(#group + 1, #group + 1):match("%d") then break end
        number = number .. group
    end
    local fraction = text:sub(#number + 1):match("^[.,]%d+")
    if fraction then number = number .. fraction end
    return number
end

local function applyHighlights(text)
    text = tostring(text or "")
    local result, index = {}, 1
    while index <= #text do
        local code = text:sub(index, index + 6)
        if code:match("^#%x%x%x%x%x%x$") then
            result[#result + 1] = code
            index = index + 7
        else
            -- Match original text once. Never rescan inserted #23B1F5: its
            -- last digit followed by $ used to be mistaken for another price.
            local tail = text:sub(index)
            local token = priceNumber(tail, true)
            if not token then
                local number = priceNumber(tail, false)
                local suffix = number and tail:sub(#number + 1):match("^ *%$")
                if suffix then token = number .. suffix end
            end
            token = token or tail:match("^/[%w_]+")
            if token then
                result[#result + 1] = "#23B1F5" .. token .. "#FFFFFF"
                index = index + #token
            else
                result[#result + 1] = text:sub(index, index)
                index = index + 1
            end
        end
    end
    return table.concat(result)
end

local function stripTrailingDots(text)
    local suffix = ""
    while tostring(text):match("#%x%x%x%x%x%x$") do
        local code = text:sub(-7)
        suffix = code .. suffix
        text = text:sub(1, -8)
    end
    return text:gsub("%.+%s*$", "") .. suffix
end

local function contentWidth(text, scale, font)
    local widest = 0
    for line in (withoutColorCodes(text) .. "\n"):gmatch("(.-)\n") do
        widest = math.max(widest, dxGetTextWidth(line, scale, font))
    end
    return widest
end

local function setNotificationHudSuppressed(suppressed)
    suppressed = suppressed == true
    if RPNotificationsClient.hudSuppressed == suppressed then return end
    RPNotificationsClient.hudSuppressed = suppressed

    triggerEvent("rp:hud:setNotificationSuppressed", root, suppressed)
end

local function lastColorCode(text, fallback)
    local result = fallback or "#FFFFFF"
    for code in tostring(text or ""):gmatch("#%x%x%x%x%x%x") do
        result = code
    end
    return result
end

local function wrapText(text, width, scale, font)
    local lines = {}
    local activeColor = "#FFFFFF"

    for paragraph in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        if paragraph == "" then
            lines[#lines + 1] = activeColor
        else
            local current = ""
            for word in paragraph:gmatch("%S+") do
                local candidate = current == "" and (activeColor .. word) or (current .. " " .. word)
                if current ~= "" and dxGetTextWidth(withoutColorCodes(candidate), scale, font) > width then
                    lines[#lines + 1] = current
                    activeColor = lastColorCode(current, activeColor)
                    current = activeColor .. word
                else
                    current = candidate
                end
                activeColor = lastColorCode(current, activeColor)
            end
            lines[#lines + 1] = current ~= "" and current or activeColor
        end
    end

    if #lines == 0 then lines[1] = activeColor end
    return lines
end

local function drawColorCodedLine(text, x, y, right, height, scale, font)
    local cursorX = x
    local color = {255, 255, 255}
    local buffer = ""
    local index = 1

    local function drawBuffer()
        if buffer == "" then return end
        dxDrawText(buffer, cursorX, y, right, y + height, tocolor(color[1], color[2], color[3], 255), scale, font, "left", "top", false, false, false, false, false)
        cursorX = cursorX + dxGetTextWidth(buffer, scale, font)
        buffer = ""
    end

    while index <= #text do
        local code = text:sub(index, index + 6)
        if code:match("^#%x%x%x%x%x%x$") then
            drawBuffer()
            color = {
                tonumber(code:sub(2, 3), 16) or 255,
                tonumber(code:sub(4, 5), 16) or 255,
                tonumber(code:sub(6, 7), 16) or 255
            }
            index = index + 7
        else
            buffer = buffer .. text:sub(index, index)
            index = index + 1
        end
    end
    drawBuffer()
end

local function addNotification(text, r, g, b, duration)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if RPChatClient and type(RPChatClient.normalizeText) == "function" then
        text = RPChatClient.normalizeText(text)
    end
    text = stripTrailingDots(text)
    if text == "" then return false end
    text = applyHighlights(text)

    local now = getTickCount()
    local last = RPNotificationsClient.items[1]
    if last and last.text == text and now - last.createdAt < 900 then
        last.expiresAt = now + (tonumber(duration) or NotificationConfig.duration)
        return true
    end

    table.insert(RPNotificationsClient.items, 1, {
        text = text,
        color = {
            tonumber(r) or NotificationConfig.colors.info[1],
            tonumber(g) or NotificationConfig.colors.info[2],
            tonumber(b) or NotificationConfig.colors.info[3]
        },
        createdAt = now,
        expiresAt = now + (tonumber(duration) or NotificationConfig.duration)
    })

    while #RPNotificationsClient.items > NotificationConfig.maxVisible do
        table.remove(RPNotificationsClient.items)
    end
    if type(playSoundFrontEnd) == "function" then
        playSoundFrontEnd(11)
    end
    return true
end

function showCoreNotification(text, r, g, b, duration)
    return addNotification(text, r, g, b, duration)
end

addEvent("notifications:push", true)
addEventHandler("notifications:push", resourceRoot, function(payload)
    payload = type(payload) == "table" and payload or {}
    local color = type(payload.color) == "table" and payload.color or NotificationConfig.colors.info
    addNotification(payload.text, color[1], color[2], color[3], payload.duration)
end)

addEventHandler("onClientRender", root, function()
    local items = RPNotificationsClient.items
    local now = getTickCount()

    for index = #items, 1, -1 do
        if now >= items[index].expiresAt then
            table.remove(items, index)
        end
    end

    setNotificationHudSuppressed(#items > 0)
    if #items == 0 then return end

    local screenW = guiGetScreenSize()
    local font = ChatConfig and ChatConfig.layout.font or "default-bold"
    local fontScale = ChatConfig and ChatConfig.layout.fontScale or 1
    local paddingX = s(NotificationConfig.paddingX)
    local paddingY = s(NotificationConfig.paddingY)
    local lineHeight = s(NotificationConfig.lineHeight)
    local offset = s(NotificationConfig.offset)
    local y = offset

    for _, item in ipairs(items) do
        local width = clamp(
            math.ceil(contentWidth(item.text, fontScale, font) + paddingX * 2),
            s(NotificationConfig.minWidth),
            s(NotificationConfig.maxWidth)
        )
        local textWidth = width - paddingX * 2
        local x = math.floor(screenW - offset - width + 0.5)
        local lines = wrapText("#FFFFFF" .. item.text, textWidth, fontScale, font)
        local height = math.max(s(NotificationConfig.minHeight), paddingY * 2 + #lines * lineHeight)
        local outer = NotificationConfig.background.outer
        local inner = NotificationConfig.background.inner

        dxDrawRectangle(x, y, width, height, tocolor(outer[1], outer[2], outer[3], outer[4]))
        dxDrawRectangle(x + 1, y + 1, width - 2, height - 2, tocolor(inner[1], inner[2], inner[3], inner[4]))

        for lineIndex, line in ipairs(lines) do
            local lineY = y + paddingY + (lineIndex - 1) * lineHeight
            drawColorCodedLine(line, x + paddingX, lineY, x + width - paddingX, lineHeight, fontScale, font)
        end
        y = y + height + s(NotificationConfig.gap)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setNotificationHudSuppressed(false)
end)
