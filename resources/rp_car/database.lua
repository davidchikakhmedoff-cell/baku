RPCarDB = {
    connection = nil,
    vehicles = {}
}

local function stamp()
    return getRealTime().timestamp
end

local function rows(sql, ...)
    if not isElement(RPCarDB.connection) then return {} end
    local handle = dbQuery(RPCarDB.connection, sql, ...)
    if not handle then return {} end
    return dbPoll(handle, -1) or {}
end

function RPCarDB.query(sql, ...)
    return rows(sql, ...)
end

function RPCarDB.exec(sql, ...)
    if not isElement(RPCarDB.connection) then return false end
    return dbExec(RPCarDB.connection, sql, ...)
end

local function columnExists(tableName, columnName)
    for _, row in ipairs(rows("PRAGMA table_info(" .. tostring(tableName) .. ")")) do
        if row.name == columnName then return true end
    end
    return false
end

local function addColumn(tableName, columnName, definition)
    if not columnExists(tableName, columnName) then
        RPCarDB.exec("ALTER TABLE " .. tostring(tableName) .. " ADD COLUMN " .. tostring(columnName) .. " " .. tostring(definition))
    end
end

local function normalize(row)
    row.id = tonumber(row.id)
    row.owner_account_id = tonumber(row.owner_account_id) or 0
    row.model = tonumber(row.model) or 400
    row.gov_price = tonumber(row.gov_price) or 0
    row.health = tonumber(row.health) or 1000
    row.fuel = FuelConfig.clamp(row.fuel, FuelConfig.capacity(row.model))
    row.mileage = tonumber(row.mileage) or 0
    row.house_id = tonumber(row.house_id) or 0
    row.parking_slot = tonumber(row.parking_slot) or 0
    row.x = tonumber(row.x) or 0
    row.y = tonumber(row.y) or 0
    row.z = tonumber(row.z) or 0
    row.rx = tonumber(row.rx) or 0
    row.ry = tonumber(row.ry) or 0
    row.rz = tonumber(row.rz) or 0
    row.interior = tonumber(row.interior) or 0
    row.dimension = tonumber(row.dimension) or 0
    row.color_r = tonumber(row.color_r) or 255
    row.color_g = tonumber(row.color_g) or 255
    row.color_b = tonumber(row.color_b) or 255
    row.plate = tostring(row.plate or "")
    row.upgrades = tostring(row.upgrades or "")
    row.visual_tuning = tostring(row.visual_tuning or "")
    row.toner_percent = tonumber(row.toner_percent) or 0
    row.toner_lob_percent = tonumber(row.toner_lob_percent) or 0
    row.toner_front_percent = tonumber(row.toner_front_percent) or 0
    row.toner_rear_percent = tonumber(row.toner_rear_percent) or row.toner_percent or 0
    row.engine_on = tonumber(row.engine_on) or 0
    row.locked = tonumber(row.locked) or 0
    row.lights_on = tonumber(row.lights_on) or 0
    row.suspension_level = tonumber(row.suspension_level) or 0
    row.acceleration_level = tonumber(row.acceleration_level) or 0
    row.max_speed_level = tonumber(row.max_speed_level) or 0
    row.created_at = tonumber(row.created_at) or stamp()
    row.updated_at = tonumber(row.updated_at) or row.created_at
    return row
end

local function valueOrCurrent(data, current, key)
    if data[key] ~= nil then return data[key] end
    return current[key]
end

