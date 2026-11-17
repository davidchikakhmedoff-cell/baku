RPHomeDB = {
    connection = nil,
    houses = {},
    parkings = {},
    hotels = {},
    hotelParkings = {}
}

local function stamp()
    return getRealTime().timestamp
end

local function rows(sql, ...)
    if not RPHomeDB.connection then return {} end
    local handle = dbQuery(RPHomeDB.connection, sql, ...)
    return dbPoll(handle, -1) or {}
end

function RPHomeDB.query(sql, ...)
    return rows(sql, ...)
end

function RPHomeDB.exec(sql, ...)
    if not RPHomeDB.connection then return false end
    return dbExec(RPHomeDB.connection, sql, ...)
end

local function columnExists(tableName, columnName)
    for _, row in ipairs(rows("PRAGMA table_info(" .. tostring(tableName) .. ")")) do
        if row.name == columnName then return true end
    end
    return false
end

local function addColumn(tableName, columnName, definition)
    if not columnExists(tableName, columnName) then
        RPHomeDB.exec("ALTER TABLE " .. tostring(tableName) .. " ADD COLUMN " .. tostring(columnName) .. " " .. tostring(definition))
    end
end

function RPHomeDB.init()
    RPHomeDB.connection = dbConnect("sqlite", HomeConfig.database.file)
    if not RPHomeDB.connection then
        outputDebugString("[RPHome] SQLite connection failed.", 1)
        return false
    end

    RPHomeDB.exec([[
        CREATE TABLE IF NOT EXISTS houses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number INTEGER NOT NULL UNIQUE,
            district TEXT NOT NULL,
            interior_key TEXT NOT NULL,
            gov_price INTEGER NOT NULL,
            sale_price INTEGER DEFAULT 0,
            entrance_x REAL NOT NULL,
            entrance_y REAL NOT NULL,
            entrance_z REAL NOT NULL,
            entrance_rotation REAL DEFAULT 0,
            entrance_interior INTEGER DEFAULT 0,
            entrance_dimension INTEGER DEFAULT 0,
            spawn_x REAL,
            spawn_y REAL,
            spawn_z REAL,
            spawn_rotation REAL DEFAULT 0,
            spawn_cam_x REAL,
            spawn_cam_y REAL,
            spawn_cam_z REAL,
            spawn_look_x REAL,
            spawn_look_y REAL,
            spawn_look_z REAL,
            spawn_interior INTEGER DEFAULT 0,
            spawn_dimension INTEGER DEFAULT 0,
            spawn_configured INTEGER DEFAULT 0,
            property_type TEXT DEFAULT 'house',
            locked INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]])

    addColumn("houses", "spawn_x", "REAL")
    addColumn("houses", "spawn_y", "REAL")
    addColumn("houses", "spawn_z", "REAL")
    addColumn("houses", "spawn_rotation", "REAL DEFAULT 0")
    addColumn("houses", "spawn_cam_x", "REAL")
    addColumn("houses", "spawn_cam_y", "REAL")
    addColumn("houses", "spawn_cam_z", "REAL")
    addColumn("houses", "spawn_look_x", "REAL")
    addColumn("houses", "spawn_look_y", "REAL")
    addColumn("houses", "spawn_look_z", "REAL")
    addColumn("houses", "spawn_interior", "INTEGER DEFAULT 0")
    addColumn("houses", "spawn_dimension", "INTEGER DEFAULT 0")
    addColumn("houses", "spawn_configured", "INTEGER DEFAULT 0")
    addColumn("houses", "property_type", "TEXT DEFAULT 'house'")
    RPHomeDB.exec("UPDATE houses SET property_type = 'house' WHERE property_type IS NULL OR property_type = ''")
    RPHomeDB.exec([[
        UPDATE houses SET
            spawn_x = COALESCE(spawn_x, entrance_x),
            spawn_y = COALESCE(spawn_y, entrance_y),
            spawn_z = COALESCE(spawn_z, entrance_z),
            spawn_rotation = COALESCE(spawn_rotation, entrance_rotation),
            spawn_interior = COALESCE(spawn_interior, entrance_interior),
            spawn_dimension = COALESCE(spawn_dimension, entrance_dimension)
    ]])

    RPHomeDB.exec([[
        CREATE TABLE IF NOT EXISTS parking_spaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            house_id INTEGER NOT NULL,
            slot INTEGER NOT NULL,
            x REAL NOT NULL,
            y REAL NOT NULL,
            z REAL NOT NULL,
            rx REAL DEFAULT 0,
            ry REAL DEFAULT 0,
            rz REAL DEFAULT 0,
            interior INTEGER DEFAULT 0,
            dimension INTEGER DEFAULT 0,
            UNIQUE(house_id, slot)
        )
    ]])

    RPHomeDB.exec([[
        CREATE TABLE IF NOT EXISTS hotels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number INTEGER NOT NULL UNIQUE,
            district TEXT NOT NULL,
            daily_price INTEGER NOT NULL,
            entrance_x REAL NOT NULL,
            entrance_y REAL NOT NULL,
            entrance_z REAL NOT NULL,
            entrance_rotation REAL DEFAULT 0,
            entrance_interior INTEGER DEFAULT 0,
            entrance_dimension INTEGER DEFAULT 0,
            spawn_x REAL,
            spawn_y REAL,
            spawn_z REAL,
            spawn_rotation REAL DEFAULT 0,
            spawn_interior INTEGER DEFAULT 0,
            spawn_dimension INTEGER DEFAULT 0,
            locked INTEGER DEFAULT 0,
            tenant_account_id INTEGER DEFAULT 0,
            rent_started_at INTEGER DEFAULT 0,
            rent_expires_at INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]])

    addColumn("hotels", "locked", "INTEGER DEFAULT 0")

    RPHomeDB.exec([[
        CREATE TABLE IF NOT EXISTS hotel_parkings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hotel_id INTEGER NOT NULL UNIQUE,
            slot INTEGER DEFAULT 1,
            x REAL NOT NULL,
            y REAL NOT NULL,
            z REAL NOT NULL,
            rx REAL DEFAULT 0,
            ry REAL DEFAULT 0,
            rz REAL DEFAULT 0,
            interior INTEGER DEFAULT 0,
            dimension INTEGER DEFAULT 0
        )
    ]])

    RPHomeDB.exec([[
        CREATE TABLE IF NOT EXISTS admin_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            admin_name TEXT NOT NULL,
            house_id INTEGER,
            details TEXT,
            created_at INTEGER NOT NULL
        )
    ]])

    RPHomeDB.reload()
    return true
