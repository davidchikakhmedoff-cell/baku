RPBansDB = {
    connection = nil
}

function RPBansDB.connect()
    if RPBansDB.connection then return true end

    RPBansDB.connection = dbConnect("sqlite", RPBansConfig.databaseFile)
    if not RPBansDB.connection then
        outputDebugString("[Bans] SQLite connection failed.", 1)
        return false
    end

    return true
end

function RPBansDB.exec(sql, ...)
    if not RPBansDB.connect() then return false end
    local ok = dbExec(RPBansDB.connection, sql, ...)
    if not ok then
        outputDebugString("[Bans] dbExec failed: " .. tostring(sql), 1)
    end
    return ok
end

function RPBansDB.query(sql, ...)
    if not RPBansDB.connect() then return {} end
    local handle = dbQuery(RPBansDB.connection, sql, ...)
    if not handle then
        outputDebugString("[Bans] dbQuery failed: " .. tostring(sql), 1)
        return {}
    end

    local result, errorCode, errorMessage = dbPoll(handle, -1)
    if result == false then
        outputDebugString("[Bans] dbPoll failed (" .. tostring(errorCode) .. "): " .. tostring(errorMessage), 1)
        return {}
    end
    return result or {}
end

function RPBansDB.queryOne(sql, ...)
    return RPBansDB.query(sql, ...)[1]
end

function RPBansDB.init()
    if not RPBansDB.connect() then return false end

    RPBansDB.exec([[
        CREATE TABLE IF NOT EXISTS bans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rp_name TEXT,
            player_id INTEGER,
            serial TEXT,
            ip TEXT,
            admin_name TEXT,
            admin_level INTEGER,
            reason TEXT,
            created_at INTEGER NOT NULL,
            expires_at INTEGER,
            ban_type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            removed_by TEXT,
            removed_at INTEGER,
            remove_reason TEXT
        )
    ]])

    RPBansDB.exec([[
        CREATE TABLE IF NOT EXISTS admin_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            admin_name TEXT,
            admin_level INTEGER,
            target_name TEXT,
            target_serial TEXT,
            target_id INTEGER,
            reason TEXT,
            created_at INTEGER NOT NULL,
            details TEXT
        )
    ]])

    RPBansDB.exec("CREATE INDEX IF NOT EXISTS idx_bans_identity ON bans (serial, rp_name, status)")
    RPBansDB.exec("CREATE INDEX IF NOT EXISTS idx_admin_logs_action ON admin_logs (action, created_at)")
    return true
end