function RPCarDB.init()
    RPCarDB.connection = dbConnect("sqlite", CarConfig.database.file)
    if not RPCarDB.connection then
        outputDebugString("[RPCar] SQLite connection failed.", 1)
        return false
    end

    RPCarDB.exec([[
        CREATE TABLE IF NOT EXISTS personal_vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_account_id INTEGER NOT NULL,
            model INTEGER NOT NULL,
            custom_name TEXT NOT NULL,
            gov_price INTEGER NOT NULL,
            color_r INTEGER DEFAULT 255,
            color_g INTEGER DEFAULT 255,
            color_b INTEGER DEFAULT 255,
            plate TEXT DEFAULT '',
            upgrades TEXT DEFAULT '',
            visual_tuning TEXT DEFAULT '',
            toner_percent INTEGER DEFAULT 0,
            toner_lob_percent INTEGER DEFAULT 0,
            toner_front_percent INTEGER DEFAULT 0,
            toner_rear_percent INTEGER DEFAULT 0,
            suspension_level INTEGER DEFAULT 0,
            acceleration_level INTEGER DEFAULT 0,
            max_speed_level INTEGER DEFAULT 0,
            engine_on INTEGER DEFAULT 0,
            locked INTEGER DEFAULT 0,
            lights_on INTEGER DEFAULT 0,
            health REAL DEFAULT 1000,
            fuel REAL DEFAULT 30,
            mileage REAL DEFAULT 0,
            house_id INTEGER DEFAULT 0,
            parking_slot INTEGER DEFAULT 0,
            x REAL NOT NULL,
            y REAL NOT NULL,
            z REAL NOT NULL,
            rx REAL DEFAULT 0,
            ry REAL DEFAULT 0,
            rz REAL DEFAULT 0,
            interior INTEGER DEFAULT 0,
            dimension INTEGER DEFAULT 0,
            status TEXT DEFAULT 'active',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]])

    addColumn("personal_vehicles", "fuel", "REAL DEFAULT 30")
    -- Preserve pre-fuel-system values, including the old unused value 100.
    if not columnExists("personal_vehicles", "fuel_legacy") then
        addColumn("personal_vehicles", "fuel_legacy", "REAL")
    end
    RPCarDB.exec("UPDATE personal_vehicles SET fuel_legacy = fuel WHERE fuel_legacy IS NULL")
    addColumn("personal_vehicles", "mileage", "REAL DEFAULT 0")
    addColumn("personal_vehicles", "status", "TEXT DEFAULT 'active'")
    addColumn("personal_vehicles", "plate", "TEXT DEFAULT ''")
    addColumn("personal_vehicles", "upgrades", "TEXT DEFAULT ''")
    addColumn("personal_vehicles", "visual_tuning", "TEXT DEFAULT ''")
    addColumn("personal_vehicles", "toner_percent", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "toner_lob_percent", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "toner_front_percent", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "toner_rear_percent", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "engine_on", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "locked", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "lights_on", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "suspension_level", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "acceleration_level", "INTEGER DEFAULT 0")
    addColumn("personal_vehicles", "max_speed_level", "INTEGER DEFAULT 0")
    RPCarDB.reload()
    return true
end

function RPCarDB.reload()
    RPCarDB.vehicles = {}
    for _, row in ipairs(rows("SELECT * FROM personal_vehicles ORDER BY id ASC")) do
        row = normalize(row)
        RPCarDB.vehicles[row.id] = row
    end
end

