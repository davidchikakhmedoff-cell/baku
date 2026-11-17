AdminReports = {
    items = {},
    nextId = 1,
    cooldown = {}
}

local REPORT_MIN_LENGTH = 5
local REPORT_MAX_LENGTH = 180
local REPORT_COOLDOWN = 60

local function now()
    return getRealTime().timestamp
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function playerName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Unknown"
end

local function playerDynamicId(player)
    return tonumber(getElementData(player, "rp:id")) or 0
end

local function notify(player, text, r, g, b)
    RPChat.send(player, {
        type = "report",
        text = text,
        color = {r or 79, g or 195, b or 247}
    })
end

local function adminHas(player, permission)
    return AdminCore and AdminCore.hasPermission and AdminCore.hasPermission(player, permission) == true
end

local function logReportAction(action, admin, report, reason)
    if RPBans and RPBans.logAction then
        local targetName = report and report.playerName or "report"
        local targetId = report and report.playerId or 0
        RPBans.logAction(action, admin, targetName, "", targetId, reason or "", "reportId=" .. tostring(report and report.id or 0))
    end
end

local function findOnlineByAccount(accountId)
    accountId = tonumber(accountId) or 0
    for _, player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player, "auth:playerId")) == accountId then return player end
    end
    return nil
end

local function publicReport(report)
    local online = findOnlineByAccount(report.accountId)
    return {
        id = report.id,
        playerName = report.playerName,
        playerId = report.playerId,
        accountId = report.accountId,
        text = report.text,
        createdAt = report.createdAt,
        status = report.status,
        takenBy = report.takenBy or "",
        closedBy = report.closedBy or "",
        online = online and true or false
    }
end

local function activeReports()
    local list = {}
    for _, report in pairs(AdminReports.items) do
        if report.status ~= "closed" then list[#list + 1] = publicReport(report) end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function syncReports(target)
    if target then
        triggerClientEvent(target, "adminReports:sync", resourceRoot, activeReports())
        return
    end
    for _, player in ipairs(getElementsByType("player")) do
        if adminHas(player, "openReports") then
            triggerClientEvent(player, "adminReports:sync", resourceRoot, activeReports())
        end
    end
end

local function deny(player, permission)
    notify(player, "Недостаточно прав.", 239, 83, 80)
    if RPBans and RPBans.logAction then
        RPBans.logAction("permissionDenied", player, "reports", "", 0, "no_permission", "permission=" .. tostring(permission))
    end
end

local function createReport(player, text)
    if not getElementData(player, "auth:loggedIn") then return end
    text = trim(text)
    if #text < REPORT_MIN_LENGTH then notify(player, "/report [жалоба/вопрос]", 239, 83, 80); return end
    if #text > REPORT_MAX_LENGTH then notify(player, "Текст обращения слишком длинный.", 239, 83, 80); return end

    local stamp = now()
    if (AdminReports.cooldown[player] or 0) + REPORT_COOLDOWN > stamp then
        notify(player, "Обращение можно отправлять не чаще одного раза в минуту.", 239, 83, 80)
        return
    end
    AdminReports.cooldown[player] = stamp

    local id = AdminReports.nextId
    AdminReports.nextId = id + 1
    AdminReports.items[id] = {
        id = id,
        accountId = tonumber(getElementData(player, "auth:playerId")) or 0,
        playerName = playerName(player),
        playerId = playerDynamicId(player),
        text = text,
        createdAt = stamp,
        status = "open"
    }

    notify(player, "Ваше обращение отправлено администрации.", 102, 187, 106)
    syncReports()
end

function AdminReports.create(player, text)
    return createReport(player, text)
end

addCommandHandler("report", function(player, _, ...)
    createReport(player, table.concat({...}, " "))
end)

addEvent("adminReports:request", true)
addEventHandler("adminReports:request", root, function()
    if client ~= source then return end
    if not adminHas(client, "openReports") then deny(client, "openReports"); return end
    triggerClientEvent(client, "adminReports:open", resourceRoot, activeReports())
end)

addEvent("adminReports:action", true)
addEventHandler("adminReports:action", root, function(action, reportId, text)
    if client ~= source then return end
    local report = AdminReports.items[tonumber(reportId) or 0]
    if not report or report.status == "closed" then return end

    local admin = playerName(client)
    local target = findOnlineByAccount(report.accountId)

    if action == "take" then
        if not adminHas(client, "manageReports") then deny(client, "manageReports"); return end
        report.status = "taken"
        report.takenBy = admin
        logReportAction("reportTake", client, report, "")
    elseif action == "close" then
        if not adminHas(client, "manageReports") then deny(client, "manageReports"); return end
        report.status = "closed"
        report.closedBy = admin
        logReportAction("reportClose", client, report, "")
    elseif action == "answer" then
        if not adminHas(client, "answerReports") then deny(client, "answerReports"); return end
        text = trim(text)
        if text == "" or #text > 160 then notify(client, "Введите корректный ответ.", 239, 83, 80); return end
        if not target then notify(client, "Игрок офлайн. Ответ сейчас отправить нельзя.", 239, 83, 80); return end
        notify(target, "Ответ от администратора " .. admin .. ": #FFFFFF" .. text, 245, 176, 65)
        notify(client, "Ответ отправлен игроку.", 102, 187, 106)
        logReportAction("reportAnswer", client, report, text)
    elseif action == "teleport" then
        if not adminHas(client, "teleportTo") then deny(client, "teleportTo"); return end
        if not target then notify(client, "Игрок офлайн.", 239, 83, 80); return end
        AdminActions.teleportTo(client, target)
        logReportAction("reportTeleport", client, report, "")
    elseif action == "spectate" then
        if not adminHas(client, "spectate") then deny(client, "spectate"); return end
        if not target then notify(client, "Игрок офлайн.", 239, 83, 80); return end
        AdminActions.spectate(client, target)
        logReportAction("reportSpectate", client, report, "")
    end

    syncReports()
end)

addEventHandler("onPlayerQuit", root, function()
    AdminReports.cooldown[source] = nil
    syncReports()
end)
