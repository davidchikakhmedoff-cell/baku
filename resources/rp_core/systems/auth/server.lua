local db
local pendingSpawns = {}

local function validRPName(name)
    return type(name) == "string" and name:match("^[A-Z][a-z]+_[A-Z][a-z]+$") ~= nil
end

local function normalizeLegacyRPName(name)
    if type(name) ~= "string" then return name end
    return name:gsub(" ", "_")
end

local function validPassword(password)
    return type(password) == "string" and #password >= AuthConfig.input.passwordMin and #password <= AuthConfig.input.passwordMax
end

local function passwordHash(password, serial)
    local salt = AuthConfig.passwordSalt or AuthConfig.resourceName
    return hash("sha256", tostring(password) .. ":" .. tostring(serial) .. ":" .. salt)
end

local function verifyAccountPassword(row,password,currentSerial)
    -- Login device and the serial used to salt the credential are independent.
    -- The current-device candidate can recover a legacy credential whose serial
    -- was overwritten by a previous login from another computer.
    for _, serial in ipairs({row.password_serial or row.serial,row.serial,currentSerial}) do
        if row.password == passwordHash(password,serial) then return true,serial end
    end
    return false
end

local function now()
    return getRealTime().timestamp
end

local function formatBanMessage(row)
    if type(row) ~= "table" then return tostring(row or "Ваш аккаунт заблокирован.") end
    local reason = row.reason or "Причина не указана"
    local admin = row.admin_name or "Console"
    local expires = row.expires_at and tonumber(row.expires_at) and os.date("%Y-%m-%d %H:%M:%S", tonumber(row.expires_at)) or "Бессрочно"
    return "Доступ запрещён. Бан выдал: " .. tostring(admin) .. ". Причина: " .. tostring(reason) .. ". До: " .. tostring(expires) .. "."
end

function AuthDBQuery(sql, ...)
    if not db then return {} end
    local handle = dbQuery(db, sql, ...)
    return dbPoll(handle, -1) or {}
end

function AuthDBExec(sql, ...)
    if not db then return false end
    return dbExec(db, sql, ...)
end

local function query(sql, ...)
    return AuthDBQuery(sql, ...)
end

local function queryOne(sql, ...)
    return query(sql, ...)[1]
end

local function columnExists(name)
    for _, row in ipairs(query("PRAGMA table_info(players)")) do
        if row.name == name then return true end
    end
    return false
end

local function addColumn(name, definition)
    if not columnExists(name) then
        dbExec(db, "ALTER TABLE players ADD COLUMN " .. name .. " " .. definition)
    end
end

local function createPlayersTable(tableName)
    return dbExec(db, string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rp_name TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            serial TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            last_login INTEGER NOT NULL,
            pos_x REAL,
            pos_y REAL,
            pos_z REAL,
            rotation REAL,
            interior INTEGER DEFAULT 0,
            dimension INTEGER DEFAULT 0,
            health REAL DEFAULT 100,
            armor REAL DEFAULT 0,
            money INTEGER DEFAULT 0,
            skin INTEGER DEFAULT 0,
            weapons TEXT,
            has_position INTEGER DEFAULT 0,
            last_position_at INTEGER DEFAULT 0,
            gender TEXT DEFAULT 'male',
            level INTEGER DEFAULT 1,
            experience INTEGER DEFAULT 0,
            house_id INTEGER DEFAULT 0
        )
    ]], tableName))
end

