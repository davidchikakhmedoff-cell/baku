DXInput = {}
DXInput.__index = DXInput
DXInput.active = nil

local modifierKeys = {
    lshift = true, rshift = true,
    lctrl = true, rctrl = true,
    lalt = true, ralt = true,
    lwin = true, rwin = true,
    tab = true
}

local function utf8Length(text)
    if utf8 and utf8.len then
        return utf8.len(text or "") or #(text or "")
    end
    return #(text or "")
end

local function utf8Sub(text, from, to)
    text = tostring(text or "")
    if utf8 and utf8.sub then
        return utf8.sub(text, from, to) or ""
    end
    return text:sub(from, to)
end

local function utf8Limit(text, limit)
    text = tostring(text or "")
    if utf8Length(text) <= limit then return text end
    if utf8 and utf8.sub then
        return utf8.sub(text, 1, limit) or text:sub(1, limit)
    end
    return text:sub(1, limit)
end

function DXInput:new(placeholder, password, maxLength)
    return setmetatable({
        placeholder = placeholder,
        password = password,
        maxLength = maxLength or 32,
        text = "",
        caret = 0,
        focus = 0,
        selectionStart = 0,
        selectionEnd = 0,
        mouseSelecting = false,
        dragAnchor = 0,
        lastLayout = nil
    }, self)
end

function DXInput:isModifierKey(button)
    return modifierKeys[button] == true
end

function DXInput:isSystemShortcutKey(button)
    if self:isModifierKey(button) then return true end
    if button == "space" and (getKeyState("lwin") or getKeyState("rwin")) then return true end
    if (button == "lshift" or button == "rshift") and (getKeyState("lalt") or getKeyState("ralt") or getKeyState("lctrl") or getKeyState("rctrl")) then return true end
    return false
end

function DXInput:hasSelection()
    return self.selectionStart ~= self.selectionEnd
end

function DXInput:selectionBounds()
    return math.min(self.selectionStart, self.selectionEnd), math.max(self.selectionStart, self.selectionEnd)
end

function DXInput:clearSelection()
    self.selectionStart = self.caret
    self.selectionEnd = self.caret
end

function DXInput:deleteSelection()
    if not self:hasSelection() then return false end
    local a, b = self:selectionBounds()
    self.text = utf8Sub(self.text, 1, a) .. utf8Sub(self.text, b + 1)
    self.caret = a
    self:clearSelection()
    return true
end

function DXInput:insertText(text)
    text = tostring(text or "")
    if text == "" then return false end
    self:deleteSelection()
    local left = utf8Sub(self.text, 1, self.caret)
    local right = utf8Sub(self.text, self.caret + 1)
    local allowed = self.maxLength - utf8Length(self.text)
    if allowed <= 0 then return false end
    local insert = utf8Limit(text, allowed)
    self.text = left .. insert .. right
    self.caret = self.caret + utf8Length(insert)
    self:clearSelection()
    return true
end

function DXInput:displayText()
    local length = utf8Length(self.text)
    return self.password and string.rep("*", length) or self.text
end

function DXInput:caretFromX(px)
    local layout = self.lastLayout
    if not layout then return utf8Length(self.text) end
    local display = self:displayText()
    local length = utf8Length(display)
    if px <= layout.textX then return 0 end
    for i = 1, length do
        local part = utf8Sub(display, 1, i)
        local charX = layout.textX + dxGetTextWidth(part, layout.scale, layout.font)
        if px < charX then
            local prev = layout.textX + dxGetTextWidth(utf8Sub(display, 1, i - 1), layout.scale, layout.font)
            return (px - prev) < (charX - px) and i - 1 or i
        end
    end
    return length
end

function DXInput:setCaret(pos, keepSelection)
    local length = utf8Length(self.text)
    self.caret = math.max(0, math.min(length, tonumber(pos) or length))
    if keepSelection then
        self.selectionEnd = self.caret
    else
        self:clearSelection()
    end
end

function DXInput:setText(text)
    self.text = utf8Limit(text, self.maxLength)
    self.caret = utf8Length(self.text)
    self:clearSelection()
end

function DXInput:getText()
    return self.text
end

function DXInput:activate()
    if DXInput.active and DXInput.active ~= self then
        DXInput.active:clearSelection()
    end
    DXInput.active = self
    self:setCaret(self.caret or utf8Length(self.text))
    guiSetInputMode("no_binds_when_editing")
end

function DXInput:blur()
    if DXInput.active == self then DXInput.active = nil end
    self.mouseSelecting = false
    self:clearSelection()
end

