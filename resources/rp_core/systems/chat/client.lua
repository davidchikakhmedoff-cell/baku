RPChatClient = {
    messages = {},
    scroll = 0,
    inputActive = false,
    inputText = "",
    inputCursor = 0,
    inputOffset = 0,
    selectionStart = nil,
    visible = ChatConfig.settings.visible,
    loggedIn = false,
    renderAttached = false,
    ignoreNextCharacter = false,
    cursorEnabled = false,
    history = {},
    historyIndex = nil,
    cursorBlinkTick = 0,
    pendingFallback = nil,
    settings = {
        scale = ChatConfig.settings.scale,
        width = ChatConfig.settings.width,
        visibleLines = ChatConfig.settings.visibleLines
    }
}

local CHAT_UI_NAME = "chat"
local CHAT_HISTORY_LIMIT = 50
local CURSOR_BLINK_INTERVAL = 500
local CHAT_INPUT_MODE = "no_binds"
local insertText
local fallbackSerial = 0

local function s(value)
    return DXUtils.s(value)
end

local function layout()
    local screenW, screenH = guiGetScreenSize()
    local scale = RPChatClient.settings.scale or 1
    local width = s(RPChatClient.settings.width) * scale
    local lineHeight = s(ChatConfig.layout.lineHeight) * scale
    local visibleLines = RPChatClient.settings.visibleLines
    local inputHeight = s(ChatConfig.layout.inputHeight) * scale
    local x = s(ChatConfig.layout.x)
    local y = s(ChatConfig.layout.y)
    return {
        x = x,
        y = y,
        width = width,
        lineHeight = lineHeight,
        visibleLines = visibleLines,
        inputHeight = inputHeight,
        font = ChatConfig.layout.font,
        fontScale = (ChatConfig.layout.messageFontScale or ChatConfig.layout.fontScale) * scale
    }
end

local function colorFrom(rgb, alpha)
    return tocolor(rgb[1], rgb[2], rgb[3], alpha or 255)
end

local function clientTime()
    local rt = getRealTime()
    return string.format("[%02d:%02d]", rt.hour, rt.minute)
end

local function withTime(text)
    text = tostring(text or "")
    if text:match("^%[%d%d:%d%d%]") then return text end
    return clientTime() .. " " .. text
end

local function drawOutlinedText(text, left, top, right, bottom, color, scale, font, alignX, alignY, clip, wordBreak)
    local outline = colorFrom(ChatConfig.layout.outlineColor, ChatConfig.layout.outlineAlpha)
    local outlineSize = math.max(0, math.floor(tonumber(ChatConfig.layout.outlineSize) or 1))
    for ox = -outlineSize, outlineSize do
        for oy = -outlineSize, outlineSize do
            if ox ~= 0 or oy ~= 0 then
                dxDrawText(text, left + ox, top + oy, right + ox, bottom + oy, outline, scale, font, alignX, alignY, clip or false, wordBreak or false, false, false, false)
            end
        end
    end
    dxDrawText(text, left, top, right, bottom, color, scale, font, alignX, alignY, clip or false, wordBreak or false, false, false, false)
end