local function migrateLegacyLoginColumn()
    if not columnExists("login") then return end

    dbExec(db, "DROP TABLE IF EXISTS players_rp_migration")
    if not createPlayersTable("players_rp_migration") then return end

    local copied = dbExec(db, [[
        INSERT OR IGNORE INTO players_rp_migration (
            id, rp_name, password, serial, created_at, last_login,
            pos_x, pos_y, pos_z, rotation, interior, dimension,
            health, armor, money, skin, weapons, has_position,
            last_position_at, gender, level, experience, house_id
        )
        SELECT
            id,
            REPLACE(COALESCE(NULLIF(rp_name, ''), login), ' ', '_'),
            password,
            serial,
            created_at,
            last_login,
            pos_x,
            pos_y,
            pos_z,
            rotation,
            interior,
            dimension,
            health,
            armor,
            money,
            skin,
            weapons,
            has_position,
            COALESCE(last_position_at, 0),
            COALESCE(NULLIF(gender, ''), 'male'),
            COALESCE(level, 1),
            COALESCE(experience, 0),
            COALESCE(house_id, 0)
        FROM players
    ]])

    if not copied then
        dbExec(db, "DROP TABLE IF EXISTS players_rp_migration")
        outputDebugString("[Auth] Legacy players table migration failed.", 1)
        return
    end

    dbExec(db, "DROP TABLE players")
    dbExec(db, "ALTER TABLE players_rp_migration RENAME TO players")
end

local function initDatabase()
    db = dbConnect("sqlite", AuthConfig.database.file)
    if not db then
        outputDebugString("[Auth] SQLite connection failed.", 1)
        return false
    end

    createPlayersTable("players")

    addColumn("pos_x", "REAL")
    addColumn("pos_y", "REAL")
    addColumn("pos_z", "REAL")
    addColumn("rotation", "REAL")
    addColumn("interior", "INTEGER DEFAULT 0")
    addColumn("dimension", "INTEGER DEFAULT 0")
    addColumn("health", "REAL DEFAULT 100")
    addColumn("armor", "REAL DEFAULT 0")
    addColumn("money", "INTEGER DEFAULT 0")
    addColumn("skin", "INTEGER DEFAULT 0")
    addColumn("weapons", "TEXT")
    addColumn("has_position", "INTEGER DEFAULT 0")
    addColumn("last_position_at", "INTEGER DEFAULT 0")
    addColumn("rp_name", "TEXT")
    addColumn("gender", "TEXT DEFAULT 'male'")
    addColumn("level", "INTEGER DEFAULT 1")
    addColumn("experience", "INTEGER DEFAULT 0")
    addColumn("house_id", "INTEGER DEFAULT 0")
    dbExec(db, "UPDATE players SET rp_name = REPLACE(rp_name, ' ', '_') WHERE rp_name LIKE '% %'")
    migrateLegacyLoginColumn()
    addColumn("password_serial", "TEXT")
    dbExec(db, "UPDATE players SET password_serial = serial WHERE password_serial IS NULL OR password_serial = ''")
    addColumn("last_position_at", "INTEGER DEFAULT 0")
    addColumn("house_id", "INTEGER DEFAULT 0")
    return true
end

