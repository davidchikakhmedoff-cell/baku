AdminCore = {
    admins = {},
    configLoaded = false,
    configError = nil,
    deniedNotifyAt = {}
}

local ADMIN_CONFIG_PATH = "systems/admin/config.lua"

local function tableSize(items)
    local count = 0
    if type(items) ~= "table" then return 0 end
    for _ in pairs(items) do count = count + 1 end
    return count
end

local function describeAdmins(items)
    local lines = {}
    if type(items) ~= "table" then return "none" end

    for rpName, level in pairs(items) do
        lines[#lines + 1] = tostring(rpName) .. "=" .. tostring(level)
    end

    table.sort(lines)
    return #lines > 0 and table.concat(lines, ", ") or "none"
end

local function copyAdmins(source)
    local result = {}
    if type(source) ~= "table" then return result end

    for rpName, level in pairs(source) do
        if type(rpName) == "string" then
            local numericLevel = tonumber(level)
            if numericLevel and numericLevel > 0 then
                result[rpName] = numericLevel
            end
        end
    end

    return result
end

local function logAdminConfig(message, level)
    outputDebugString("[Admin] " .. tostring(message), level or 3)
end

local function notify(player, text, r, g, b)
    RPNotifications.send(player, text, r, g, b)
end

local function getPlayerRPName(player)
    if not isElement(player) or getElementType(player) ~= "player" then return nil end

    local rpName = getElementData(player, "auth:rpName")
    if type(rpName) == "string" and rpName ~= "" then return rpName end

    rpName = getElementData(player, "rp:name")
    if type(rpName) == "string" and rpName ~= "" then return rpName end

    return nil
end

local function applyAdminConfig(adminsTable, sourceName)
    if type(AdminConfig) ~= "table" then
        AdminCore.configLoaded = false
        AdminCore.configError = "AdminConfig table is missing."
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    if type(adminsTable) ~= "table" then
        AdminCore.admins = {}
        AdminCore.configLoaded = false
        AdminCore.configError = "Admins table is missing or is not a table."
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    AdminCore.admins = copyAdmins(adminsTable)
    AdminCore.configLoaded = true
    AdminCore.configError = nil
    logAdminConfig("Loaded " .. tostring(tableSize(AdminCore.admins)) .. " admin record(s) from " .. tostring(sourceName) .. ": " .. describeAdmins(AdminCore.admins) .. ".")
    return true
end

function reloadAdminConfig()
    if hasObjectPermissionTo and not hasObjectPermissionTo(getThisResource(), "function.loadstring", false) then
        return false, "rp_core: нет ACL-права loadstring. В консоли хостинга: aclrequest allow rp_core all"
    end
    if not fileExists(ADMIN_CONFIG_PATH) then
        AdminCore.configLoaded = false
        AdminCore.configError = "Config file not found: " .. ADMIN_CONFIG_PATH
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    local file = fileOpen(ADMIN_CONFIG_PATH, true)
    if not file then
        AdminCore.configLoaded = false
        AdminCore.configError = "Could not open config file: " .. ADMIN_CONFIG_PATH
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    local content = fileRead(file, fileGetSize(file))
    fileClose(file)

    local chunk, compileError = loadstring(content)
    if not chunk then
        AdminCore.configLoaded = false
        AdminCore.configError = "Config syntax error: " .. tostring(compileError)
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    local previousAdminConfig = AdminConfig
    local previousAdmins = Admins
    local ok, runtimeError = pcall(chunk)
    if not ok then
        AdminConfig = previousAdminConfig
        Admins = previousAdmins
        AdminCore.configLoaded = false
        AdminCore.configError = "Config runtime error: " .. tostring(runtimeError)
        logAdminConfig(AdminCore.configError, 1)
        return false, AdminCore.configError
    end

    return applyAdminConfig(Admins, ADMIN_CONFIG_PATH)
end

function isPlayerAdmin(player)
    local rpName = getPlayerRPName(player)
    if not rpName then
        return false, 0, nil, "RP name is not set on player."
    end

    if not AdminCore.configLoaded or type(AdminCore.admins) ~= "table" then
        return false, 0, rpName, "Admin config is not loaded."
    end

    local level = tonumber(AdminCore.admins[rpName]) or 0
    if level <= 0 then
        return false, 0, rpName, "RP name is not present in Admins table. Loaded admins: " .. describeAdmins(AdminCore.admins) .. "."
    end

    return true, level, rpName
end

function AdminCore.getRPName(player)
    return getPlayerRPName(player)
end

function AdminCore.getAdminLevel(player)
    local ok, level = isPlayerAdmin(player)
    return ok and level or 0
end

function AdminCore.getAdminType(player)
    local level = AdminCore.getAdminLevel(player)
    for _, row in ipairs(AdminConfig.typeByLevel or {}) do
        if level >= (tonumber(row.min) or 0) then return row.type end
    end
    return nil
end

function AdminCore.getAdminTypeName(player)
    local adminType = AdminCore.getAdminType(player)
    return adminType and ((AdminConfig.typeNames or {})[adminType] or adminType) or "Нет доступа"
end

function AdminCore.hasPermission(player, permission)
    local ok, level = isPlayerAdmin(player)
    if not ok then return false, level or 0, nil end
    local adminType = AdminCore.getAdminType(player)
    local permissions = adminType and (AdminConfig.permissions or {})[adminType]
    if not permissions then return false, level, adminType end
    return permissions.all == true or permissions[permission] == true, level, adminType
end

function AdminCore.hasAccess(player, action)
    return AdminCore.hasPermission(player, action or "openPanel")
end

function hasAdminPermission(player, permissionName)
    return AdminCore.hasPermission(player, permissionName)
end

function isCoreFounder(player)
    return AdminCore.getAdminType(player) == "owner"
end

function getAdminAllowedActions(player)
    local allowed = {}
    for action in pairs(AdminActions or {}) do
        local ok = AdminCore.hasPermission(player, action)
        if ok then allowed[action] = true end
    end
    return allowed
end

function AdminCore.getPlayerById(id)
    id = tonumber(id)
    if not id then return nil end
    for _, player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player, "rp:id")) == id then return player end
    end
    return nil