function RPCarDB.createVehicle(data)
    local nowStamp = stamp()
    if not isElement(RPCarDB.connection) then return false end
    local handle = dbQuery(RPCarDB.connection, [[
        INSERT INTO personal_vehicles (
            owner_account_id, model, custom_name, gov_price,
            color_r, color_g, color_b, plate, upgrades, visual_tuning, toner_percent, toner_lob_percent, toner_front_percent, toner_rear_percent, suspension_level, acceleration_level, max_speed_level, engine_on, locked, lights_on, health, fuel, mileage,
            house_id, parking_slot, x, y, z, rx, ry, rz,
            interior, dimension, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], data.owner_account_id, data.model, data.custom_name, data.gov_price,
        data.color_r or 255, data.color_g or 255, data.color_b or 255, data.plate or "", data.upgrades or "",
        data.visual_tuning or "", data.toner_percent or 0, data.toner_lob_percent or 0, data.toner_front_percent or 0, data.toner_rear_percent or data.toner_percent or 0,
        data.suspension_level or 0, data.acceleration_level or 0, data.max_speed_level or 0,
        data.engine_on or 0, data.locked or 0, data.lights_on or 0, data.health or 1000, data.fuel or FuelConfig.initial, data.mileage or 0,
        data.house_id or 0, data.parking_slot or 0, data.x, data.y, data.z, data.rx or 0, data.ry or 0, data.rz or 0,
        data.interior or 0, data.dimension or 0, data.status or VehicleStatuses.active, nowStamp, nowStamp)

    if not handle then return false end
    local result, affected, insertedId = dbPoll(handle, -1)
    insertedId = tonumber(insertedId)
    if result == false or tonumber(affected) ~= 1 or not insertedId or insertedId <= 0 then
        outputDebugString("[RPCar] Vehicle INSERT failed; purchase must be refunded.", 1)
        return false
    end
    RPCarDB.reload()
    local row = RPCarDB.vehicles[insertedId]
    if not row or tonumber(row.owner_account_id) ~= tonumber(data.owner_account_id)
        or tonumber(row.house_id) ~= tonumber(data.house_id or 0)
        or tonumber(row.parking_slot) ~= tonumber(data.parking_slot or 0) then
        RPCarDB.exec("DELETE FROM personal_vehicles WHERE id = ?", insertedId)
        RPCarDB.reload()
        outputDebugString("[RPCar] Vehicle ownership/parking verification failed.", 1)
        return false
    end
    return insertedId
end

function RPCarDB.updateVehicle(id, data)
    id = tonumber(id)
    if not id then return false end
    local current = RPCarDB.vehicles[id]
    if not current then return false end
    -- Other vehicle updates must not replace unsaved consumption with a stale row.
    if FuelSystem and FuelSystem.byIdFuel and data.fuel == nil then
        data.fuel = FuelSystem.byIdFuel(id) or current.fuel
    end

    local ok = RPCarDB.exec([[
        UPDATE personal_vehicles SET
            owner_account_id = ?, model = ?, custom_name = ?, gov_price = ?,
            color_r = ?, color_g = ?, color_b = ?, plate = ?, upgrades = ?, visual_tuning = ?, toner_percent = ?, toner_lob_percent = ?, toner_front_percent = ?, toner_rear_percent = ?, suspension_level = ?, acceleration_level = ?, max_speed_level = ?, engine_on = ?, locked = ?, lights_on = ?, health = ?, fuel = ?, mileage = ?,
            house_id = ?, parking_slot = ?, x = ?, y = ?, z = ?, rx = ?, ry = ?, rz = ?,
            interior = ?, dimension = ?, status = ?, updated_at = ?
        WHERE id = ?
    ]], valueOrCurrent(data, current, "owner_account_id"), valueOrCurrent(data, current, "model"), valueOrCurrent(data, current, "custom_name"), valueOrCurrent(data, current, "gov_price"),
        valueOrCurrent(data, current, "color_r"), valueOrCurrent(data, current, "color_g"), valueOrCurrent(data, current, "color_b"), valueOrCurrent(data, current, "plate"), valueOrCurrent(data, current, "upgrades"), valueOrCurrent(data, current, "visual_tuning"),
        valueOrCurrent(data, current, "toner_percent"), valueOrCurrent(data, current, "toner_lob_percent"), valueOrCurrent(data, current, "toner_front_percent"), valueOrCurrent(data, current, "toner_rear_percent"),
        valueOrCurrent(data, current, "suspension_level"), valueOrCurrent(data, current, "acceleration_level"), valueOrCurrent(data, current, "max_speed_level"),
        valueOrCurrent(data, current, "engine_on"), valueOrCurrent(data, current, "locked"), valueOrCurrent(data, current, "lights_on"),
        valueOrCurrent(data, current, "health"), valueOrCurrent(data, current, "fuel"), valueOrCurrent(data, current, "mileage"),
        valueOrCurrent(data, current, "house_id"), valueOrCurrent(data, current, "parking_slot"), valueOrCurrent(data, current, "x"), valueOrCurrent(data, current, "y"), valueOrCurrent(data, current, "z"),
        valueOrCurrent(data, current, "rx"), valueOrCurrent(data, current, "ry"), valueOrCurrent(data, current, "rz"), valueOrCurrent(data, current, "interior"), valueOrCurrent(data, current, "dimension"),
        valueOrCurrent(data, current, "status"), stamp(), id)

    if ok then RPCarDB.reload() end
    return ok
end

function RPCarDB.deleteVehicle(id)
    id = tonumber(id)
    if not id then return false end
    local ok = RPCarDB.exec("DELETE FROM personal_vehicles WHERE id = ?", id)
    if ok then RPCarDB.reload() end
    return ok
end
