AdminMutes = {}

local function now()
    return getRealTime().timestamp
end

function AdminMutes.set(player, adminName, seconds, reason)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    local expiresAt = seconds and seconds > 0 and (now() + seconds) or nil
    setElementData(player, "admin:muted", true, false)
    setElementData(player, "admin:muteExpires", expiresAt, false)
    setElementData(player, "admin:muteReason", reason or "Muted", false)
    return true
end

function AdminMutes.clear(player)
    if not isElement(player) then return false end
    removeElementData(player, "admin:muted")
    removeElementData(player, "admin:muteExpires")
    removeElementData(player, "admin:muteReason")
    RPNotifications.send(player, "Мут снят.", 102, 187, 106)
    return true
end

addEventHandler("onPlayerChat", root, function()
    if not getElementData(source, "admin:muted") then return end
    local expiresAt = getElementData(source, "admin:muteExpires")
    if expiresAt and expiresAt <= now() then
        AdminMutes.clear(source)
        return
    end

    cancelEvent()
    local text = "Вы не можете писать в чат: " .. tostring(getElementData(source, "admin:muteReason") or "Muted")
    RPNotifications.send(source, text, 239, 83, 80)
end)