end

local function collectPlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        local loggedIn = getElementData(player, "auth:loggedIn")
        if loggedIn then
            local vehicle = getPedOccupiedVehicle(player)
            local vehicleHealth, vehicleMaxHealth, vehicleModel, vehicleId
            if vehicle then
                vehicleHealth = math.floor(getElementHealth(vehicle))
                vehicleMaxHealth = tonumber(AdminConfig and AdminConfig.vehicleMaxHealth) or 1000
                vehicleModel = getElementModel(vehicle)
                vehicleId = getElementID(vehicle)
            end

            list[#list + 1] = {
                id = tonumber(getElementData(player, "rp:id")) or 0,
                name = getPlayerRPName(player) or "Unknown_RP_Name",
                level = tonumber(getElementData(player, "rp:level")) or 1,
                experience = tonumber(getElementData(player, "rp:experience")) or 0,
                health = math.floor(getElementHealth(player)),
                armor = math.floor(getPedArmor(player)),
                money = getPlayerMoney(player),
                skin = getElementModel(player),
                ping = getPlayerPing(player),
                muted = getElementData(player, "admin:muted") and true or false,
                frozen = isElementFrozen(player) and true or false,
                adminLevel = AdminCore.getAdminLevel(player),
                vehicleHealth = vehicleHealth,
                vehicleMaxHealth = vehicleMaxHealth,
                vehicleModel = vehicleModel,
                vehicleId = vehicleId
            }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function denyPanel(player, reason, rpName)
    local stamp = getRealTime().timestamp
    if (AdminCore.deniedNotifyAt[player] or 0) + 2 <= stamp then
        AdminCore.deniedNotifyAt[player] = stamp
        notify(player, "Недостаточно прав.", 239, 83, 80)
    end
    logAdminConfig("Access denied for " .. tostring(rpName or "nil") .. ": " .. tostring(reason), 2)
    if RPBans and RPBans.logAction then
        RPBans.logAction("permissionDenied", player, "adminPanel", "", 0, "no_permission", tostring(reason or ""))
    end
end

local function sendPanel(player)
    local ok, level, rpName, reason = isPlayerAdmin(player)
    if not ok then
        denyPanel(player, reason, rpName)
        return
    end
    if not AdminCore.hasPermission(player, "openPanel") then
        denyPanel(player, "permission=openPanel", rpName)
        return
    end

    triggerClientEvent(player, "admin:openPanel", resourceRoot, level, collectPlayers(), AdminConfig.levels, getAdminAllowedActions(player), AdminCore.getAdminTypeName(player))
end

function AdminCore.requestPanel(player)
    sendPanel(player)
end

local function refreshPanel(player)
    if not AdminCore.hasPermission(player, "openPanel") then return end
    triggerClientEvent(player, "admin:players", resourceRoot, collectPlayers())
end

local function runAction(player, action, targetId, data)
    if type(action) ~= "string" or not AdminActions[action] then return end

    local ok = AdminCore.hasPermission(player, action)
    if not ok then
        notify(player, "Недостаточно прав.", 239, 83, 80)
        if RPBans and RPBans.logAction then
            RPBans.logAction("permissionDenied", player, "admin:" .. tostring(action), "", 0, "no_permission", "action=" .. tostring(action))
        end
        return
    end

    local target = AdminCore.getPlayerById(targetId)
    if not target and action ~= "unban" then
        notify(player, "Игрок не найден.", 239, 83, 80)
        refreshPanel(player)
        return
    end

    local success, err = AdminActions[action](player, target, data or {})
    if success == false and err then
        notify(player, err, 239, 83, 80)
    end
    setTimer(refreshPanel, 150, 1, player)
end

addEventHandler("onResourceStart", resourceRoot, function()
    applyAdminConfig(Admins, "meta startup")
end)

function reloadAdminsCommand(player)
    if player and isElement(player) and not AdminCore.hasPermission(player, "adminCommands") then
        denyPanel(player, "permission=adminCommands", AdminCore.getRPName(player))
        return
    end
    local ok, err = reloadAdminConfig()
    local text = ok and ("Админ-конфиг перезагружен. Записей: " .. tostring(tableSize(AdminCore.admins)) .. ". Админы: " .. describeAdmins(AdminCore.admins) .. ".") or ("Ошибка перезагрузки админ-конфига: " .. tostring(err))

    if player and isElement(player) then
        notify(player, text, ok and 102 or 239, ok and 187 or 83, ok and 106 or 80)
    else
        logAdminConfig(text, ok and 3 or 1)
    end
end
addCommandHandler("reloadadmins", reloadAdminsCommand)

addEvent("admin:requestPanel", true)
addEventHandler("admin:requestPanel", root, function()
    if client ~= source then return end
    sendPanel(client)
end)

addEvent("admin:refresh", true)
addEventHandler("admin:refresh", root, function()
    if client ~= source then return end
    refreshPanel(client)
end)

addEvent("admin:action", true)
addEventHandler("admin:action", root, function(action, targetId, data)
    if client ~= source then return end
    runAction(client, action, targetId, data)
end)

addCommandHandler(AdminConfig.command, function(player)
    sendPanel(player)
end)