local function getRandomSkin(gender)
    local list = AuthConfig.skins[gender == "female" and "female" or "male"] or AuthConfig.skins.male
    if not list or #list == 0 then return AuthConfig.spawn.skin end
    return tonumber(list[math.random(1, #list)]) or AuthConfig.spawn.skin
end

local function factionValue(player,method)
    local resource=getResourceFromName('rp_fraction')
    if not resource or getResourceState(resource)~='running' then return nil end
    local ok,value=pcall(call,resource,method,player)
    return ok and value or nil
end

local function getPlayerWeapons(player)
    local civilian=factionValue(player,"getCivilianWeapons")
    if type(civilian)=="string" then return civilian end
    local weapons = {}
    for slot = 0, 12 do
        local weapon = getPedWeapon(player, slot)
        local ammo = getPedTotalAmmo(player, slot)
        if weapon and weapon > 0 and ammo and ammo > 0 then
            weapons[#weapons + 1] = { weapon = weapon, ammo = ammo }
        end
    end
    return toJSON(weapons, true)
end

local function restoreWeapons(player, weaponsJson)
    takeAllWeapons(player)
    if not weaponsJson or weaponsJson == "" then return end

    local weapons = fromJSON(weaponsJson)
    if type(weapons) ~= "table" then return end

    for _, item in ipairs(weapons) do
        if item.weapon and item.ammo then
            giveWeapon(player, tonumber(item.weapon), tonumber(item.ammo), false)
        end
    end
end

local function applyPlayerState(player, row)
    setElementHealth(player, tonumber(row.health) or 100)
    setPedArmor(player, tonumber(row.armor) or 0)
    setPlayerMoney(player, tonumber(row.money) or 0)
    restoreWeapons(player, row.weapons)
end

local function spawnAt(player, data)
    spawnPlayer(player, data.x, data.y, data.z, data.rotation, data.skin, data.interior, data.dimension)
    setPedRotation(player, data.rotation)
    setElementInterior(player, data.interior)
    setElementDimension(player, data.dimension)
    fadeCamera(player, true, 0)
    setCameraTarget(player, player)
    toggleAllControls(player, true)
end

local function getHouseSpawnForPlayer(player)
    if getResourceFromName("rp_home") and getResourceState(getResourceFromName("rp_home")) == "running" then
        return exports.rp_home:getPlayerSpawnHousePosition(player)
    end
    return false
end

local function spawnAuthorizedPlayer(player, row)
    local savedAt = tonumber(row.last_position_at) or 0
    local canUseSavedPosition = tonumber(row.has_position) == 1 and row.pos_x and row.pos_y and row.pos_z and savedAt > 0 and (now() - savedAt) <= 600

    if canUseSavedPosition then
        spawnAt(player, {
            x = tonumber(row.pos_x),
            y = tonumber(row.pos_y),
            z = tonumber(row.pos_z),
            rotation = tonumber(row.rotation) or AuthConfig.spawn.rotation,
            skin = tonumber(row.skin) or AuthConfig.spawn.skin,
            interior = tonumber(row.interior) or AuthConfig.spawn.interior,
            dimension = tonumber(row.dimension) or AuthConfig.spawn.dimension
        })
        applyPlayerState(player, row)
        return false
    end

    local houseSpawn = getHouseSpawnForPlayer(player)

    if type(houseSpawn) == "table" and houseSpawn.x and houseSpawn.y and houseSpawn.z then
        spawnAt(player, {
            x = tonumber(houseSpawn.x),
            y = tonumber(houseSpawn.y),
            z = tonumber(houseSpawn.z),
            rotation = tonumber(houseSpawn.rotation) or AuthConfig.spawn.rotation,
            skin = tonumber(row.skin) or AuthConfig.spawn.skin,
            interior = tonumber(houseSpawn.interior) or 0,
            dimension = tonumber(houseSpawn.dimension) or 0,
            camera = houseSpawn.camera
        })
        applyPlayerState(player, row)
        return houseSpawn.camera
    end

    local s = AuthConfig.spawn
    spawnAt(player, { x = s.x, y = s.y, z = s.z, rotation = s.rotation, skin = tonumber(row.skin) or s.skin, interior = s.interior, dimension = s.dimension })
    applyPlayerState(player, row)
    return false
end

local function getPlayerId(player)
    return getElementData(player, "auth:playerId")
end

local function savePlayerState(player)
    local id = getPlayerId(player)
    if not db or not id or not isElement(player) then return false end

    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    return dbExec(db, [[
        UPDATE players SET
            pos_x = ?, pos_y = ?, pos_z = ?, rotation = ?, interior = ?, dimension = ?,
            health = ?, armor = ?, money = ?, skin = ?, weapons = ?, has_position = 1, last_position_at = ?
        WHERE id = ?
    ]], x, y, z, rz, getElementInterior(player), getElementDimension(player), getElementHealth(player), getPedArmor(player), getPlayerMoney(player), tonumber(factionValue(player,"getCivilianSkin")) or getElementModel(player), getPlayerWeapons(player), now(), id)
end

local function finishSession(player)
    pendingSpawns[player] = nil
    savePlayerState(player)
    removeElementData(player, "auth:loggedIn")
    removeElementData(player, "auth:rpName")
    removeElementData(player, "auth:playerId")
end

local function setSessionData(player, row)
    local rpName = row.rp_name
    setElementData(player, "auth:loggedIn", true, false)
    setElementData(player, "auth:rpName", rpName, false)
    setElementData(player, "auth:playerId", row.id, false)
    setElementData(player, "auth:houseId", tonumber(row.house_id) or 0, true)
end

-- Account identity belongs to the server. Other resources (including factions)
-- use these fields through the auth exports; reject client element-data edits.
local protectedSessionKeys={['auth:playerId']=true,['auth:loggedIn']=true,['auth:rpName']=true,['auth:houseId']=true}
addEventHandler('onElementDataChange',root,function(key,oldValue)
    if not client or not protectedSessionKeys[key] then return end
    if oldValue==nil then removeElementData(source,key)
    else setElementData(source,key,oldValue,key=='auth:houseId') end
end,true,'high+100')

function getAuthPlayerId(player)
    return getPlayerId(player)
end

function getAuthPlayerHouseId(player)
    return tonumber(getElementData(player, "auth:houseId")) or 0
end

function getAuthAccountHouseId(accountId)
    local row = queryOne("SELECT house_id FROM players WHERE id = ? LIMIT 1", tonumber(accountId) or 0)
    return row and (tonumber(row.house_id) or 0) or 0
end

function getAuthHouseOwnerAccountId(houseId)
    local row = queryOne("SELECT id FROM players WHERE house_id = ? LIMIT 1", tonumber(houseId) or 0)
    return row and tonumber(row.id) or false
end

function getAuthAccountName(accountId)
    local row = queryOne("SELECT rp_name FROM players WHERE id = ? LIMIT 1", tonumber(accountId) or 0)
    return row and row.rp_name or false
end

function setAuthPlayerHouseId(playerOrAccountId, houseId)
    houseId = math.max(0, math.floor(tonumber(houseId) or 0))
    local accountId = tonumber(playerOrAccountId)

    if isElement(playerOrAccountId) and getElementType(playerOrAccountId) == "player" then
        accountId = getPlayerId(playerOrAccountId)
        setElementData(playerOrAccountId, "auth:houseId", houseId, true)
    end

    if not accountId then return false end
    for _, player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player, "auth:playerId")) == accountId then
            setElementData(player, "auth:houseId", houseId, true)
        end
    end
    return AuthDBExec("UPDATE players SET house_id = ? WHERE id = ?", houseId, accountId)
end

function addAuthAccountMoney(accountId, amount)
    accountId = tonumber(accountId)
    amount = math.floor(tonumber(amount) or 0)
    if not accountId then return false, "invalid_account" end
    if amount == 0 then
        local row = queryOne("SELECT money FROM players WHERE id = ? LIMIT 1", accountId)
        return row ~= nil, row and (tonumber(row.money) or 0) or "account_not_found"
    end

    for _, player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player, "auth:playerId")) == accountId then
            local currentBalance = math.max(0, math.floor(tonumber(getPlayerMoney(player)) or 0))
            local newBalance = math.max(0, currentBalance + amount)
            local ok = AuthDBExec("UPDATE players SET money = ? WHERE id = ?", newBalance, accountId)
            if not ok then return false, "db_update_failed" end

            setPlayerMoney(player, newBalance)
            triggerClientEvent(player, "rp:hud:update", resourceRoot, { money = newBalance })
            return true, newBalance
        end
    end

    local ok = AuthDBExec("UPDATE players SET money = MAX(0, COALESCE(money, 0) + ?) WHERE id = ?", amount, accountId)
    if not ok then return false, "db_update_failed" end
    local row = queryOne("SELECT money FROM players WHERE id = ? LIMIT 1", accountId)
    return true, row and (tonumber(row.money) or 0) or 0
