RPNotifications = RPNotifications or {}

local function clampColor(value, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.max(0, math.min(255, math.floor(value)))
end

function RPNotifications.send(player, text, r, g, b, duration)
    if not isElement(player) or getElementType(player) ~= "player" then return false end

    triggerClientEvent(player, "notifications:push", resourceRoot, {
        text = tostring(text or ""),
        color = {
            clampColor(r, NotificationConfig.colors.info[1]),
            clampColor(g, NotificationConfig.colors.info[2]),
            clampColor(b, NotificationConfig.colors.info[3])
        },
        duration = math.max(1500, math.min(20000, tonumber(duration) or NotificationConfig.duration))
    })
    return true
end

function RPNotifications.broadcast(players, text, r, g, b, duration)
    if type(players) ~= "table" then return false end
    local sent = false
    for _, player in ipairs(players) do
        sent = RPNotifications.send(player, text, r, g, b, duration) or sent
    end
    return sent
end

function sendCoreNotification(player, text, r, g, b, duration)
    return RPNotifications.send(player, text, r, g, b, duration)
end
