RPChat = {
    commands = {}
}

local function nowTime()
    local rt = getRealTime()
    return string.format("[%02d:%02d]", rt.hour, rt.minute)
end

local function withTime(text)
    text = tostring(text or "")
    if text:match("^%[%d%d:%d%d%]") then return text end
    return nowTime() .. " " .. text
end

local function playerRPName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Unknown"
end

local function playerDynamicId(player)
    return tonumber(getElementData(player, "rp:id")) or 0
end

local function isLoggedIn(player)
    return getElementData(player, "auth:loggedIn") == true
end

local function isMuted(player)
    if not getElementData(player, "admin:muted") then return false end
    local expiresAt = getElementData(player, "admin:muteExpires")
    if expiresAt and expiresAt <= getRealTime().timestamp then
        if AdminMutes and AdminMutes.clear then AdminMutes.clear(player) end
        return false
    end
    return true
end

local function getFormattedMuteTimeRemaining(player)
    local expiresAt = tonumber(getElementData(player, "admin:muteExpires")) or 0
    local now = getRealTime().timestamp
    local remaining = expiresAt - now
    if remaining <= 0 then return "истёк" end
    
    local hours = math.floor(remaining / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = math.floor(remaining % 60)
    
    if hours > 0 then
        return string.format("%d ч %d мин", hours, minutes)
    elseif minutes > 0 then
        return string.format("%d мин %d сек", minutes, seconds)
    else
        return string.format("%d сек", seconds)
    end
end

local function sameWorld(a, b)
    return getElementInterior(a) == getElementInterior(b) and getElementDimension(a) == getElementDimension(b)
end

local function distanceBetween(a, b)
    local ax, ay, az = getElementPosition(a)
    local bx, by, bz = getElementPosition(b)
    return getDistanceBetweenPoints3D(ax, ay, az, bx, by, bz)
end

local function playersInRange(player, radius)
    local recipients = {}
    for _, target in ipairs(getElementsByType("player")) do
        if isLoggedIn(target) and sameWorld(player, target) then
            if distanceBetween(player, target) <= radius then
                recipients[#recipients + 1] = target
            end
        end
    end
    return recipients
end

function registerChatCommand(name, handler, options)
    if type(name) ~= "string" or type(handler) ~= "function" then return false end
    RPChat.commands[name:lower()] = {
        handler = handler,
        options = options or {}
    }
    return true
end

function RPChat.send(player, payload)
    if not isElement(player) then return end
    payload = payload or {}
    if (payload.type == "system" or payload.type == "pay") and RPNotifications and RPNotifications.send then
        local color = payload.color or ChatConfig.colors.system
        RPNotifications.send(player, payload.text, color[1], color[2], color[3])
        return
    end
    triggerClientEvent(player, "chat:receive", resourceRoot, {
        type = payload.type,
        text = withTime(payload.text),
        color = payload.color
    })
end

-- Resource-to-resource delivery through the same DX chat as normal messages.
function sendCoreChatMessage(player, text, r, g, b)
    if not isElement(player) or getElementType(player) ~= "player" or type(text) ~= "string" then return false end
    RPChat.send(player, {
        type = "radio",
        text = text,
        color = {tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255}
    })
    return true
end

function RPChat.sendMany(players, payload)
    if type(players) ~= "table" or #players == 0 then return end
    payload = payload or {}
    if (payload.type == "system" or payload.type == "pay") and RPNotifications and RPNotifications.broadcast then
        local color = payload.color or ChatConfig.colors.system
        RPNotifications.broadcast(players, payload.text, color[1], color[2], color[3])
        return
    end
    triggerClientEvent(players, "chat:receive", resourceRoot, {
        type = payload.type,
        text = withTime(payload.text),
        color = payload.color
    })
end

function RPChat.clear(player)
    if not isElement(player) then return end
    triggerClientEvent(player, "chat:clear", resourceRoot)
end

function RPChat.clearMany(players)
    if type(players) ~= "table" or #players == 0 then return end
    triggerClientEvent(players, "chat:clear", resourceRoot)
end

function RPChat.sendSystem(player, text, good)
    local color = good and ChatConfig.colors.success or ChatConfig.colors.error
    if RPNotifications and RPNotifications.send then
        RPNotifications.send(player, text, color[1], color[2], color[3])
    end
end

function RPChat.notify(player, text, r, g, b)
    local color = { tonumber(r) or ChatConfig.colors.system[1], tonumber(g) or ChatConfig.colors.system[2], tonumber(b) or ChatConfig.colors.system[3] }
    if RPNotifications and RPNotifications.send then
        RPNotifications.send(player, tostring(text or ""), color[1], color[2], color[3])
    end
end

function RPChat.sendWelcome(player)
    local serverName = ChatConfig.serverName or (type(getServerName) == "function" and getServerName()) or "сервер"
    local color = ChatConfig.colors.welcome or ChatConfig.colors.system
    RPChat.send(player, {
        type = "welcome",
        text = string.format("Добро пожаловать на сервер «%s»!", tostring(serverName)),
        color = color
    })
    RPChat.send(player, {
        type = "welcome",
        text = "Желаем приятной игры!",
        color = color
    })
end

function RPChat.sendLocalMessage(player, text, msgType, color)
    local recipients = playersInRange(player, ChatConfig.localChatDistance)
    local payload = {
        type = msgType or "normal",
        text = text,
        color = color or ChatConfig.colors.normal
    }
    RPChat.sendMany(recipients, payload)
end

function RPChat.formatNormal(player, message)
    return string.format("%s %s: %s", nowTime(), playerRPName(player), message)
end

function RPChat.formatMe(player, action)
    return string.format("%s * %s %s", nowTime(), playerRPName(player), action)
end

function RPChat.formatDo(player, description)
    return string.format("%s * %s (%s)", nowTime(), description, playerRPName(player))
end

function RPChat.formatOOC(player, message)
    return string.format("%s (( %s ))", playerRPName(player), message)
end

function RPChat.formatAdmin(player, message)
    return string.format("[A] %s (%d): %s", playerRPName(player), playerDynamicId(player), message)
end

function RPChat.broadcastToAdmins(player, message)
    local text = RPChat.formatAdmin(player, message)
    local recipients = {}
    for _, target in ipairs(getElementsByType("player")) do
        if isLoggedIn(target) and AdminCore and AdminCore.hasPermission(target, "adminChat") then
            recipients[#recipients + 1] = target
        end
    end
    RPChat.sendMany(recipients, {
        type = "admin",
        text = text,
        color = ChatConfig.colors.admin
    })
end

local function parseCommand(message)
    local cmd, args = message:match("^/(%S+)(.*)$")
    if not cmd then return nil, nil end
    args = args:gsub("^%s+", "")
    return cmd:lower(), args
end

local function handlePlainMessage(player, message)
    local text = RPChat.formatNormal(player, message)
    RPChat.sendLocalMessage(player, text, "normal", ChatConfig.colors.normal)
end

local function handleFractionCommand(player,command,args)
    local resource=getResourceFromName('rp_fraction')
    if not resource or getResourceState(resource)~='running' then return false end
    for _,name in ipairs(getResourceExportedFunctions(resource) or {}) do
        if name=='executeFractionCommand' then
            return call(resource,name,player,command,args)==true
        end
    end
    return false
end

local function handleCarCommand(player,command,args)
    local resource=getResourceFromName('rp_car')
    if not resource or getResourceState(resource)~='running' then return false end
    for _,name in ipairs(getResourceExportedFunctions(resource) or {}) do
        if name=='executeCarCommand' then return call(resource,name,player,command,args)==true end
    end
    return false
end

function RPChat.processMessage(player, message)
    if not isElement(player) or not isLoggedIn(player) then return end

    message = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then return end

    if isMuted(player) then
        local reason = getElementData(player, "admin:muteReason") or "Muted"
        local timeRemaining = getFormattedMuteTimeRemaining(player)
        RPChat.sendSystem(player, "Вы не можете писать в чат. Причина: " .. tostring(reason) .. ". До окончания мута: " .. timeRemaining .. ".", false)
        return
    end

    if message:sub(1, 1) == "/" then
        local cmd, args = parseCommand(message)
        local def = cmd and RPChat.commands[cmd]
        if def then
            def.handler(player, args)
        elseif not handleFractionCommand(player,cmd,args) and not handleCarCommand(player,cmd,args) then
            RPChat.sendSystem(player, "Неизвестная команда.", false)
        end
        return
    end

    handlePlainMessage(player, message)
end

addEventHandler("onPlayerChat", root, function()
    cancelEvent()
end)

addEvent("chat:send", true)
addEventHandler("chat:send", root, function(message)
    if client ~= source then return end
    RPChat.processMessage(client, message)
end)

addEvent("chat:clientReady", true)
addEventHandler("chat:clientReady", root, function()
    if client ~= source then return end
    if isLoggedIn(client) then
        triggerClientEvent(client, "auth:spawned", resourceRoot)
    end
end)

addEventHandler("rp:onPlayerReady", root, function(player)
    if not isElement(player) or not isLoggedIn(player) then return end
    RPChat.sendWelcome(player)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    if RPChatDB and RPChatDB.init then RPChatDB.init() end
end)