end

function getAuthPlayerBalance(player)
    if not isElement(player) or getElementType(player) ~= "player" or not getPlayerId(player) then return false end
    return getPlayerMoney(player) or 0
end

function giveAuthPlayerMoney(player, amount)
    if not isElement(player) or getElementType(player) ~= "player" or not getPlayerId(player) then return false, "player_not_authorized" end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "invalid_amount" end
    return addAuthAccountMoney(getPlayerId(player), amount)
end

function takeAuthPlayerMoney(player, amount)
    if not isElement(player) or getElementType(player) ~= "player" or not getPlayerId(player) then return false, "player_not_authorized" end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "invalid_amount" end
    if (getPlayerMoney(player) or 0) < amount then return false, "not_enough_money" end
    return addAuthAccountMoney(getPlayerId(player), -amount)
end

function getCoreAdminLevel(player)
    if AdminCore and AdminCore.getAdminLevel then
        return tonumber(AdminCore.getAdminLevel(player)) or 0
    end
    return 0
end

local function respawnAtHospital(player)
    if not isElement(player) then return end
    if factionValue(player,"applyFactionJail")==true then return end
    if not isElement(player) or not getPlayerId(player) then return end

    local custom = factionValue(player,"getHospitalRespawnLocation")
    local h = type(custom)=="table" and custom or AuthConfig.hospital
    spawnAt(player, { x = h.x, y = h.y, z = h.z, rotation = h.rotation or 0, skin = getElementModel(player) or h.skin, interior = h.interior, dimension = h.dimension })
    setElementHealth(player, 20)
    setPedArmor(player, 0)
    fadeCamera(player, true, 0)
    setCameraTarget(player, player)
    if custom then factionValue(player,"completeHospitalRespawn") end
    savePlayerState(player)