end

function RPHomeDB.reload()
    RPHomeDB.houses = {}
    RPHomeDB.parkings = {}
    RPHomeDB.hotels = {}
    RPHomeDB.hotelParkings = {}

    for _, row in ipairs(rows("SELECT * FROM houses ORDER BY number ASC")) do
        row.id = tonumber(row.id)
        row.number = tonumber(row.number)
        row.gov_price = tonumber(row.gov_price) or 0
        row.sale_price = tonumber(row.sale_price) or 0
        row.entrance_x = tonumber(row.entrance_x)
        row.entrance_y = tonumber(row.entrance_y)
        row.entrance_z = tonumber(row.entrance_z)
        row.entrance_rotation = tonumber(row.entrance_rotation) or 0
        row.entrance_interior = tonumber(row.entrance_interior) or 0
        row.entrance_dimension = tonumber(row.entrance_dimension) or 0
        row.spawn_x = tonumber(row.spawn_x) or row.entrance_x
        row.spawn_y = tonumber(row.spawn_y) or row.entrance_y
        row.spawn_z = tonumber(row.spawn_z) or row.entrance_z
        row.spawn_rotation = tonumber(row.spawn_rotation) or row.entrance_rotation
        row.spawn_cam_x = tonumber(row.spawn_cam_x)
        row.spawn_cam_y = tonumber(row.spawn_cam_y)
        row.spawn_cam_z = tonumber(row.spawn_cam_z)
        row.spawn_look_x = tonumber(row.spawn_look_x)
        row.spawn_look_y = tonumber(row.spawn_look_y)
        row.spawn_look_z = tonumber(row.spawn_look_z)
        row.spawn_interior = tonumber(row.spawn_interior) or row.entrance_interior
        row.spawn_dimension = tonumber(row.spawn_dimension) or row.entrance_dimension
        row.spawn_configured = tonumber(row.spawn_configured) == 1
        row.locked = tonumber(row.locked) == 1
        RPHomeDB.houses[row.id] = row
    end

    for _, row in ipairs(rows("SELECT * FROM parking_spaces ORDER BY house_id ASC, slot ASC")) do
        row.house_id = tonumber(row.house_id)
        row.slot = tonumber(row.slot)
        row.x, row.y, row.z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
        row.rx, row.ry, row.rz = tonumber(row.rx) or 0, tonumber(row.ry) or 0, tonumber(row.rz) or 0
        row.interior, row.dimension = tonumber(row.interior) or 0, tonumber(row.dimension) or 0
        RPHomeDB.parkings[row.house_id] = RPHomeDB.parkings[row.house_id] or {}
        RPHomeDB.parkings[row.house_id][row.slot] = row
    end

    for _, row in ipairs(rows("SELECT * FROM hotels ORDER BY number ASC")) do
        row.id = tonumber(row.id)
        row.number = tonumber(row.number)
        row.daily_price = tonumber(row.daily_price) or 0
        row.entrance_x = tonumber(row.entrance_x)
        row.entrance_y = tonumber(row.entrance_y)
        row.entrance_z = tonumber(row.entrance_z)
        row.entrance_rotation = tonumber(row.entrance_rotation) or 0
        row.entrance_interior = tonumber(row.entrance_interior) or 0
        row.entrance_dimension = tonumber(row.entrance_dimension) or 0
        row.spawn_x = tonumber(row.spawn_x) or row.entrance_x
        row.spawn_y = tonumber(row.spawn_y) or row.entrance_y
        row.spawn_z = tonumber(row.spawn_z) or row.entrance_z
        row.spawn_rotation = tonumber(row.spawn_rotation) or row.entrance_rotation
        row.spawn_interior = tonumber(row.spawn_interior) or row.entrance_interior
        row.spawn_dimension = tonumber(row.spawn_dimension) or row.entrance_dimension
        row.locked = tonumber(row.locked) == 1
        row.tenant_account_id = tonumber(row.tenant_account_id) or 0
        row.rent_started_at = tonumber(row.rent_started_at) or 0
        row.rent_expires_at = tonumber(row.rent_expires_at) or 0
        RPHomeDB.hotels[row.id] = row
    end

    for _, row in ipairs(rows("SELECT * FROM hotel_parkings ORDER BY hotel_id ASC")) do
        row.hotel_id = tonumber(row.hotel_id)
        row.house_id = -row.hotel_id
        row.slot = 1
        row.x, row.y, row.z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
        row.rx, row.ry, row.rz = tonumber(row.rx) or 0, tonumber(row.ry) or 0, tonumber(row.rz) or 0
        row.interior, row.dimension = tonumber(row.interior) or 0, tonumber(row.dimension) or 0
        RPHomeDB.hotelParkings[row.hotel_id] = row
    end
