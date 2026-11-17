RPBans = {}

local function now()
    return getRealTime().timestamp
end

local function cleanText(value, fallback)
    if type(value) ~= "string" then return fallback end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return fallback end
    return value
end

local function adminName(admin)
    if isElement(admin) then
        return getElementData(admin, "rp:name") or getPlayerName(admin) or "Console"
    end
    return tostring(admin or "Console")
end

local function adminLevel(admin)
    if isElement(admin) and AdminCore and AdminCore.getAdminLevel then
        return tonumber(AdminCore.getAdminLevel(admin)) or 0
    end
    return 0
end

local function playerName(player)
    return getElementData(player, "rp:name") or getPlayerName(player) or "Unknown"
end

local function playerId(player)
    return tonumber(getElementData(player, "rp:id")) or 0
end

local function durationToExpiry(duration, unit)
    unit = unit or "permanent"
    if unit == "permanent" then return nil, "permanent" end

    local amount = math.max(1, math.floor(tonumber(duration) or 1))
    local unitSeconds = RPBansConfig.units[unit] or RPBansConfig.units.days
    if unitSeconds <= 0 then return nil, "permanent" end
    return now() + amount * unitSeconds, "temporary"
end

local function expireBan(row)
    if not row or row.status ~= "active" then return end
    RPBansDB.exec("UPDATE bans SET status = 'expired' WHERE id = ?", row.id)
end

function RPBans.logAction(action, admin, targetName, targetSerial, targetId, reason, details)
    RPBansDB.init()
    local stamp = now()
    RPBansDB.exec([[
        INSERT INTO admin_logs (action, admin_name, admin_level, target_name, target_serial, target_id, reason, created_at, details)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], tostring(action), adminName(admin), adminLevel(admin), targetName, targetSerial, targetId, cleanText(reason, RPBansConfig.defaultReason), stamp, details or "")

    outputDebugString(string.format(
        "[AdminLog] %s | admin=%s level=%s target=%s id=%s serial=%s reason=%s time=%s",
        tostring(action),
        adminName(admin),
        tostring(adminLevel(admin)),
        tostring(targetName),
        tostring(targetId),
        tostring(targetSerial),
        cleanText(reason, RPBansConfig.defaultReason),
        tostring(stamp)
    ), 3)
end

function RPBans.isPlayerBanned(rpName, serial)
    RPBansDB.init()
    local stamp = now()
    local row = RPBansDB.queryOne([[
        SELECT * FROM bans
        WHERE status = 'active'
          AND ((serial IS NOT NULL AND serial <> '' AND serial = ?) OR (rp_name IS NOT NULL AND rp_name <> '' AND rp_name = ?))
        ORDER BY id DESC
        LIMIT 1
    ]], serial or "", rpName or "")

    if not row then return false end
    if row.expires_at and tonumber(row.expires_at) and tonumber(row.expires_at) <= stamp then
        expireBan(row)
        return false
    end

    return true, row
end

function RPBans.banPlayer(target, admin, duration, unit, reason)
    if not isElement(target) or getElementType(target) ~= "player" then return false, "Player not found." end
    RPBansDB.init()

    reason = cleanText(reason, RPBansConfig.defaultReason)
    local expiresAt, banType = durationToExpiry(duration, unit)
    local targetName = playerName(target)
    local targetSerial = getPlayerSerial(target)
    local targetIp = getPlayerIP(target)
    local targetId = playerId(target)
    local stamp = now()

    local ok = RPBansDB.exec([[
        INSERT INTO bans (
            rp_name, player_id, serial, ip, admin_name, admin_level, reason,
            created_at, expires_at, ban_type, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
    ]], targetName, targetId, targetSerial, targetIp, adminName(admin), adminLevel(admin), reason, stamp, expiresAt, banType)

    if not ok then return false, "Could not save ban." end
    RPBans.logAction("ban", admin, targetName, targetSerial, targetId, reason, "unit=" .. tostring(unit) .. "; duration=" .. tostring(duration))
    kickPlayer(target, admin, reason)
    return true
end

function RPBans.unbanPlayerByIdentity(rpName, serial, admin, reason)
    RPBansDB.init()
    reason = cleanText(reason, "Unbanned by administrator")
    local rows = RPBansDB.query([[
        SELECT id FROM bans
        WHERE status = 'active'
          AND ((serial IS NOT NULL AND serial <> '' AND serial = ?) OR (rp_name IS NOT NULL AND rp_name <> '' AND rp_name = ?))
    ]], serial or "", rpName or "")

    if not rows or #rows == 0 then return false, "Active ban not found." end

    local stamp = now()
    for _, row in ipairs(rows) do
        RPBansDB.exec("UPDATE bans SET status = 'removed', removed_by = ?, removed_at = ?, remove_reason = ? WHERE id = ?", adminName(admin), stamp, reason, row.id)
    end

    RPBans.logAction("unban", admin, rpName, serial, nil, reason, "removed=" .. tostring(#rows))
    return true
end

function isPlayerBanned(rpName, serial)
    return RPBans.isPlayerBanned(rpName, serial)
end

function banPlayer(target, admin, duration, unit, reason)
    return RPBans.banPlayer(target, admin, duration, unit, reason)
end

function unbanPlayerByIdentity(rpName, serial, admin, reason)
    return RPBans.unbanPlayerByIdentity(rpName, serial, admin, reason)
end

function logAdminAction(action, admin, targetName, targetSerial, targetId, reason, details)
    return RPBans.logAction(action, admin, targetName, targetSerial, targetId, reason, details)
end

addEventHandler("onResourceStart", resourceRoot, function()
    RPBansDB.init()
end)