end

addEventHandler("onResourceStart", resourceRoot, function()
    math.randomseed(getTickCount())
    initDatabase()
end)

addEvent("auth:login", true)
addEventHandler("auth:login", root, function(rpName, password, remember)
    if client ~= source then return end
    if not db then triggerClientEvent(client, "auth:response", resourceRoot, false, "База данных недоступна."); return end
    if not validRPName(rpName) or not validPassword(password) then triggerClientEvent(client, "auth:response", resourceRoot, false, "Проверьте имя персонажа и пароль."); return end

    if RPBans and RPBans.isPlayerBanned then
        local banned, ban = RPBans.isPlayerBanned(rpName, getPlayerSerial(client))
        if banned then
            local message = formatBanMessage(ban)
            triggerClientEvent(client, "auth:response", resourceRoot, false, message)
            return
        end
    end

    local row = queryOne("SELECT * FROM players WHERE rp_name = ? LIMIT 1", rpName)
    if not row then triggerClientEvent(client, "auth:response", resourceRoot, false, "Аккаунт не найден."); return end
    local valid,credentialSerial=verifyAccountPassword(row,password,getPlayerSerial(client))
    if not valid then triggerClientEvent(client, "auth:response", resourceRoot, false, "Неверное имя персонажа или пароль."); return end

    dbExec(db, "UPDATE players SET last_login = ?, serial = ?, rp_name = ?, password_serial = ? WHERE id = ?", now(), getPlayerSerial(client), rpName, credentialSerial, row.id)
    row.rp_name = rpName
    setSessionData(client, row)
    pendingSpawns[client] = row
    triggerClientEvent(client, "auth:response", resourceRoot, true, "Добро пожаловать!", remember and rpName or false)
end)

-- Recovery requires access to the server console, never an in-game client.
addCommandHandler('authreset',function(player,_,rpName,password)
    if isElement(player) then return end
    if not validRPName(rpName) or not validPassword(password) then
        outputServerLog('Usage: authreset Name_Surname NEW_PASSWORD (server console only)');return
    end
    local row=queryOne('SELECT * FROM players WHERE rp_name=? LIMIT 1',rpName)
    if not row then outputServerLog('[Auth] Account not found');return end
    if not AuthDBExec('UPDATE players SET password=?,password_serial=? WHERE id=?',passwordHash(password,row.serial),row.serial,row.id) then
        outputServerLog('[Auth] Password recovery failed');return
    end
    outputServerLog('[Auth] Password updated for '..rpName..'. Account ID and game data preserved.')
end)