local function parseColorCodedSegments(text, defaultColor)
    text = tostring(text or "")
    local segments = {}
    local currentColor = defaultColor
    local buffer = ""
    local i = 1

    while i <= #text do
        local code = text:sub(i, i + 6)
        if code:match("^#%x%x%x%x%x%x$") then
            if buffer ~= "" then
                segments[#segments + 1] = { text = buffer, color = currentColor }
                buffer = ""
            end
            currentColor = {
                tonumber(code:sub(2, 3), 16) or 255,
                tonumber(code:sub(4, 5), 16) or 255,
                tonumber(code:sub(6, 7), 16) or 255
            }
            i = i + 7
        else
            buffer = buffer .. text:sub(i, i)
            i = i + 1
        end
    end

    if buffer ~= "" then
        segments[#segments + 1] = { text = buffer, color = currentColor }
    end
    return segments
end

local function drawSegmentedOutlinedText(text, left, top, right, bottom, defaultRgb, alpha, scale, font)
    local x = math.floor(left + 0.5)
    local segments = parseColorCodedSegments(text, defaultRgb)
    local outline = colorFrom(ChatConfig.layout.outlineColor, ChatConfig.layout.outlineAlpha)
    local outlineSize = math.max(0, math.floor(tonumber(ChatConfig.layout.outlineSize) or 1))
    for _, segment in ipairs(segments) do
        local part = segment.text
        local rgb = segment.color or defaultRgb
        for ox = -outlineSize, outlineSize do
            for oy = -outlineSize, outlineSize do
                if ox ~= 0 or oy ~= 0 then
                    dxDrawText(part, x + ox, top + oy, right + ox, bottom + oy, outline, scale, font, "left", "top", false, false, false, false, false)
                end
            end
        end
        dxDrawText(part, x, top, right, bottom, tocolor(rgb[1], rgb[2], rgb[3], alpha or 255), scale, font, "left", "top", false, false, false, false, false)
        x = x + dxGetTextWidth(part, scale, font)
    end
end

local cp1251Reverse = {
    [0x0402] = 0x80, [0x0403] = 0x81, [0x201A] = 0x82, [0x0453] = 0x83,
    [0x201E] = 0x84, [0x2026] = 0x85, [0x2020] = 0x86, [0x2021] = 0x87,
    [0x20AC] = 0x88, [0x2030] = 0x89, [0x0409] = 0x8A, [0x2039] = 0x8B,
    [0x040A] = 0x8C, [0x040C] = 0x8D, [0x040B] = 0x8E, [0x040F] = 0x8F,
    [0x0452] = 0x90, [0x2018] = 0x91, [0x2019] = 0x92, [0x201C] = 0x93,
    [0x201D] = 0x94, [0x2022] = 0x95, [0x2013] = 0x96, [0x2014] = 0x97,
    [0x0098] = 0x98,
    [0x2122] = 0x99, [0x0459] = 0x9A, [0x203A] = 0x9B, [0x045A] = 0x9C,
    [0x045C] = 0x9D, [0x045B] = 0x9E, [0x045F] = 0x9F, [0x00A0] = 0xA0,
    [0x040E] = 0xA1, [0x045E] = 0xA2, [0x0408] = 0xA3, [0x00A4] = 0xA4,
    [0x0490] = 0xA5, [0x00A6] = 0xA6, [0x00A7] = 0xA7, [0x0401] = 0xA8,
    [0x00A9] = 0xA9, [0x0404] = 0xAA, [0x00AB] = 0xAB, [0x00AC] = 0xAC,
    [0x00AD] = 0xAD, [0x00AE] = 0xAE, [0x0407] = 0xAF, [0x00B0] = 0xB0,
    [0x00B1] = 0xB1, [0x0406] = 0xB2, [0x0456] = 0xB3, [0x0491] = 0xB4,
    [0x00B5] = 0xB5, [0x00B6] = 0xB6, [0x00B7] = 0xB7, [0x0451] = 0xB8,
    [0x2116] = 0xB9, [0x0454] = 0xBA, [0x00BB] = 0xBB, [0x0458] = 0xBC,
    [0x0405] = 0xBD, [0x0455] = 0xBE, [0x0457] = 0xBF
}

local function utf8Codepoints(text)
    local points, i = {}, 1
    text = tostring(text or "")
    while i <= #text do
        local b1 = text:byte(i)
        if not b1 then break end
        if b1 < 0x80 then
            points[#points + 1] = b1
            i = i + 1
        elseif b1 < 0xC0 then
            return false
        elseif b1 < 0xE0 then
            local b2 = text:byte(i + 1)
            if not b2 or b2 < 0x80 or b2 > 0xBF then return false end
            points[#points + 1] = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
            i = i + 2
        elseif b1 < 0xF0 then
            local b2, b3 = text:byte(i + 1), text:byte(i + 2)
            if not b2 or not b3 or b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF then return false end
            points[#points + 1] = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
            i = i + 3
        else
            local b2, b3, b4 = text:byte(i + 1), text:byte(i + 2), text:byte(i + 3)
            if not b2 or not b3 or not b4
                or b2 < 0x80 or b2 > 0xBF
                or b3 < 0x80 or b3 > 0xBF
                or b4 < 0x80 or b4 > 0xBF then return false end
            points[#points + 1] = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
            i = i + 4
        end
    end
    return points
end

local function isValidUtf8(text)
    return utf8Codepoints(text) ~= false
end

local function hasCyrillic(text)
    local points = utf8Codepoints(text)
    if not points then return false end
    for _, cp in ipairs(points) do
        if cp >= 0x0400 and cp <= 0x04FF then return true end
    end
    return false
end

local function cp1251Byte(cp)
    if cp < 0x80 then return cp end
    if cp >= 0x0410 and cp <= 0x044F then return cp - 0x0410 + 0xC0 end
    return cp1251Reverse[cp]
end

local function repairMojibakeOnce(text)
    local points = utf8Codepoints(text)
    if not points then return false end
    local bytes = {}
    for _, cp in ipairs(points) do
        local byte = cp1251Byte(cp)
        if not byte then return false end
        bytes[#bytes + 1] = string.char(byte)
    end
    local repaired = table.concat(bytes)
    if repaired ~= text and isValidUtf8(repaired) and hasCyrillic(repaired) then
        return repaired
    end
    return false
end

local function normalizeChatText(text)
    text = tostring(text or "")
    for _ = 1, 3 do
        local repaired = repairMojibakeOnce(text)
        if not repaired then break end
        text = repaired
    end
    return text
end

function RPChatClient.normalizeText(text)
    return normalizeChatText(text)
end

local function canUseChat()
    if RPUIManager and not RPUIManager.canOpen(CHAT_UI_NAME) then return false end
    if AuthUI and AuthUI.visible then return false end
    if AdminPanel and AdminPanel.visible then return false end
    return RPChatClient.loggedIn == true or getElementData(localPlayer, "auth:loggedIn") == true
end

local function maxScroll()
    return math.max(0, #RPChatClient.messages - RPChatClient.settings.visibleLines)
end

local function clampScroll()
    RPChatClient.scroll = math.max(0, math.min(RPChatClient.scroll, maxScroll()))
end

function RPChatClient.addMessage(payload)
    if type(payload) ~= "table" then return end

    local wasAtBottom = RPChatClient.scroll == 0

    RPChatClient.messages[#RPChatClient.messages + 1] = {
        text = withTime(normalizeChatText(payload.text)),
        color = payload.color or ChatConfig.colors.normal,
        type = payload.type or "normal"
    }

    while #RPChatClient.messages > ChatConfig.maxChatMessages do
        table.remove(RPChatClient.messages, 1)
    end

    if wasAtBottom then
        RPChatClient.scroll = 0
    else
        clampScroll()
    end
end

-- Native outputChatBox messages (SMS, /f and model-loader diagnostics) must
-- reach the DX chat too: the standard GTA chat is hidden by this resource.
function RPChatClient.receiveNativeMessage(text,r,g,b)
    cancelEvent()
    RPChatClient.addMessage({type="native",text=tostring(text or ""),color={r or 255,g or 255,b or 255}})
end
addEventHandler("onClientChatMessage",root,RPChatClient.receiveNativeMessage)

function RPChatClient.setVisible(state)
    RPChatClient.visible = state and true or false
end

function RPChatClient.toggleVisible()
    RPChatClient.setVisible(not RPChatClient.visible)
end


local blockedControls = {
    "forwards",
    "backwards",
    "left",
    "right",
    "jump",
    "sprint",
    "fire",
    "aim_weapon",
    "next_weapon",
    "previous_weapon"
}

local function lockChatControls(state)
    for _, control in ipairs(blockedControls) do
        toggleControl(control, not state)
    end
end

local function resetCursorBlink()
    RPChatClient.cursorBlinkTick = getTickCount()
end

local function ensureInputFocus()
    if not RPChatClient.inputActive then return end
    guiSetInputMode(CHAT_INPUT_MODE)
    if RPChatClient.cursorEnabled then
        showCursor(true)
    end
end

local function clearPendingFallback()
    RPChatClient.pendingFallback = nil
end

local function addHistory(text)
    text = trim(text)
    if text == "" then return end

    RPChatClient.history[#RPChatClient.history + 1] = text
    while #RPChatClient.history > CHAT_HISTORY_LIMIT do
        table.remove(RPChatClient.history, 1)
    end
end

local function setInputText(text)
    RPChatClient.inputText = tostring(text or "")
    RPChatClient.inputCursor = #RPChatClient.inputText
    RPChatClient.inputOffset = 0
    RPChatClient.selectionStart = nil
    -- ensure existing text fits the visible input area; if not, trim from the end
    local cfg = layout()
    local prefix = "Say: "
    local padding = s(6)
    local avail = cfg.width - padding * 2
    while dxGetTextWidth(prefix .. RPChatClient.inputText, cfg.fontScale, cfg.font) > avail and #RPChatClient.inputText > 0 do
        RPChatClient.inputText = RPChatClient.inputText:sub(1, -2)
        RPChatClient.inputCursor = math.min(RPChatClient.inputCursor, #RPChatClient.inputText)
    end
    resetCursorBlink()
end

local function utf8PreviousIndex(text, index)
    index = math.max(0, math.min(#text, tonumber(index) or 0))
    if index <= 0 then return 0 end

    local pos = index
    while pos > 0 do
        local byte = text:byte(pos)
        if not byte or byte < 128 or byte >= 192 then
            return pos - 1
        end
        pos = pos - 1
    end

    return 0
end

local function printableKey(button)
    if type(button) ~= "string" then return nil end
    if button == "space" then return " " end
    if button == "num_div" or button == "slash" or button == "/" then return "/" end
    if button == "num_mul" then return "*" end
    if button == "num_add" then return "+" end
    if button == "num_sub" then return "-" end
    if button == "num_dec" then return "." end

    local digit = button:match("^num_(%d)$")
    if digit then return digit end

    if #button == 1 and button:match("[%w%p]") then
        if button:match("%a") and (getKeyState("lshift") or getKeyState("rshift")) then
            return button:upper()
        end
        return button
    end

    return nil
end

local function schedulePrintableFallback(button)
    local char = printableKey(button)
    if not char or getKeyState("lctrl") or getKeyState("rctrl") then
        clearPendingFallback()
        return
    end

    fallbackSerial = fallbackSerial + 1
    local token = fallbackSerial
    RPChatClient.pendingFallback = token
    setTimer(function()
        if RPChatClient.inputActive and RPChatClient.pendingFallback == token then
            insertText(char)
            clearPendingFallback()
        end
    end, 50, 1)
end

local function navigateHistory(direction)
    if #RPChatClient.history == 0 then return end

    local lastIndex = #RPChatClient.history
    local index = RPChatClient.historyIndex or (lastIndex + 1)

    index = index + direction
    if index < 1 then index = 1 end

    if index > lastIndex then
        RPChatClient.historyIndex = nil
        setInputText("")
        return
    end

    RPChatClient.historyIndex = index
    setInputText(RPChatClient.history[index])
end

function RPChatClient.openInput(prefix)
    if not canUseChat() then return end
    if RPUIManager and not RPUIManager.acquire(CHAT_UI_NAME, { cursor = true, inputMode = CHAT_INPUT_MODE }) then return end

    RPChatClient.inputActive = true
    RPChatClient.inputText = prefix or ""
    RPChatClient.inputCursor = #RPChatClient.inputText
    RPChatClient.selectionStart = nil
    RPChatClient.historyIndex = nil
    resetCursorBlink()

    -- Ignore the key that opened the chat (for example T)
    RPChatClient.ignoreNextCharacter = true

    lockChatControls(true)
    RPChatClient.cursorEnabled = true
    ensureInputFocus()
end

function RPChatClient.closeInput(send)
    if not RPChatClient.inputActive then return end

    local text = RPChatClient.inputText

    RPChatClient.inputActive = false
    RPChatClient.inputText = ""
    RPChatClient.inputCursor = 0
    RPChatClient.selectionStart = nil
    RPChatClient.ignoreNextCharacter = false
    RPChatClient.historyIndex = nil

    lockChatControls(false)

    if RPChatClient.cursorEnabled then
        if RPUIManager then RPUIManager.release(CHAT_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
        RPChatClient.cursorEnabled = false
    end

    if send and trim(text) ~= "" then
        addHistory(text)
    end

    if send then
        local ttrim = trim(text)
        if ChatConfig.autoCommands and ChatConfig.autoCommands[ttrim] then
            triggerServerEvent("chat:send", localPlayer, ChatConfig.autoCommands[ttrim])
            return
        end
    end

    if send and RPChatClient.handleLocalCommand(text) then
        return
    end

    if send and trim(text) ~= "" then
        triggerServerEvent("chat:send", localPlayer, text)
    end
end


local function getSelection()
    if not RPChatClient.selectionStart then return nil end
    local a = RPChatClient.selectionStart
    local b = RPChatClient.inputCursor
    if a > b then a, b = b, a end
    return a, b
end

local function deleteSelection()
    local a, b = getSelection()
    if not a then return false end

    RPChatClient.inputText = RPChatClient.inputText:sub(1, a) .. RPChatClient.inputText:sub(b + 1)
    RPChatClient.inputCursor = a
    RPChatClient.selectionStart = nil
    resetCursorBlink()
    return true
end

insertText = function(value)
    value = tostring(value or "")
    deleteSelection()

    local cfg = layout()
    local prefix = "Say: "
    local padding = s(6)
    local avail = cfg.width - padding * 2
    local fontScale = cfg.fontScale
    local font = cfg.font

    local left = RPChatClient.inputText:sub(1, RPChatClient.inputCursor)
    local right = RPChatClient.inputText:sub(RPChatClient.inputCursor + 1)

    -- try to append whole value, otherwise trim until it fits
    local attempt = left .. value .. right
    local full = prefix .. attempt
    while #value > 0 and dxGetTextWidth(full, fontScale, font) > avail do
        -- trim last character from value
        value = value:sub(1, -2)
        attempt = left .. value .. right
        full = prefix .. attempt
    end

    if #value == 0 then return end

    RPChatClient.inputText = attempt
    RPChatClient.inputCursor = #left + #value
    RPChatClient.historyIndex = nil
    resetCursorBlink()
end

function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function splitArgs(value)
    local parts = {}
    for part in tostring(value or ""):gmatch("%S+") do
        parts[#parts + 1] = part
    end
    return parts
end

function RPChatClient.handleLocalCommand(text)
    text = trim(text)
    local args = text:match("^/chatsize%s*(.*)$")
    if not args then return false end

    local parts = splitArgs(args)
    local scale = tonumber(parts[1])
    local lines = tonumber(parts[2])
    local width = tonumber(parts[3])

    if parts[1] == "small" then
        scale, lines, width = 0.9, 8, 440
    elseif parts[1] == "normal" or parts[1] == "" or not parts[1] then
        scale, lines, width = ChatConfig.settings.scale, ChatConfig.settings.visibleLines, ChatConfig.settings.width
    elseif parts[1] == "large" then
        scale, lines, width = 1.1, 12, 620
    end

    RPChatClient.settings.scale = math.max(0.8, math.min(1.25, scale or RPChatClient.settings.scale))
    RPChatClient.settings.visibleLines = math.max(ChatConfig.minVisibleLines, math.min(ChatConfig.maxVisibleLines, math.floor(lines or RPChatClient.settings.visibleLines)))
    RPChatClient.settings.width = math.max(ChatConfig.minChatWidth, math.min(ChatConfig.maxChatWidth, math.floor(width or RPChatClient.settings.width)))
    clampScroll()

    RPChatClient.addMessage({
        type = "system",
        text = "Размер чата изменён.",
        color = ChatConfig.colors.system
    })
    return true
end


local function dxDrawRoundedRectangle(x, y, w, h, radius, color)
    dxDrawRectangle(x + radius, y, w - radius * 2, h, color)
    dxDrawRectangle(x, y + radius, w, h - radius * 2, color)

    dxDrawCircle(x + radius, y + radius, radius, 180, 270, color)
    dxDrawCircle(x + w - radius, y + radius, radius, 270, 360, color)
    dxDrawCircle(x + radius, y + h - radius, radius, 90, 180, color)
    dxDrawCircle(x + w - radius, y + h - radius, radius, 0, 90, color)
end

local function scrollChat(direction)
    if direction > 0 then
        RPChatClient.scroll = math.min(maxScroll(), RPChatClient.scroll + ChatConfig.scrollSpeed)
    elseif direction < 0 then
        RPChatClient.scroll = math.max(0, RPChatClient.scroll - ChatConfig.scrollSpeed)
    end
end

function RPChatClient.render()
    if not RPChatClient.visible or not canUseChat() then return end

    local cfg = layout()
    local startIndex = math.max(1, #RPChatClient.messages - RPChatClient.settings.visibleLines - RPChatClient.scroll + 1)
    local endIndex = math.min(#RPChatClient.messages, startIndex + cfg.visibleLines - 1)

    local visibleCount = math.max(0, endIndex - startIndex + 1)
    local bottomOffset = math.max(0, cfg.visibleLines - visibleCount)

    for index = startIndex, endIndex do
        local message = RPChatClient.messages[index]
        if message then
            local row = bottomOffset + index - startIndex
            local top = cfg.y + row * cfg.lineHeight
            local bottom = top + cfg.lineHeight
            -- draw full single-line message without wrapping; allow it to overflow horizontally
            local textWidth = dxGetTextWidth(tostring(message.text or ""), cfg.fontScale, cfg.font)
            local rightBound = cfg.x + math.max(cfg.width, textWidth)
            drawSegmentedOutlinedText(message.text, cfg.x, top, rightBound, bottom, message.color or ChatConfig.colors.normal, 255, cfg.fontScale, cfg.font)
        end
    end

    if RPChatClient.inputActive then
        local inputTop = cfg.y + cfg.visibleLines * cfg.lineHeight + s(6)
        local inputBottom = inputTop + cfg.inputHeight

        dxDrawRoundedRectangle(
            cfg.x - s(4),
            inputTop,
            cfg.width + s(8),
            cfg.inputHeight,
            s(9),
            tocolor(0, 0, 0, 255)
        )

                local prefix = "Say: "
        local textInside = RPChatClient.inputText or ""
        local fullText = prefix .. textInside
        local fontScale = cfg.fontScale
        local font = cfg.font
        local padding = s(6)
        local visibleLeft = cfg.x + padding
        local visibleRight = cfg.x + cfg.width - padding

        local prefixWidth = dxGetTextWidth(prefix, fontScale, font)
        local beforeCursorText = textInside:sub(1, RPChatClient.inputCursor)
        local beforeCursorWidth = dxGetTextWidth(beforeCursorText, fontScale, font)

        local offset = RPChatClient.inputOffset or 0
        local cursorX = cfg.x + padding + prefixWidth + beforeCursorWidth - offset

        local totalTextWidth = dxGetTextWidth(fullText, fontScale, font)
        local visibleWidth = cfg.width - padding * 2

        -- adjust offset so cursor is visible
        if cursorX < visibleLeft then
            offset = math.max(0, offset - (visibleLeft - cursorX))
        elseif cursorX > visibleRight then
            offset = math.max(0, offset + (cursorX - visibleRight))
        end

        -- clamp offset
        local maxOffset = math.max(0, totalTextWidth - visibleWidth)
        if offset > maxOffset then offset = maxOffset end
        RPChatClient.inputOffset = offset

        local selA, selB = getSelection()
        if selA then
            local startWidth = dxGetTextWidth(textInside:sub(1, selA), fontScale, font)
            local selectedWidth = dxGetTextWidth(textInside:sub(selA + 1, selB), fontScale, font)
            local selectX = cfg.x + padding + prefixWidth + startWidth - offset
            local clippedX = math.max(selectX, visibleLeft)
            local clippedW = math.max(0, math.min(selectX + selectedWidth, visibleRight) - clippedX)
            if clippedW > 0 then
                dxDrawRectangle(clippedX, inputTop + s(5), clippedW, cfg.inputHeight - s(10), tocolor(79, 195, 247, 115))
            end
        end

        -- draw text shifted by offset, clipped to input area
        dxDrawText(
            fullText,
            cfg.x + padding - offset,
            inputTop,
            cfg.x + cfg.width - padding - offset,
            inputBottom,
            colorFrom(ChatConfig.colors.normal),
            fontScale,
            font,
            "left",
            "center",
            true,
            false,
            false,
            false,
            false
        )

        -- recompute cursorX after clamping offset
        cursorX = cfg.x + padding + prefixWidth + beforeCursorWidth - RPChatClient.inputOffset

        if (getTickCount() - RPChatClient.cursorBlinkTick) % (CURSOR_BLINK_INTERVAL * 2) < CURSOR_BLINK_INTERVAL then
            dxDrawLine(
                cursorX,
                inputTop + s(5),
                cursorX,
                inputBottom - s(5),
                tocolor(255,255,255,220),
                1
            )
        end
    end
end

local function attachRender()
    if RPChatClient.renderAttached then return end
    addEventHandler("onClientRender", root, RPChatClient.render)
    RPChatClient.renderAttached = true
end

local function detachRender()
    if not RPChatClient.renderAttached then return end
    removeEventHandler("onClientRender", root, RPChatClient.render)
    RPChatClient.renderAttached = false
end

addEvent("chat:receive", true)
addEventHandler("chat:receive", resourceRoot, function(payload)
    RPChatClient.addMessage(payload)
end)

addEvent("chat:clear", true)
addEventHandler("chat:clear", resourceRoot, function()
    RPChatClient.messages = {}
    RPChatClient.scroll = 0
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    showChat(false)
    attachRender()
    triggerServerEvent("chat:clientReady", localPlayer)
end)

addEvent("auth:spawned", true)
addEventHandler("auth:spawned", resourceRoot, function()
    RPChatClient.loggedIn = true
    RPChatClient.visible = true
    showChat(false)
end)

addEvent("auth:loggedOut", true)
addEventHandler("auth:loggedOut", resourceRoot, function()
    RPChatClient.loggedIn = false
    RPChatClient.inputActive = false
    RPChatClient.messages = {}
    RPChatClient.historyIndex = nil
    RPChatClient.cursorEnabled = false
    lockChatControls(false)
    if RPUIManager then RPUIManager.release(CHAT_UI_NAME) else guiSetInputMode("allow_binds") end
end)

addEventHandler("onClientKey", root, function(button, press)
    if RPChatClient.inputActive then
        ensureInputFocus()
    end

    if not press then return end

    if string.lower(button) == string.lower(ChatConfig.inputKey) then
        if not RPChatClient.inputActive and canUseChat() then
            cancelEvent()
            RPChatClient.openInput("")
            return
        end
    end

    if string.lower(button) == string.lower(ChatConfig.toggleKey) then
        if canUseChat() then
            RPChatClient.toggleVisible()
        end
        return
    end

    if RPChatClient.visible and RPChatClient.inputActive then
        if button == "mouse_wheel_up" then
            scrollChat(1)
            cancelEvent()
            return
        elseif button == "mouse_wheel_down" then
            scrollChat(-1)
            cancelEvent()
            return
        end

        if button == "escape" then
            cancelEvent()
            RPChatClient.closeInput(false)
            return
        end

        if button == "enter" then
            cancelEvent()
            RPChatClient.closeInput(true)
            return
        end

        if button == "backspace" then
            cancelEvent()
            if not deleteSelection() and RPChatClient.inputCursor > 0 then
                local previous = utf8PreviousIndex(RPChatClient.inputText, RPChatClient.inputCursor)
                RPChatClient.inputText = RPChatClient.inputText:sub(1, previous) .. RPChatClient.inputText:sub(RPChatClient.inputCursor + 1)
                RPChatClient.inputCursor = previous
                RPChatClient.historyIndex = nil
                resetCursorBlink()
            end
            return
        end

        if button == "delete" then
            cancelEvent()
            if not deleteSelection() then
                RPChatClient.inputText = RPChatClient.inputText:sub(1, RPChatClient.inputCursor) .. RPChatClient.inputText:sub(RPChatClient.inputCursor + 2)
                RPChatClient.historyIndex = nil
                resetCursorBlink()
            end
            return
        end

        local ctrl = getKeyState("lctrl") or getKeyState("rctrl")
        local shift = getKeyState("lshift") or getKeyState("rshift")

        local function moveInputCursor(position)
            if shift and not RPChatClient.selectionStart then
                RPChatClient.selectionStart = RPChatClient.inputCursor
            end
            RPChatClient.inputCursor = math.max(0, math.min(#RPChatClient.inputText, position))
            if not shift then RPChatClient.selectionStart = nil end
            resetCursorBlink()
        end

        if ctrl and button == "a" then
            cancelEvent()
            RPChatClient.selectionStart = 0
            RPChatClient.inputCursor = #RPChatClient.inputText
            return
        end

        if ctrl and button == "c" then
            cancelEvent()
            local a,b=getSelection()
            if a then setClipboard(RPChatClient.inputText:sub(a+1,b)) end
            return
        end

        if ctrl and button == "x" then
            cancelEvent()
            local a,b=getSelection()
            if a then
                setClipboard(RPChatClient.inputText:sub(a+1,b))
                deleteSelection()
            end
            return
        end

        if ctrl and button == "v" then
            cancelEvent()
            insertText(getClipboard())
            return
        end

        if button == "arrow_l" then
            cancelEvent()
            moveInputCursor(RPChatClient.inputCursor - 1)
            return
        end

        if button == "arrow_r" then
            cancelEvent()
            moveInputCursor(RPChatClient.inputCursor + 1)
            return
        end

        if button == "arrow_u" then
            cancelEvent()
            navigateHistory(-1)
            return
        end

        if button == "arrow_d" then
            cancelEvent()
            navigateHistory(1)
            return
        end

        if button == "home" then
            cancelEvent()
            moveInputCursor(0)
            RPChatClient.inputOffset = 0
            return
        end

        if button == "end" then
            cancelEvent()
            moveInputCursor(#RPChatClient.inputText)
            RPChatClient.inputOffset = 0
            return
        end

        schedulePrintableFallback(button)
        return
    end

    if not canUseChat() or not (RPChatClient.visible and RPChatClient.inputActive) then return end

    if button == "mouse_wheel_up" then
        scrollChat(1)
        cancelEvent()
    elseif button == "mouse_wheel_down" then
        scrollChat(-1)
        cancelEvent()
    elseif button == "num_add" then
        RPChatClient.settings.visibleLines = math.min(ChatConfig.maxVisibleLines, RPChatClient.settings.visibleLines + ChatConfig.resizeStep)
        cancelEvent()
    elseif button == "num_sub" then
        RPChatClient.settings.visibleLines = math.max(ChatConfig.minVisibleLines, RPChatClient.settings.visibleLines - ChatConfig.resizeStep)
        clampScroll()
        cancelEvent()
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if not RPChatClient.inputActive then return end
    ensureInputFocus()
    clearPendingFallback()

    if RPChatClient.ignoreNextCharacter then
        RPChatClient.ignoreNextCharacter = false
        return
    end

    insertText(char)
end)

addEventHandler("onClientPaste", root, function(text)
    if not RPChatClient.inputActive then return end
    ensureInputFocus()
    text = tostring(text or ""):gsub("[\r\n]", "")
    insertText(text)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    detachRender()
    if RPChatClient.inputActive then
        if RPUIManager then RPUIManager.release(CHAT_UI_NAME) else guiSetInputMode("allow_binds") end
        RPChatClient.cursorEnabled = false
        lockChatControls(false)
    end
    showChat(true)
end)
