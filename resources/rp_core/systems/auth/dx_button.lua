DXButton = {}
DXButton.__index = DXButton

function DXButton:new(text, onClick)
    return setmetatable({ text = text, onClick = onClick, hover = 0, press = 0, enabled = true }, self)
end

function DXButton:draw(x, y, w, h, alpha)
    local hovered = self.enabled and DXUtils.inBox(x, y, w, h)
    self.hover = DXUtils.lerp(self.hover, hovered and 1 or 0, 0.18)
    self.press = DXUtils.lerp(self.press, self.pressed and 1 or 0, 0.24)
    local c = AuthConfig.colors.primary
    local lift = self.hover * 12 - self.press * 8
    local offsetY = self.press * 1
    local radius = DXUtils.s(9)

    DXUtils.roundedRect(x, y + offsetY, w, h, radius, tocolor(c[1] + lift, c[2] + lift, c[3] + lift, 218 * alpha / 255))
    if self.hover > 0.02 then
        dxDrawRectangle(x + DXUtils.s(18), y + h - DXUtils.s(2) + offsetY, w - DXUtils.s(36), DXUtils.s(1), tocolor(255, 255, 255, 70 * self.hover * alpha / 255))
    end
    dxDrawText(self.text, x, y + offsetY, x + w, y + offsetY + h, tocolor(255, 255, 255, alpha), 1.02, "default-bold", "center", "center")
end

function DXButton:mouse(button, state, x, y, bx, by, bw, bh)
    if not self.enabled or button ~= "left" then return false end
    if state == "down" and x >= bx and x <= bx + bw and y >= by and y <= by + bh then self.pressed = true; return true end
    if state == "up" then
        local was = self.pressed
        self.pressed = false
        if was and x >= bx and x <= bx + bw and y >= by and y <= by + bh and self.onClick then self.onClick(); return true end
    end
    return false
end
