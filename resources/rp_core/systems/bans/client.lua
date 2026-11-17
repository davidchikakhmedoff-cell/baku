RPBanNotice = {
    visible = false,
    message = "",
    alpha = 0,
    targetAlpha = 0,
    hitbox = nil
}

local function s(value) return DXUtils.s(value) end
local function color(name, alpha) return DXUtils.color(AuthConfig.colors[name], alpha or 255) end
local function crisp(value) return math.floor(value + 0.5) end

local function closeNotice()
    RPBanNotice.targetAlpha = 0
end

function RPBanNotice.render()
    RPBanNotice.alpha = DXUtils.lerp(RPBanNotice.alpha, RPBanNotice.targetAlpha, 0.12)
    local alpha = RPBanNotice.alpha
    if alpha < 1 and RPBanNotice.targetAlpha == 0 then
        RPBanNotice.visible = false
        removeEventHandler("onClientRender", root, RPBanNotice.render)
        removeEventHandler("onClientClick", root, RPBanNotice.click)
        return
    end

    local sw, sh = guiGetScreenSize()
    local w, h = s(560), s(250)
    local x, y = crisp((sw - w) / 2), crisp((sh - h) / 2)

    dxDrawRectangle(0, 0, sw, sh, tocolor(0, 0, 0, 115 * alpha / 255))
    DXUtils.shadow(x, y, w, h, s(18), 100 * alpha / 255)
    DXUtils.roundedRect(x, y, w, h, s(18), color("window", alpha))
    dxDrawText("Доступ запрещён", x + s(30), y + s(24), x + w - s(30), y + s(58), tocolor(255, 255, 255, alpha), 1.25, "default-bold", "center", "center", true)
    dxDrawRectangle(x + s(34), y + s(70), w - s(68), 1, color("primary", 120 * alpha / 255))
    dxDrawText(RPBanNotice.message, x + s(34), y + s(88), x + w - s(34), y + s(166), color("text", alpha), 0.95, "default", "center", "top", true, true)

    RPBanNotice.hitbox = { x = crisp(x + (w - s(150)) / 2), y = y + h - s(62), w = s(150), h = s(40) }
    local mx, my = getCursorPosition()
    mx, my = (mx or 0) * sw, (my or 0) * sh
    local hover = mx >= RPBanNotice.hitbox.x and mx <= RPBanNotice.hitbox.x + RPBanNotice.hitbox.w and my >= RPBanNotice.hitbox.y and my <= RPBanNotice.hitbox.y + RPBanNotice.hitbox.h
    local bg = hover and {45, 52, 56} or AuthConfig.colors.panel
    DXUtils.roundedRect(RPBanNotice.hitbox.x, RPBanNotice.hitbox.y, RPBanNotice.hitbox.w, RPBanNotice.hitbox.h, s(8), tocolor(bg[1], bg[2], bg[3], math.min(245, alpha)))
    dxDrawRectangle(RPBanNotice.hitbox.x + s(12), RPBanNotice.hitbox.y + RPBanNotice.hitbox.h - s(2), RPBanNotice.hitbox.w - s(24), s(1), color("primary", hover and 150 * alpha / 255 or 90 * alpha / 255))
    dxDrawText("OK", RPBanNotice.hitbox.x + s(12), RPBanNotice.hitbox.y, RPBanNotice.hitbox.x + RPBanNotice.hitbox.w - s(12), RPBanNotice.hitbox.y + RPBanNotice.hitbox.h, tocolor(255,255,255,alpha), 1, "default-bold", "center", "center")
end

function RPBanNotice.click(button, state, x, y)
    if button ~= "left" or state ~= "down" then return end
    local box = RPBanNotice.hitbox
    if box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h then
        closeNotice()
    end
end

addEvent("bans:showBanInfo", true)
addEventHandler("bans:showBanInfo", resourceRoot, function(message)
    RPBanNotice.message = tostring(message or "Ваш аккаунт заблокирован.")
    RPBanNotice.visible = true
    RPBanNotice.targetAlpha = 255
    showCursor(true)
    removeEventHandler("onClientRender", root, RPBanNotice.render)
    removeEventHandler("onClientClick", root, RPBanNotice.click)
    addEventHandler("onClientRender", root, RPBanNotice.render)
    addEventHandler("onClientClick", root, RPBanNotice.click)
end)

addEventHandler("onClientKey", root, function(button, press)
    if RPBanNotice.visible and press and button == "escape" then
        cancelEvent()
        closeNotice()
    end
end)