end

function RPHomeDB.createHouse(data, parkings)
    local created = stamp()
    local ok = RPHomeDB.exec([[
        INSERT INTO houses (
            number, district, interior_key, gov_price, sale_price,
            entrance_x, entrance_y, entrance_z, entrance_rotation,
            entrance_interior, entrance_dimension,
            spawn_x, spawn_y, spawn_z, spawn_rotation,
            spawn_cam_x, spawn_cam_y, spawn_cam_z, spawn_look_x, spawn_look_y, spawn_look_z,
            spawn_interior, spawn_dimension,
            spawn_configured, locked, created_at, updated_at
        ) VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ]], data.number, data.district, data.interior_key, data.gov_price, data.x, data.y, data.z, data.rotation, data.interior, data.dimension,
        data.spawn_x or data.x, data.spawn_y or data.y, data.spawn_z or data.z, data.spawn_rotation or data.rotation,
        data.spawn_cam_x, data.spawn_cam_y, data.spawn_cam_z, data.spawn_look_x, data.spawn_look_y, data.spawn_look_z,
        data.spawn_interior or data.interior, data.spawn_dimension or data.dimension,
        data.spawn_configured and 1 or 0, created, created)

    if not ok then return false end
    local row = rows("SELECT id FROM houses WHERE number = ? LIMIT 1", data.number)[1]
    if not row then return false end
    local houseId = tonumber(row.id)
    RPHomeDB.replaceParkings(houseId, parkings or {})
    RPHomeDB.reload()
    return houseId