addEvent("auth:register", true)
addEventHandler("auth:register", root, function(rpName, password, repeatPassword, remember, gender)
    if client ~= source then return end
    if not db then triggerClientEvent(client, "auth:response", resourceRoot, false, "База данных недоступна."); return end
    if not validRPName(rpName) then triggerClientEvent(client, "auth:response", resourceRoot, false, "Введите имя персонажа в формате Name_Surname."); return end
    if not validPassword(password) then triggerClientEvent(client, "auth:response", resourceRoot, false, "Пароль должен быть от 6 до 32 символов."); return end
    if password ~= repeatPassword then triggerClientEvent(client, "auth:response", resourceRoot, false, "Пароли не совпадают."); return end
    gender = gender == "female" and "female" or "male"
    if queryOne("SELECT id FROM players WHERE rp_name = ? LIMIT 1", rpName) then triggerClientEvent(client, "auth:response", resourceRoot, false, "Такое имя персонажа уже существует."); return end

    if RPBans and RPBans.isPlayerBanned then
        local banned, ban = RPBans.isPlayerBanned(rpName, getPlayerSerial(client))
        if banned then
            local message = formatBanMessage(ban)
            triggerClientEvent(client, "auth:response", resourceRoot, false, message)
            return
        end
    end

    local serial, stamp = getPlayerSerial(client), now()
    local skin = getRandomSkin(gender)
    local ok = dbExec(db, "INSERT INTO players (rp_name, password, serial, created_at, last_login, skin, gender, level, experience) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", rpName, passwordHash(password, serial), serial, stamp, stamp, skin, gender, 1, 0)
    if ok then
        local row = queryOne("SELECT * FROM players WHERE rp_name = ? LIMIT 1", rpName)
        setSessionData(client, row)
        pendingSpawns[client] = row
        triggerClientEvent(client, "auth:response", resourceRoot, true, "Аккаунт создан!", remember and rpName or false)
        return
    end
    if not ok then triggerClientEvent(client, "auth:response", resourceRoot, false, "Не удалось создать аккаунт."); return end
end)

addEvent("auth:spawnReady", true)
addEventHandler("auth:spawnReady", root, function()
    print("[Auth] auth:spawnReady получено, client = " .. tostring(client))
    if client ~= source then 
        print("[Auth] ОШИБКА: client != source")
        return 
    end

    local row = pendingSpawns[client]
    if not row or not getPlayerId(client) then 
        print("[Auth] ОШИБКА: row or playerId not found")
        return 
    end

    print("[Auth] Спавнираю игрока и триггерю auth:spawned")
    pendingSpawns[client] = nil
    local rpName = row.rp_name
    if rpName then setPlayerRPNickname(client, rpName) end
    triggerEvent("rp:onPlayerReady", root, client, row)
    local spawnCamera = spawnAuthorizedPlayer(client, row)
    
    -- Отправляем событие и клиенту, и серверу (для HUD и других систем)
    print("[Auth] Триггерю triggerClientEvent auth:spawned")
    triggerClientEvent(client, "auth:spawned", resourceRoot)
    if type(spawnCamera) == "table" then
        triggerClientEvent(client, "auth:applySpawnCamera", resourceRoot, spawnCamera)
    end
    
    print("[Auth] Триггерю triggerEvent auth:spawned на root с client = " .. tostring(client))
    triggerEvent("auth:spawned", root, client)
    print("[Auth] auth:spawned триггернут успешно")
end)

addEventHandler("onPlayerWasted", root, function()
    fadeCamera(source, true, 0)
    setTimer(respawnAtHospital, 3000, 1, source)
end)

addEventHandler("onPlayerQuit", root, function()
    finishSession(source)
end)

addEventHandler("onPlayerJoin", root, function()
    fadeCamera(source, true, 0)
    toggleAllControls(source, false, true, false)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        if getPlayerId(player) then
            finishSession(player)
        end
    end
end)