function DXInput:draw(x, y, w, h, alpha, icon)
    local active = DXInput.active == self
    self.focus = DXUtils.lerp(self.focus, active and 1 or 0, 0.14)

    local panel, primary, muted, textColor = AuthConfig.colors.panel, AuthConfig.colors.primary, AuthConfig.colors.muted, AuthConfig.colors.text
    local hover = DXUtils.inBox(x, y, w, h) and 1 or 0
    local bgAlpha = (118 + self.focus * 36 + hover * 14) * alpha / 255
    DXUtils.roundedRect(x, y, w, h, DXUtils.s(8), tocolor(panel[1], panel[2], panel[3], bgAlpha))
    dxDrawRectangle(x + DXUtils.s(14), y + h - DXUtils.s(1), w - DXUtils.s(28), DXUtils.s(1), tocolor(255, 255, 255, 30 * alpha / 255))

    if self.focus > 0.02 then
        dxDrawRectangle(x + DXUtils.s(14), y + h - DXUtils.s(2), w - DXUtils.s(28), DXUtils.s(2), tocolor(primary[1], primary[2], primary[3], alpha * self.focus))
    end

    dxDrawText(icon or "", x + DXUtils.s(16), y, x + DXUtils.s(44), y + h, tocolor(primary[1], primary[2], primary[3], 215 * alpha / 255), 0.92, "default-bold", "center", "center")

    local length = utf8Length(self.text)
    local display = self:displayText()
    local hasText = self.text ~= ""
    local shown = hasText and display or self.placeholder
    local color = hasText and textColor or muted
    local textX = x + DXUtils.s(52)
    local textRight = x + w - DXUtils.s(16)
    local scale = 1.02
    local font = "default"
    self.lastLayout = { textX = textX, textRight = textRight, scale = scale, font = font }

    if active and hasText and self:hasSelection() then
        local a, b = self:selectionBounds()
        local leftWidth = dxGetTextWidth(utf8Sub(display, 1, a), scale, font)
        local selectedWidth = dxGetTextWidth(utf8Sub(display, a + 1, b), scale, font)
        local sx = math.min(textX + leftWidth, textRight)
        local sw = math.max(1, math.min(selectedWidth, textRight - sx))
        dxDrawRectangle(sx, y + DXUtils.s(11), sw, h - DXUtils.s(22), tocolor(primary[1], primary[2], primary[3], 115 * alpha / 255))
    end

    dxDrawText(shown, textX, y, textRight, y + h, tocolor(color[1], color[2], color[3], alpha), scale, font, "left", "center", true)

    if active and (getTickCount() % 1000) < 520 then
        local textWidth = hasText and dxGetTextWidth(utf8Sub(display, 1, self.caret), scale, font) or 0
        local cursorX = math.min(textX + textWidth, textRight)
        dxDrawRectangle(cursorX, y + DXUtils.s(16), 1, h - DXUtils.s(32), tocolor(255, 255, 255, alpha))
    end
end

function DXInput:click(x, y, ix, iy, iw, ih)
    if x >= ix and x <= ix + iw and y >= iy and y <= iy + ih then
        self:activate()
        local pos = self:caretFromX(x)
        self.dragAnchor = pos
        self.selectionStart = pos
        self.selectionEnd = pos
        self.mouseSelecting = true
        self:setCaret(pos)
        return true
    end
    if DXInput.active == self then self:blur() end
    return false
end

function DXInput:key(button, press)
    if not press or DXInput.active ~= self then return false end

    if self:isSystemShortcutKey(button) then
        return false
    end

    local ctrl = getKeyState("lctrl") or getKeyState("rctrl")
    local shift = getKeyState("lshift") or getKeyState("rshift")
    local length = utf8Length(self.text)

    local function moveCaret(pos)
        if shift and not self:hasSelection() then self.selectionStart = self.caret end
        self:setCaret(pos, shift)
    end

    if ctrl then
        if button == "a" then self.selectionStart = 0; self.selectionEnd = length; self.caret = length; return true end
        if button == "c" then
            if self:hasSelection() then
                local a, b = self:selectionBounds()
                setClipboard(utf8Sub(self.text, a + 1, b))
            end
            return true
        end
        if button == "x" then
            if self:hasSelection() then
                local a, b = self:selectionBounds()
                setClipboard(utf8Sub(self.text, a + 1, b))
                self:deleteSelection()
            end
            return true
        end
        if button == "v" then return false end
    end

    if button == "backspace" then
        if not self:deleteSelection() and self.caret > 0 then
            self.text = utf8Sub(self.text, 1, self.caret - 1) .. utf8Sub(self.text, self.caret + 1)
            self:setCaret(self.caret - 1)
        end
        return true
    end

    if button == "delete" then
        if not self:deleteSelection() and self.caret < length then
            self.text = utf8Sub(self.text, 1, self.caret) .. utf8Sub(self.text, self.caret + 2)
            self:setCaret(self.caret)
        end
        return true
    end

    if button == "arrow_l" then
        moveCaret(self.caret - 1)
        return true
    end

    if button == "arrow_r" then
        moveCaret(self.caret + 1)
        return true
    end

    if button == "home" then
        moveCaret(0)
        return true
    end

    if button == "end" then
        moveCaret(length)
        return true
    end

    return false
end

function DXInput:char(char)
    if DXInput.active ~= self then return false end
    return self:insertText(char)
end

function DXInput:paste(text)
    if DXInput.active ~= self or not text then return false end
    return self:insertText(text)
end

addEventHandler("onClientCursorMove", root, function(_, _, x)
    local input = DXInput.active
    if not input or not input.mouseSelecting then return end
    input.caret = input:caretFromX(x)
    input.selectionStart = input.dragAnchor or input.caret
    input.selectionEnd = input.caret
end)

addEventHandler("onClientClick", root, function(button, state)
    if button == "left" and state == "up" and DXInput.active then
        DXInput.active.mouseSelecting = false
    end
end)