end

function RPHomeDB.replaceParkings(houseId, parkings)
    houseId = tonumber(houseId)
    if not houseId then return false end
    RPHomeDB.exec("DELETE FROM parking_spaces WHERE house_id = ?", houseId)
    for index, parking in ipairs(parkings or {}) do
        RPHomeDB.exec([[
            INSERT INTO parking_spaces (house_id, slot, x, y, z, rx, ry, rz, interior, dimension)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], houseId, index, parking.x, parking.y, parking.z, parking.rx or 0, parking.ry or 0, parking.rz or 0, parking.interior or 0, parking.dimension or 0)
    end
    RPHomeDB.reload()
    return true
end

function RPHomeDB.createHotel(data, parking)
    local created = stamp()
    local ok = RPHomeDB.exec([[
        INSERT INTO hotels (
            number, district, daily_price,
            entrance_x, entrance_y, entrance_z, entrance_rotation, entrance_interior, entrance_dimension,
            spawn_x, spawn_y, spawn_z, spawn_rotation, spawn_interior, spawn_dimension,
            tenant_account_id, rent_started_at, rent_expires_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?)
    ]], data.number, data.district, data.daily_price,
        data.x, data.y, data.z, data.rotation or 0, data.interior or 0, data.dimension or 0,
        data.spawn_x or data.x, data.spawn_y or data.y, data.spawn_z or data.z, data.spawn_rotation or data.rotation or 0,
        data.spawn_interior or data.interior or 0, data.spawn_dimension or data.dimension or 0,
        created, created)
    if not ok then return false end
    local row = rows("SELECT id FROM hotels WHERE number = ? LIMIT 1", data.number)[1]
    if not row then return false end
    local hotelId = tonumber(row.id)
    RPHomeDB.replaceHotelParking(hotelId, parking)
    RPHomeDB.reload()
    return hotelId
end

function RPHomeDB.replaceHotelParking(hotelId, parking)
    hotelId = tonumber(hotelId)
    if not hotelId or type(parking) ~= "table" then return false end
    RPHomeDB.exec("DELETE FROM hotel_parkings WHERE hotel_id = ?", hotelId)
    RPHomeDB.exec([[
        INSERT INTO hotel_parkings (hotel_id, slot, x, y, z, rx, ry, rz, interior, dimension)
        VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], hotelId, parking.x, parking.y, parking.z, parking.rx or 0, parking.ry or 0, parking.rz or 0, parking.interior or 0, parking.dimension or 0)
    RPHomeDB.reload()
    return true
end

function RPHomeDB.log(action, adminName, houseId, details)
    return RPHomeDB.exec("INSERT INTO admin_logs (action, admin_name, house_id, details, created_at) VALUES (?, ?, ?, ?, ?)", tostring(action), tostring(adminName or "Console"), tonumber(houseId) or 0, tostring(details or ""), stamp())
end
