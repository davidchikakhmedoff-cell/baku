local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function splitArgs(args)
    local parts = {}
    for part in tostring(args or ""):gmatch("%S+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function resolvePlayerById(id)
    id = tonumber(id)
    if not id then return nil end
    if AdminCore and AdminCore.getPlayerById then
        return AdminCore.getPlayerById(id)
    end
    return getPlayerByDynamicID and getPlayerByDynamicID(id) or nil
end

local function sameWorld(a, b)
    return getElementInterior(a) == getElementInterior(b) and getElementDimension(a) == getElementDimension(b)
end

local function distanceBetween(a, b)
    local ax, ay, az = getElementPosition(a)
    local bx, by, bz = getElementPosition(b)
    return getDistanceBetweenPoints3D(ax, ay, az, bx, by, bz)
end

local function playersInCustomRange(player, radius)
    local recipients = {}
    radius = tonumber(radius) or ChatConfig.localChatDistance
    for _, target in ipairs(getElementsByType("player")) do
        if getElementData(target, "auth:loggedIn") and sameWorld(player, target) and distanceBetween(player, target) <= radius then
            recipients[#recipients + 1] = target
        end
    end
    return recipients
end

local function sendRangeSpeech(player, args, radius, verb, msgType, color)
    local message = trim(args)
    if message == "" then
        RPChat.sendSystem(player, "Использование: /" .. msgType .. " [сообщение]", false)
        return
    end
    if #message > (tonumber(ChatConfig.maxMessageLength) or 128) then
        RPChat.sendSystem(player, "Сообщение слишком длинное.", false)
        return
    end

    local text = string.format("%s %s: %s",
        getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player),
        verb,
        message
    )
    RPChat.sendMany(playersInCustomRange(player, radius), {
        type = msgType,
        text = text,
        color = color
    })
end

registerChatCommand("me", function(player, args)
    local action = trim(args)
    if action == "" then
        RPChat.sendSystem(player, "Использование: /me [действие]", false)
        return
    end

    local text = RPChat.formatMe(player, action)
    RPChat.sendLocalMessage(player, text, "me", ChatConfig.colors.me)
end)

registerChatCommand("do", function(player, args)
    local description = trim(args)
    if description == "" then
        RPChat.sendSystem(player, "Использование: /do [описание]", false)
        return
    end

    local text = RPChat.formatDo(player, description)
    RPChat.sendLocalMessage(player, text, "do", ChatConfig.colors.do_action)
end)

registerChatCommand("b", function(player, args)
    local message = trim(args)
    if message == "" then
        RPChat.sendSystem(player, "Использование: /b [сообщение]", false)
        return
    end
    if #message > (tonumber(ChatConfig.maxMessageLength) or 128) then
        RPChat.sendSystem(player, "Сообщение слишком длинное", false)
        return
    end

    RPChat.sendLocalMessage(player, RPChat.formatOOC(player, message), "ooc", ChatConfig.colors.normal)
end)

registerChatCommand("w", function(player, args)
    sendRangeSpeech(player, args, tonumber(ChatConfig.whisperDistance) or 4, "шепчет", "w", ChatConfig.colors.whisper or ChatConfig.colors.system)
end)

registerChatCommand("s", function(player, args)
    local distance = (tonumber(ChatConfig.localChatDistance) or 20) * (tonumber(ChatConfig.shoutDistanceMultiplier) or 2)
    sendRangeSpeech(player, args, distance, "кричит", "s", ChatConfig.colors.shout or ChatConfig.colors.admin)
end)

registerChatCommand("pay", function(player, args)
    local parts = splitArgs(args)
    local targetId = tonumber(parts[1])
    local amount = tonumber(parts[2])

    if not targetId or not amount then
        RPChat.sendSystem(player, "Использование: /pay [ID] [сумма]", false)
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        RPChat.sendSystem(player, "Сумма перевода должна быть больше нуля.", false)
        return
    end

    if targetId == (tonumber(getElementData(player, "rp:id")) or -1) then
        RPChat.sendSystem(player, "Нельзя передать деньги самому себе.", false)
        return
    end

    local target = resolvePlayerById(targetId)
    if not target or not isElement(target) or getElementType(target) ~= "player" or not getElementData(target, "auth:loggedIn") then
        RPChat.sendSystem(player, "Игрок с таким ID не найден.", false)
        return
    end

    local allowedDistance = tonumber(ChatConfig.payDistance) or 5
    if not sameWorld(player, target) then
        RPChat.sendSystem(player, "Игрок слишком далеко. Подойдите ближе для передачи денег.", false)
        return
    end

    if distanceBetween(player, target) > allowedDistance then
        RPChat.sendSystem(player, string.format("Игрок слишком далеко.", allowedDistance), false)
        return
    end

    local balance = getPlayerMoney(player)
    if balance < amount then
        RPChat.sendSystem(player, "Недостаточно денег для перевода.", false)
        return
    end

    takePlayerMoney(player, amount)
    givePlayerMoney(target, amount)

    local senderName = getElementData(player, "rp:name") or getPlayerName(player)
    local targetName = getElementData(target, "rp:name") or getPlayerName(target)

    RPChat.send(player, {
        type = "pay",
        text = string.format("Вы передали $%d игроку %s (%d).", amount, targetName, targetId),
        color = ChatConfig.colors.pay
    })

    RPChat.send(target, {
        type = "pay",
        text = string.format("Вы получили $%d от игрока %s (%d).", amount, senderName, tonumber(getElementData(player, "rp:id")) or 0),
        color = ChatConfig.colors.pay
    })
end)

registerChatCommand("a", function(player, args)
    local message = trim(args)
    if message == "" then
        RPChat.send(player, {
            type = "admin",
            text = "Использование: /a [сообщение]",
            color = ChatConfig.colors.error
        })
        return
    end

    if not AdminCore or not AdminCore.hasPermission(player, "adminChat") then
        RPChat.send(player, {
            type = "admin",
            text = "Недостаточно прав",
            color = ChatConfig.colors.error
        })
        return
    end

    RPChat.broadcastToAdmins(player, message)
end)

registerChatCommand("report", function(player, args)
    if AdminReports and AdminReports.create then
        AdminReports.create(player, args)
    else
        RPChat.send(player, {
            type = "report",
            text = "Система обращений сейчас недоступна",
            color = ChatConfig.colors.error
        })
    end
end)

registerChatCommand("createhotel", function(player)
    local resource = getResourceFromName("rp_home")
    if resource and getResourceState(resource) == "running" then
        triggerEvent("home:openCreateHotelCommand", player)
    else
        RPChat.sendSystem(player, "Система домов сейчас недоступна.", false)
    end
end)

registerChatCommand("apanel", function(player)
    if AdminCore and AdminCore.requestPanel then
        AdminCore.requestPanel(player)
    else
        RPChat.sendSystem(player, "Недостаточно прав.", false)
    end
end)

registerChatCommand("time", function(player)
    if togglePlayerTime then
        togglePlayerTime(player)
    else
        RPChat.sendSystem(player, "Система времени сейчас недоступна.", false)
    end
end)

registerChatCommand("clearchat", function(player)
    if not AdminCore or not AdminCore.hasPermission(player, "adminChat") then
        RPChat.sendSystem(player, "Недостаточно прав.", false)
        return
    end

    local recipients = {}
    for _, target in ipairs(getElementsByType("player")) do
        if getElementData(target, "auth:loggedIn") then
            recipients[#recipients + 1] = target
        end
    end

    RPChat.clearMany(recipients)
    RPChat.sendMany(recipients, {
        type = "system",
        text = "Чат очищен администрацией.",
        color = ChatConfig.colors.system
    })
end)

registerChatCommand("home", function(player, args)
    if getResourceFromName("rp_home") and getResourceState(getResourceFromName("rp_home")) == "running" then
        triggerEvent("home:findCommand", player, args)
    else
        RPChat.sendSystem(player, "Система домов сейчас недоступна.", false)
    end
end)

registerChatCommand("homecancel", function(player)
    if getResourceFromName("rp_home") and getResourceState(getResourceFromName("rp_home")) == "running" then
        triggerClientEvent(player, "home:clearGps", getResourceRootElement(getResourceFromName("rp_home")))
        RPChat.sendSystem(player, "GPS-метка удалена.", true)
    else
        RPChat.sendSystem(player, "Система домов сейчас недоступна.", false)
    end
end)

registerChatCommand("createhouse", function(player)
    if getResourceFromName("rp_home") and getResourceState(getResourceFromName("rp_home")) == "running" then
        triggerEvent("home:openCreateCommand", player)
    else
        RPChat.sendSystem(player, "Система домов сейчас недоступна.", false)
    end
end)

registerChatCommand("eject", function(player, args)
    local parts = splitArgs(args)
    local targetId = tonumber(parts[1])
    if not targetId then
        RPChat.sendSystem(player, "Использование: /eject [ID]", false)
        return
    end

    local car = getResourceFromName("rp_car")
    if car and getResourceState(car) == "running" then
        triggerEvent("car:ejectCommand", player, targetId)
    else
        RPChat.sendSystem(player, "Система транспорта сейчас недоступна.", false)
    end
end)

-- Current position for configuring markers and parking spaces.
registerChatCommand("coords", function(player)
    local x,y,z=getElementPosition(player)
    local _,_,rotation=getElementRotation(player)
    RPChat.send(player,{type="normal",text=string.format("x=%.4f, y=%.4f, z=%.4f, rotation=%.2f | interior=%d, dimension=%d",x,y,z,rotation,getElementInterior(player),getElementDimension(player)),color=ChatConfig.colors.system})
end)
