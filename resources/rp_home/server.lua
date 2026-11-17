local controlMarkers = {}
local pendingEntrances = {}
local pendingHotelEntrances = {}

local function debugHome(message)
    if HomeConfig.DebugMode then
        outputDebugString("[RP HOME] " .. tostring(message), 3)
    end
end

local function homeConfig()
    return HomeSystemConfig or HomeConfig
end

local function hotelConfig()
    return HotelSystemConfig or {}
end

local function hotelInteriorConfig()
    return hotelConfig().interior or HomeConfig.hotelInterior or {}
end

local function markerKey(kind, id)
    return tostring(kind) .. ":" .. tostring(tonumber(id) or id)
end

local function coreRunning()
    local core = getResourceFromName("rp_core")
    return core and getResourceState(core) == "running"
end

local function carResourceRunning()
    local car = getResourceFromName("rp_car")
    return car and getResourceState(car) == "running"
end

local function notify(player, text, good)
    local c = good and HomeConfig.colors.green or HomeConfig.colors.red
    if coreRunning() then
        exports.rp_core:sendCoreNotification(player, text, c[1], c[2], c[3])
    else
        outputDebugString("[RP Home] Уведомление не отправлено: rp_core не запущен.", 2)
    end
end

local function isLogged(player)
    return isElement(player) and getElementData(player, "auth:loggedIn") == true
end

local function accountId(player)
    if coreRunning() then return tonumber(exports.rp_core:getAuthPlayerId(player)) end
    return tonumber(getElementData(player, "auth:playerId"))
end

local function playerHouseId(player)
    if coreRunning() then return tonumber(exports.rp_core:getAuthPlayerHouseId(player)) or 0 end
    return tonumber(getElementData(player, "auth:houseId")) or 0
end

local function ownerAccountId(houseId)
    if not coreRunning() then return false end
    return exports.rp_core:getAuthHouseOwnerAccountId(tonumber(houseId) or 0)
end

local function accountName(id)
    if not id or not coreRunning() then return "РќРµС‚" end
    return exports.rp_core:getAuthAccountName(id) or ("ID " .. tostring(id))
end

local function setAccountHouse(playerOrId, houseId)
    if not coreRunning() then return false end
    return exports.rp_core:setAuthPlayerHouseId(playerOrId, tonumber(houseId) or 0)
end

local function notifyCarHouseDetached(houseId, ownerId, reason)
    if not carResourceRunning() then return end
    local ok = pcall(function()
        exports.rp_car:releaseHouseVehicles(tonumber(houseId) or 0, tonumber(ownerId) or 0, tostring(reason or "house_detached"))
    end)
    if not ok then
        triggerEvent("car:onHouseDetached", resourceRoot, tonumber(houseId) or 0, tonumber(ownerId) or 0, tostring(reason or "house_detached"))
    end
end

local function notifyCarHouseAttached(houseId, ownerId, reason)
    if not carResourceRunning() then return end
    pcall(function()
        exports.rp_car:assignHouseVehicles(tonumber(ownerId) or 0, tonumber(houseId) or 0, tostring(reason or "house_attached"))
    end)
end

local function clearHouseOwner(houseId)
    local ownerId = ownerAccountId(houseId)
    if ownerId then
        setAccountHouse(ownerId, 0)
        notifyCarHouseDetached(houseId, ownerId, "house_cleared")
    end
    return ownerId
end

local function validatePlayerHouse(player)
    local houseId = playerHouseId(player)
    if houseId > 0 and not RPHomeDB.houses[houseId] then
        setAccountHouse(player, 0)
        notify(player, "РџСЂРёРІСЏР·РєР° Рє СѓРґР°Р»С‘РЅРЅРѕРјСѓ РґРѕРјСѓ РѕС‡РёС‰РµРЅР°.", true)
        return false
    end
    return houseId > 0
end

local function cleanupInvalidAccountHouseIds()
    if not coreRunning() then return end
    local rows = exports.rp_core:AuthDBQuery("SELECT id, house_id FROM players WHERE COALESCE(house_id, 0) > 0") or {}
    local cleared = 0
    for _, row in ipairs(rows) do
        local houseId = tonumber(row.house_id) or 0
        if houseId > 0 and not RPHomeDB.houses[houseId] then
            if setAccountHouse(tonumber(row.id), 0) then cleared = cleared + 1 end
        end
    end
    if cleared > 0 then
        outputDebugString("[RPHome] Cleared " .. tostring(cleared) .. " invalid house_id value(s).", 3)
    end
end

local function addAccountMoney(id, amount)
    if not coreRunning() then return false end
    return exports.rp_core:addAuthAccountMoney(id, amount)
end

local function changePlayerMoneyCore(player, amount)
    if not coreRunning() or not isElement(player) then return false, "core_or_player_unavailable" end
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then
        local ok, result, extra = pcall(function()
            return exports.rp_core:giveAuthPlayerMoney(player, amount)
        end)
        if not ok then return false, tostring(result) end
        return result == true, extra
    elseif amount < 0 then
        local ok, result, extra = pcall(function()
            return exports.rp_core:takeAuthPlayerMoney(player, math.abs(amount))
        end)
        if not ok then return false, tostring(result) end
        return result == true, extra
    end
    return false, "zero_amount"
end

local function playerBalance(player)
    if coreRunning() then
        local ok, balance = pcall(function()
            return exports.rp_core:getAuthPlayerBalance(player)
        end)
        if ok then return tonumber(balance) or 0 end
    end
    return tonumber(getPlayerMoney(player)) or 0
end

local function isAdmin(player)
    if not coreRunning() then return false end
    if exports.rp_core.hasAdminPermission then
        local ok, allowed = pcall(function()
            return exports.rp_core:hasAdminPermission(player, "adminHouses")
        end)
        if ok then return allowed == true end
    end
    return (tonumber(exports.rp_core:getCoreAdminLevel(player)) or 0) >= 10
end

local function playerHasHouseKey(player, houseId)
    -- Reserved for future key system integration.
    return false
end

local function adminName(player)
    return getElementData(player, "rp:name") or getElementData(player, "auth:rpName") or getPlayerName(player) or "Console"
end

local function getHouseStatus(houseId)
    local owner = ownerAccountId(houseId)
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not owner then return "free" end
    if house and (tonumber(house.sale_price) or 0) > 0 then return "sale" end
    return "owned"
end

local makeHotelDimension
local propertyPublicId
local hotelFromPublicId
local nowStamp
local isHotelRentActive

local function publicHouse(house)
    if not house then return nil end
    local interior = (homeConfig().getInterior or HomeConfig.getInterior)(house.interior_key)
    local owner = ownerAccountId(house.id)
    local parkings = RPHomeDB.parkings[house.id] or {}
    local count = 0
    for _ in pairs(parkings) do count = count + 1 end
    local parkingList = {}
    for _, row in pairs(parkings) do
        parkingList[#parkingList + 1] = {
            slot = row.slot,
            x = row.x, y = row.y, z = row.z,
            rx = row.rx, ry = row.ry, rz = row.rz,
            interior = row.interior,
            dimension = row.dimension
        }
    end
    table.sort(parkingList, function(a, b) return a.slot < b.slot end)

    return {
        id = house.id,
        property_type = "house",
        number = house.number,
        district = house.district,
        interior_key = house.interior_key,
        interior_name = interior and interior.name or house.interior_key,
        house_class = interior and interior.class or "-",
        house_class_name = interior and interior.className or (interior and interior.name or house.interior_key),
        gov_price = house.gov_price,
        sale_price = house.sale_price,
        x = house.entrance_x,
        y = house.entrance_y,
        z = house.entrance_z,
        rotation = house.entrance_rotation,
        interior = house.entrance_interior,
        dimension = house.entrance_dimension,
        spawn_x = house.spawn_x,
        spawn_y = house.spawn_y,
        spawn_z = house.spawn_z,
        spawn_rotation = house.spawn_rotation,
        spawn_cam_x = house.spawn_cam_x,
        spawn_cam_y = house.spawn_cam_y,
        spawn_cam_z = house.spawn_cam_z,
        spawn_look_x = house.spawn_look_x,
        spawn_look_y = house.spawn_look_y,
        spawn_look_z = house.spawn_look_z,
        spawn_interior = house.spawn_interior,
        spawn_dimension = house.spawn_dimension,
        spawn_configured = house.spawn_configured,
        locked = house.locked,
        owner_account_id = owner or 0,
        owner_name = owner and accountName(owner) or "Государство",
        parking_count = count,
        parkings = parkingList,
        status = getHouseStatus(house.id)
    }
end

local function publicHotel(hotel, viewer)
    if not hotel then return nil end
    local rented = isHotelRentActive(hotel)
    local parking = RPHomeDB.hotelParkings[hotel.id]
    local parkingList = {}
    if parking then
        parkingList[1] = {
            slot = 1,
            x = parking.x, y = parking.y, z = parking.z,
            rx = parking.rx, ry = parking.ry, rz = parking.rz,
            interior = parking.interior,
            dimension = parking.dimension,
            house_id = propertyPublicId("hotel", hotel.id)
        }
    end
    return {
        id = propertyPublicId("hotel", hotel.id),
        hotel_id = hotel.id,
        property_type = "hotel",
        number = hotel.number,
        district = hotel.district,
        daily_price = hotel.daily_price,
        gov_price = hotel.daily_price,
        sale_price = 0,
        x = hotel.entrance_x,
        y = hotel.entrance_y,
        z = hotel.entrance_z,
        rotation = hotel.entrance_rotation,
        interior = hotel.entrance_interior,
        dimension = hotel.entrance_dimension,
        spawn_x = hotel.spawn_x,
        spawn_y = hotel.spawn_y,
        spawn_z = hotel.spawn_z,
        spawn_rotation = hotel.spawn_rotation,
        spawn_interior = hotel.spawn_interior,
        spawn_dimension = hotel.spawn_dimension,
        locked = hotel.locked == true,
        owner_account_id = rented and hotel.tenant_account_id or 0,
        tenant_account_id = rented and hotel.tenant_account_id or 0,
        is_tenant = rented and isElement(viewer) and accountId(viewer) == tonumber(hotel.tenant_account_id) or false,
        owner_name = rented and accountName(hotel.tenant_account_id) or "Нет",
        tenant_name = rented and accountName(hotel.tenant_account_id) or "Нет",
        rent_started_at = hotel.rent_started_at,
        rent_expires_at = rented and hotel.rent_expires_at or 0,
        status = rented and "rented" or "free",
        parking_count = parking and 1 or 0,
        parkings = parkingList,
        inside_dimension = makeHotelDimension(hotel.id)
    }
end

local function allPublicHouses(viewer)
    local list = {}
    for _, house in pairs(RPHomeDB.houses) do
        list[#list + 1] = publicHouse(house)
    end
    for _, hotel in pairs(RPHomeDB.hotels) do
        list[#list + 1] = publicHotel(hotel, viewer)
    end
    table.sort(list, function(a, b)
        if a.property_type == b.property_type then return a.number < b.number end
        return tostring(a.property_type or "house") < tostring(b.property_type or "house")
    end)
    return list
end

local function syncHouses(target)
    if target and isElement(target) then
        setElementData(target, "home:isAdmin", isAdmin(target), false)
        triggerClientEvent(target, "home:setAdminState", resourceRoot, isAdmin(target))
        triggerClientEvent(target, "home:syncHouses", resourceRoot, allPublicHouses(target))
        return
    elseif not target then
        for _, player in ipairs(getElementsByType("player")) do
            setElementData(player, "home:isAdmin", isAdmin(player), false)
            triggerClientEvent(player, "home:setAdminState", resourceRoot, isAdmin(player))
            triggerClientEvent(player, "home:syncHouses", resourceRoot, allPublicHouses(player))
        end
        return
    end
end

local function distanceToHouse(player, house)
    local x, y, z = getElementPosition(player)
    return getDistanceBetweenPoints3D(x, y, z, house.entrance_x, house.entrance_y, house.entrance_z)
end

local function nearHouse(player, house, distance)
    return house
        and getElementInterior(player) == house.entrance_interior
        and getElementDimension(player) == house.entrance_dimension
        and distanceToHouse(player, house) <= (distance or HomeConfig.enterDistance)
end

local function makeDimension(houseId)
    return (tonumber(homeConfig().dimensionBase) or tonumber(HomeConfig.dimensionBase) or 60000) + (tonumber(houseId) or 0)
end

makeHotelDimension = function(hotelId)
    return (tonumber(hotelConfig().dimensionBase) or tonumber(HomeConfig.hotelDimensionBase) or 30000) + (tonumber(hotelId) or 0)
end

propertyPublicId = function(kind, id)
    id = tonumber(id) or 0
    return kind == "hotel" and -id or id
end

hotelFromPublicId = function(publicId)
    publicId = tonumber(publicId) or 0
    if publicId < 0 then return RPHomeDB.hotels[-publicId] end
    return false
end

nowStamp = function()
    return getRealTime().timestamp
end

isHotelRentActive = function(hotel)
    return hotel and (tonumber(hotel.tenant_account_id) or 0) > 0 and (tonumber(hotel.rent_expires_at) or 0) > nowStamp()
end

local function getHouseOutsidePosition(house)
    if not house then return false end
    if house.spawn_configured then
        return {
            x = house.spawn_x,
            y = house.spawn_y,
            z = house.spawn_z,
            rotation = house.spawn_rotation,
            camera = house.spawn_cam_x and {
                x = house.spawn_cam_x,
                y = house.spawn_cam_y,
                z = house.spawn_cam_z,
                lx = house.spawn_look_x,
                ly = house.spawn_look_y,
                lz = house.spawn_look_z
            } or nil,
            interior = house.spawn_interior,
            dimension = house.spawn_dimension
        }
    end
    return {
        x = house.entrance_x,
        y = house.entrance_y,
        z = house.entrance_z + 0.8,
        rotation = house.entrance_rotation,
        interior = house.entrance_interior,
        dimension = house.entrance_dimension
    }
end

local function getHotelOutsidePosition(hotel)
    if not hotel then return false end
    return {
        x = hotel.spawn_x or hotel.entrance_x,
        y = hotel.spawn_y or hotel.entrance_y,
        z = hotel.spawn_z or hotel.entrance_z,
        rotation = hotel.spawn_rotation or hotel.entrance_rotation,
        interior = hotel.spawn_interior or hotel.entrance_interior or 0,
        dimension = hotel.spawn_dimension or hotel.entrance_dimension or 0
    }
end

local function createInteriorMarker(house)
    local interior = (homeConfig().getInterior or HomeConfig.getInterior)(house.interior_key)
    if not interior then return end
    local c = interior.control or interior.spawn
    local style = homeConfig().interiorMarker or {}
    local color = style.color or {79, 195, 247}
    local markerType = tostring(style.type or "cylinder")
    local defaultZOffset = markerType == "arrow" and 0.7 or -1
    local markerZ = c.z + (tonumber(style.zOffset) or defaultZOffset)
    local control = createMarker(c.x, c.y, markerZ, markerType, style.size or HomeConfig.controlMarkerSize or HomeConfig.markerSize or 1.0, color[1], color[2], color[3], style.alpha or HomeConfig.markerAlpha or 180)
    setElementInterior(control, interior.interior)
    setElementDimension(control, makeDimension(house.id))
    setElementData(control, "home:controlHouseId", house.id, true)
    controlMarkers[markerKey("house", house.id)] = control
end

local function createHotelInteriorMarker(hotel)
    local interior = hotelInteriorConfig()
    if not hotel or not interior then return end
    local c = interior.menuMarker or interior.control or interior.spawn or interior.playerSpawn
    if not c then return end
    local key = markerKey("hotel", hotel.id)
    local dimension = makeHotelDimension(hotel.id)
    if dimension < 1 or dimension >= (tonumber(homeConfig().dimensionBase) or 60000) or dimension > 65535 then
        outputDebugString("[RP Home] Invalid hotel dimension for hotel ID " .. tostring(hotel.id), 1)
        return
    end
    if isElement(controlMarkers[key]) then destroyElement(controlMarkers[key]) end
    debugHome("Creating hotel interior marker")
    debugHome("Hotel ID: " .. tostring(hotel.id))
    debugHome("Interior: " .. tostring(interior.interior))
    debugHome("Dimension: " .. tostring(dimension))
    debugHome(string.format("Marker position: %.3f, %.3f, %.3f", tonumber(c.x) or 0, tonumber(c.y) or 0, tonumber(c.z) or 0))
    local style = hotelConfig().interiorMarker or {}
    local color = style.color or {245, 248, 252}
    local markerType = tostring(style.type or "cylinder")
    local defaultZOffset = markerType == "arrow" and 0.7 or -1
    local markerZ = c.z + (tonumber(style.zOffset) or defaultZOffset)
    local control = createMarker(c.x, c.y, markerZ, markerType, style.size or HomeConfig.controlMarkerSize or HomeConfig.markerSize or 1.0, color[1], color[2], color[3], style.alpha or HomeConfig.markerAlpha or 165)
    setElementInterior(control, interior.interior)
    setElementDimension(control, dimension)
    setElementData(control, "hotel:controlHotelId", tonumber(hotel.id) or 0, true)
    setElementData(control, "hotel:interiorMarker", true, true)
    setElementData(control, "home:hotelId", tonumber(hotel.id) or 0, true)
    controlMarkers[key] = control
    debugHome("Marker created: " .. (isElement(control) and "YES" or "NO"))
end

local function rebuildExitMarkers()
    for _, marker in pairs(controlMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    controlMarkers = {}
    for _, house in pairs(RPHomeDB.houses) do
        createInteriorMarker(house)
    end
    for _, hotel in pairs(RPHomeDB.hotels) do
        createHotelInteriorMarker(hotel)
    end
end

local function hasHouseLimit(player)
    validatePlayerHouse(player)
    return playerHouseId(player) and playerHouseId(player) > 0
end

local function getActiveHotelByAccount(accountIdValue)
    accountIdValue = tonumber(accountIdValue) or 0
    if accountIdValue <= 0 then return false end
    for _, hotel in pairs(RPHomeDB.hotels) do
        if tonumber(hotel.tenant_account_id) == accountIdValue and isHotelRentActive(hotel) then
            return hotel
        end
    end
    return false
end

local function detachHotelVehicles(hotel, ownerId, reason)
    if hotel then notifyCarHouseDetached(propertyPublicId("hotel", hotel.id), ownerId or hotel.tenant_account_id, reason or "hotel_detached") end
end

local function attachHotelVehicles(hotel, ownerId, reason)
    if hotel then notifyCarHouseAttached(propertyPublicId("hotel", hotel.id), ownerId or hotel.tenant_account_id, reason or "hotel_attached") end
end

local function expireHotelRent(hotel, reason)
    if not hotel or (tonumber(hotel.tenant_account_id) or 0) <= 0 then return false end
    local tenantId = tonumber(hotel.tenant_account_id) or 0
    detachHotelVehicles(hotel, tenantId, reason or "hotel_expired")
    RPHomeDB.exec("UPDATE hotels SET tenant_account_id = 0, rent_started_at = 0, rent_expires_at = 0, updated_at = ? WHERE id = ?", nowStamp(), hotel.id)
    for _, player in ipairs(getElementsByType("player")) do
        if accountId(player) == tenantId and getElementDimension(player) == makeHotelDimension(hotel.id) then
            local p = getHotelOutsidePosition(hotel)
            setElementInterior(player, p.interior or 0)
            setElementDimension(player, p.dimension or 0)
            setElementPosition(player, p.x, p.y, p.z)
            setPedRotation(player, p.rotation or 0)
            setCameraTarget(player, player)
            notify(player, "РЎСЂРѕРє Р°СЂРµРЅРґС‹ РіРѕСЃС‚РёРЅРёС‡РЅРѕРіРѕ РЅРѕРјРµСЂР° РёСЃС‚С‘Рє.", false)
        end
    end
    RPHomeDB.reload()
    syncHouses()
    return true
end

local function checkExpiredHotels()
    for _, hotel in pairs(RPHomeDB.hotels) do
        if (tonumber(hotel.tenant_account_id) or 0) > 0 and (tonumber(hotel.rent_expires_at) or 0) <= nowStamp() then
            expireHotelRent(hotel, "hotel_expired")
        end
    end
end

local function buyHouse(player, house, price, sellerId)
    price = math.floor(tonumber(price) or 0)
    if playerBalance(player) < price then
        notify(player, "РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РґРµРЅРµРі РґР»СЏ РїРѕРєСѓРїРєРё РґРѕРјР°.", false)
        return false
    end
    if hasHouseLimit(player) then
        notify(player, "Р’С‹ СѓР¶Рµ РІР»Р°РґРµРµС‚Рµ РґРѕРјРѕРј.", false)
        return false
    end

    local buyerId = accountId(player)
    if not buyerId then return false end

    if sellerId then
        if tonumber(sellerId) == buyerId then
            notify(player, "Р’С‹ СѓР¶Рµ РІР»Р°РґРµР»РµС† СЌС‚РѕРіРѕ РґРѕРјР°.", false)
            return false
        end
    end

    if not changePlayerMoneyCore(player, -price) then
        notify(player, "РћС€РёР±РєР° РґРµРЅРµР¶РЅРѕР№ РѕРїРµСЂР°С†РёРё.", false)
        return false
    end

    if sellerId and not addAccountMoney(sellerId, price) then
        changePlayerMoneyCore(player, price)
        notify(player, "РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°С‡РёСЃР»РёС‚СЊ РґРµРЅСЊРіРё РїСЂРѕРґР°РІС†Сѓ. РџРѕРєСѓРїРєР° РѕС‚РјРµРЅРµРЅР°.", false)
        return false
    end

    if sellerId then
        setAccountHouse(sellerId, 0)
        notifyCarHouseDetached(house.id, sellerId, "house_sold_player")
    end

    if not setAccountHouse(buyerId, house.id) then
        changePlayerMoneyCore(player, price)
        if sellerId then addAccountMoney(sellerId, -price) end
        notify(player, "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕС…СЂР°РЅРёС‚СЊ РґРѕРј Р·Р° Р°РєРєР°СѓРЅС‚РѕРј. РџРѕРєСѓРїРєР° РѕС‚РјРµРЅРµРЅР°.", false)
        return false
    end
    setElementData(player, "auth:houseId", house.id, true)
    RPHomeDB.exec("UPDATE houses SET sale_price = 0, updated_at = ? WHERE id = ?", getRealTime().timestamp, house.id)
    RPHomeDB.reload()
    syncHouses()
    notifyCarHouseAttached(house.id, buyerId, "house_bought")
    notify(player, "Р”РѕРј в„–" .. tostring(house.number) .. " РєСѓРїР»РµРЅ.", true)
    return true
end

local function openCreatePanel(player)
    if not isAdmin(player) then notify(player, "РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ.", false); return end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    pendingEntrances[player] = {
        x = x, y = y, z = z,
        rotation = rz or getPedRotation(player) or 0,
        interior = getElementInterior(player),
        dimension = getElementDimension(player)
    }
    triggerClientEvent(player, "home:openCreatePanel", resourceRoot, HomeConfig.interiors, pendingEntrances[player])
end

local function openCreateHotelPanel(player)
    if not isAdmin(player) then notify(player, "РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ.", false); return end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    pendingHotelEntrances[player] = {
        x = x, y = y, z = z,
        rotation = rz or getPedRotation(player) or 0,
        interior = getElementInterior(player),
        dimension = getElementDimension(player)
    }
    triggerClientEvent(player, "hotel:openCreatePanel", resourceRoot, pendingHotelEntrances[player])
end

local function createHouse(player, data)
    if not isAdmin(player) then return end
    if type(data) ~= "table" then return end

    local number = math.floor(tonumber(data.number) or 0)
    local price = math.floor(tonumber(data.gov_price) or 0)
    local parkingCount = math.floor(tonumber(data.parking_count) or 0)
    local district = tostring(data.district or ""):sub(1, 64)
    local interior = (homeConfig().getInterior or HomeConfig.getInterior)(data.interior_key)

    if number <= 0 or price <= 0 or district == "" or not interior then
        notify(player, "РџСЂРѕРІРµСЂСЊС‚Рµ РЅРѕРјРµСЂ, СЂР°Р№РѕРЅ, С†РµРЅСѓ Рё РёРЅС‚РµСЂСЊРµСЂ.", false)
        return
    end
    if getHouseByNumber(number) then
        notify(player, "Р”РѕРј СЃ С‚Р°РєРёРј РЅРѕРјРµСЂРѕРј СѓР¶Рµ СЃСѓС‰РµСЃС‚РІСѓРµС‚.", false)
        return
    end
    if parkingCount < 0 or parkingCount > 20 then
        notify(player, "РќРµРєРѕСЂСЂРµРєС‚РЅРѕРµ РєРѕР»РёС‡РµСЃС‚РІРѕ РїР°СЂРєРѕРІРѕРє.", false)
        return
    end
    if type(data.parkings) ~= "table" or #data.parkings ~= parkingCount then
        notify(player, "РЎРѕС…СЂР°РЅРёС‚Рµ РІСЃРµ РїР°СЂРєРѕРІРѕС‡РЅС‹Рµ РјРµСЃС‚Р°.", false)
        return
    end

    local entrance = pendingEntrances[player] or data
    local x, y, z = tonumber(entrance.x), tonumber(entrance.y), tonumber(entrance.z)
    if not x or not y or not z then return end

    local houseId = RPHomeDB.createHouse({
        number = number,
        district = district,
        interior_key = interior.key,
        gov_price = price,
        x = x, y = y, z = z,
        rotation = tonumber(entrance.rotation) or 0,
        interior = tonumber(entrance.interior) or 0,
        dimension = tonumber(entrance.dimension) or 0,
        spawn_x = tonumber(data.spawn_x) or x,
        spawn_y = tonumber(data.spawn_y) or y,
        spawn_z = tonumber(data.spawn_z) or z,
        spawn_rotation = tonumber(data.spawn_rotation) or tonumber(entrance.rotation) or 0,
        spawn_cam_x = tonumber(data.spawn_cam_x),
        spawn_cam_y = tonumber(data.spawn_cam_y),
        spawn_cam_z = tonumber(data.spawn_cam_z),
        spawn_look_x = tonumber(data.spawn_look_x),
        spawn_look_y = tonumber(data.spawn_look_y),
        spawn_look_z = tonumber(data.spawn_look_z),
        spawn_interior = tonumber(data.spawn_interior) or tonumber(entrance.interior) or 0,
        spawn_dimension = tonumber(data.spawn_dimension) or tonumber(entrance.dimension) or 0,
        spawn_configured = data.spawn_configured == true
    }, data.parkings)

    if houseId then
        pendingEntrances[player] = nil
        createInteriorMarker(RPHomeDB.houses[houseId])
        RPHomeDB.log("create", adminName(player), houseId, "number=" .. tostring(number))
        syncHouses()
        notify(player, "Р”РѕРј в„–" .. tostring(number) .. " СЃРѕР·РґР°РЅ.", true)
    else
        notify(player, "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ РґРѕРј.", false)
    end
end

local function createHotel(player, data)
    if not isAdmin(player) or type(data) ~= "table" then return end
    local number = math.floor(tonumber(data.number) or 0)
    local price = math.floor(tonumber(data.daily_price or data.gov_price) or 0)
    local district = tostring(data.district or ""):sub(1, 64)
    if number <= 0 or price <= 0 or district == "" then
        notify(player, "РџСЂРѕРІРµСЂСЊС‚Рµ РЅРѕРјРµСЂ, СЂР°Р№РѕРЅ Рё С†РµРЅСѓ Р°СЂРµРЅРґС‹.", false)
        return
    end
    for _, hotel in pairs(RPHomeDB.hotels) do
        if tonumber(hotel.number) == number then notify(player, "РћС‚РµР»СЊ СЃ С‚Р°РєРёРј РЅРѕРјРµСЂРѕРј СѓР¶Рµ СЃСѓС‰РµСЃС‚РІСѓРµС‚.", false); return end
    end
    if type(data.parkings) ~= "table" or not data.parkings[1] then
        notify(player, "РЎРѕС…СЂР°РЅРёС‚Рµ РїР°СЂРєРѕРІРѕС‡РЅРѕРµ РјРµСЃС‚Рѕ РѕС‚РµР»СЏ.", false)
        return
    end
    local entrance = pendingHotelEntrances[player] or data
    local x, y, z = tonumber(entrance.x), tonumber(entrance.y), tonumber(entrance.z)
    if not x or not y or not z then return end
    local hotelId = RPHomeDB.createHotel({
        number = number,
        district = district,
        daily_price = price,
        x = x, y = y, z = z,
        rotation = tonumber(entrance.rotation) or 0,
        interior = tonumber(entrance.interior) or 0,
        dimension = tonumber(entrance.dimension) or 0,
        spawn_x = tonumber(data.spawn_x) or x,
        spawn_y = tonumber(data.spawn_y) or y,
        spawn_z = tonumber(data.spawn_z) or z,
        spawn_rotation = tonumber(data.spawn_rotation) or tonumber(entrance.rotation) or 0,
        spawn_interior = tonumber(data.spawn_interior) or tonumber(entrance.interior) or 0,
        spawn_dimension = tonumber(data.spawn_dimension) or tonumber(entrance.dimension) or 0
    }, data.parkings[1])
    if hotelId then
        pendingHotelEntrances[player] = nil
        createHotelInteriorMarker(RPHomeDB.hotels[hotelId])
        RPHomeDB.log("create_hotel", adminName(player), -hotelId, "number=" .. tostring(number))
        syncHouses()
        notify(player, "РћС‚РµР»СЊ в„–" .. tostring(number) .. " СЃРѕР·РґР°РЅ.", true)
    else
        notify(player, "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ РѕС‚РµР»СЊ.", false)
    end
end

local function updateHouse(player, houseId, data)
    if not isAdmin(player) then return end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not house or type(data) ~= "table" then return end

    if data.delete then
        clearHouseOwner(house.id)
        RPHomeDB.exec("DELETE FROM parking_spaces WHERE house_id = ?", house.id)
        RPHomeDB.exec("DELETE FROM houses WHERE id = ?", house.id)
        RPHomeDB.log("delete", adminName(player), house.id, "number=" .. tostring(house.number))
        RPHomeDB.reload()
        rebuildExitMarkers()
        syncHouses()
        notify(player, "Р”РѕРј СѓРґР°Р»С‘РЅ.", true)
        return
    end

    local number = math.floor(tonumber(data.number) or house.number)
    local duplicate = getHouseByNumber(number)
    if duplicate and duplicate.id ~= house.id then
        notify(player, "Р­С‚РѕС‚ РЅРѕРјРµСЂ СѓР¶Рµ Р·Р°РЅСЏС‚.", false)
        return
    end

    local interior = (homeConfig().getInterior or HomeConfig.getInterior)(data.interior_key or house.interior_key)
    local price = math.floor(tonumber(data.gov_price) or house.gov_price)
    local district = tostring(data.district or house.district):sub(1, 64)
    local locked = data.locked == nil and (house.locked and 1 or 0) or (data.locked and 1 or 0)

    RPHomeDB.exec([[
        UPDATE houses SET number = ?, district = ?, interior_key = ?, gov_price = ?, entrance_x = ?,
            entrance_y = ?, entrance_z = ?, entrance_rotation = ?, entrance_interior = ?, entrance_dimension = ?,
            spawn_x = ?, spawn_y = ?, spawn_z = ?, spawn_rotation = ?,
            spawn_cam_x = ?, spawn_cam_y = ?, spawn_cam_z = ?, spawn_look_x = ?, spawn_look_y = ?, spawn_look_z = ?,
            spawn_interior = ?, spawn_dimension = ?,
            spawn_configured = ?, locked = ?, updated_at = ?
        WHERE id = ?
    ]], number, district, interior.key, price, tonumber(data.x) or house.entrance_x, tonumber(data.y) or house.entrance_y,
        tonumber(data.z) or house.entrance_z, tonumber(data.rotation) or house.entrance_rotation,
        tonumber(data.interior) or house.entrance_interior, tonumber(data.dimension) or house.entrance_dimension,
        tonumber(data.spawn_x) or house.spawn_x, tonumber(data.spawn_y) or house.spawn_y, tonumber(data.spawn_z) or house.spawn_z,
        tonumber(data.spawn_rotation) or house.spawn_rotation,
        tonumber(data.spawn_cam_x) or house.spawn_cam_x, tonumber(data.spawn_cam_y) or house.spawn_cam_y, tonumber(data.spawn_cam_z) or house.spawn_cam_z,
        tonumber(data.spawn_look_x) or house.spawn_look_x, tonumber(data.spawn_look_y) or house.spawn_look_y, tonumber(data.spawn_look_z) or house.spawn_look_z,
        tonumber(data.spawn_interior) or house.spawn_interior, tonumber(data.spawn_dimension) or house.spawn_dimension,
        data.spawn_configured and 1 or (house.spawn_configured and 1 or 0), locked, getRealTime().timestamp, house.id)

    if type(data.parkings) == "table" then RPHomeDB.replaceParkings(house.id, data.parkings) end
    if data.free then clearHouseOwner(house.id); RPHomeDB.exec("UPDATE houses SET sale_price = 0 WHERE id = ?", house.id) end
    if tonumber(data.owner_account_id) and tonumber(data.owner_account_id) > 0 then
        clearHouseOwner(house.id)
        local newOwnerId = tonumber(data.owner_account_id)
        setAccountHouse(newOwnerId, house.id)
        notifyCarHouseAttached(house.id, newOwnerId, "house_admin_assigned")
    end

    RPHomeDB.reload()
    rebuildExitMarkers()
    RPHomeDB.log("edit", adminName(player), house.id, "number=" .. tostring(number))
    syncHouses()
    notify(player, "Р”РѕРј РѕР±РЅРѕРІР»С‘РЅ.", true)
end

local function updateHotel(player, publicId, data)
    if not isAdmin(player) then return end
    local hotel = hotelFromPublicId(publicId)
    if not hotel or type(data) ~= "table" then return end

    if data.delete then
        expireHotelRent(hotel, "hotel_deleted")
        RPHomeDB.exec("DELETE FROM hotel_parkings WHERE hotel_id = ?", hotel.id)
        RPHomeDB.exec("DELETE FROM hotels WHERE id = ?", hotel.id)
        RPHomeDB.log("delete_hotel", adminName(player), propertyPublicId("hotel", hotel.id), "number=" .. tostring(hotel.number))
        RPHomeDB.reload()
        rebuildExitMarkers()
        syncHouses()
        notify(player, "РћС‚РµР»СЊ СѓРґР°Р»С‘РЅ.", true)
        return
    end

    if data.free then
        expireHotelRent(hotel, "hotel_admin_evict")
        notify(player, "РђСЂРµРЅРґР°С‚РѕСЂ РІС‹СЃРµР»РµРЅ.", true)
        return
    end

    local number = math.floor(tonumber(data.number) or hotel.number)
    for _, other in pairs(RPHomeDB.hotels) do
        if other.id ~= hotel.id and tonumber(other.number) == number then
            notify(player, "Р­С‚РѕС‚ РЅРѕРјРµСЂ РѕС‚РµР»СЏ СѓР¶Рµ Р·Р°РЅСЏС‚.", false)
            return
        end
    end

    local district = tostring(data.district or hotel.district):sub(1, 64)
    local price = math.floor(tonumber(data.daily_price or data.gov_price) or hotel.daily_price)
    if number <= 0 or district == "" or price <= 0 then
        notify(player, "РџСЂРѕРІРµСЂСЊС‚Рµ РЅРѕРјРµСЂ, СЂР°Р№РѕРЅ Рё С†РµРЅСѓ Р°СЂРµРЅРґС‹.", false)
        return
    end

    RPHomeDB.exec([[
        UPDATE hotels SET number = ?, district = ?, daily_price = ?,
            entrance_x = ?, entrance_y = ?, entrance_z = ?, entrance_rotation = ?, entrance_interior = ?, entrance_dimension = ?,
            spawn_x = ?, spawn_y = ?, spawn_z = ?, spawn_rotation = ?, spawn_interior = ?, spawn_dimension = ?,
            updated_at = ?
        WHERE id = ?
    ]], number, district, price,
        tonumber(data.x) or hotel.entrance_x, tonumber(data.y) or hotel.entrance_y, tonumber(data.z) or hotel.entrance_z,
        tonumber(data.rotation) or hotel.entrance_rotation, tonumber(data.interior) or hotel.entrance_interior,
        tonumber(data.dimension) or hotel.entrance_dimension,
        tonumber(data.spawn_x) or hotel.spawn_x, tonumber(data.spawn_y) or hotel.spawn_y, tonumber(data.spawn_z) or hotel.spawn_z,
        tonumber(data.spawn_rotation) or hotel.spawn_rotation,
        tonumber(data.spawn_interior) or hotel.spawn_interior, tonumber(data.spawn_dimension) or hotel.spawn_dimension,
        nowStamp(), hotel.id)

    if type(data.parkings) == "table" and data.parkings[1] then
        RPHomeDB.replaceHotelParking(hotel.id, data.parkings[1])
    end

    RPHomeDB.reload()
    rebuildExitMarkers()
    RPHomeDB.log("edit_hotel", adminName(player), propertyPublicId("hotel", hotel.id), "number=" .. tostring(number))
    syncHouses()
    notify(player, "РћС‚РµР»СЊ РѕР±РЅРѕРІР»С‘РЅ.", true)
end

addEventHandler("onResourceStart", resourceRoot, function()
    if RPHomeDB.init() then
        rebuildExitMarkers()
        setTimer(cleanupInvalidAccountHouseIds, 1000, 1)
        setTimer(syncHouses, 1000, 1)
        setTimer(checkExpiredHotels, 1500, 1)
        setTimer(checkExpiredHotels, tonumber(hotelConfig().expireCheckInterval) or tonumber(HomeConfig.hotelExpireCheckInterval) or 60000, 0)
    end

end)

addEventHandler("onPlayerQuit", root, function()
    pendingEntrances[source] = nil
    pendingHotelEntrances[source] = nil
end)

addEventHandler("onPlayerJoin", root, function()
    setTimer(function(player)
        if isElement(player) then syncHouses(player) end
    end, 1500, 1, source)
end)

addEventHandler("auth:spawned", root, function(player)
    if isElement(player) then
        checkExpiredHotels()
        validatePlayerHouse(player)
        syncHouses(player)
    end
end)

addEvent("home:requestSync", true)
addEventHandler("home:requestSync", root, function()
    if client ~= source then return end
    syncHouses(client)
end)

addEvent("home:create", true)
addEventHandler("home:create", root, function(data)
    if client ~= source then return end
    createHouse(client, data)
end)

addEvent("home:createHotel", true)
addEventHandler("home:createHotel", root, function(data)
    if client ~= source then return end
    createHotel(client, data)
end)

addEvent("hotel:create", true)
addEventHandler("hotel:create", root, function(data)
    if client ~= source then return end
    createHotel(client, data)
end)

addEvent("home:adminUpdate", true)
addEventHandler("home:adminUpdate", root, function(houseId, data)
    if client ~= source then return end
    updateHouse(client, houseId, data)
end)

addEvent("home:adminUpdateHotel", true)
addEventHandler("home:adminUpdateHotel", root, function(hotelId, data)
    if client ~= source then return end
    updateHotel(client, hotelId, data)
end)

addEvent("hotel:adminUpdate", true)
addEventHandler("hotel:adminUpdate", root, function(hotelId, data)
    if client ~= source then return end
    updateHotel(client, hotelId, data)
end)

local function rentHotel(player, publicId)
    if not isLogged(player) then return end
    checkExpiredHotels()
    local hotel = hotelFromPublicId(publicId)
    if not hotel then return false end
    hotel = RPHomeDB.hotels[hotel.id]
    if not nearHouse(player, { entrance_x = hotel.entrance_x, entrance_y = hotel.entrance_y, entrance_z = hotel.entrance_z, entrance_interior = hotel.entrance_interior, entrance_dimension = hotel.entrance_dimension }, (hotelConfig().markerDistance or HomeConfig.markerDistance) + 1.5) then
        notify(player, "Р’С‹ СЃР»РёС€РєРѕРј РґР°Р»РµРєРѕ РѕС‚ РѕС‚РµР»СЏ.", false)
        return false
    end
    if playerHouseId(player) > 0 then notify(player, "РќРµР»СЊР·СЏ Р°СЂРµРЅРґРѕРІР°С‚СЊ РѕС‚РµР»СЊ, РµСЃР»Рё Сѓ РІР°СЃ РµСЃС‚СЊ РґРѕРј.", false); return false end
    local id = accountId(player)
    if not id then return false end
    if getActiveHotelByAccount(id) then notify(player, "Р’С‹ СѓР¶Рµ Р°СЂРµРЅРґСѓРµС‚Рµ РіРѕСЃС‚РёРЅРёС‡РЅС‹Р№ РЅРѕРјРµСЂ.", false); return false end
    if isHotelRentActive(hotel) then notify(player, "Р­С‚РѕС‚ РЅРѕРјРµСЂ СѓР¶Рµ Р°СЂРµРЅРґРѕРІР°РЅ.", false); return false end
    local price = math.floor(tonumber(hotel.daily_price) or 0)
    if price <= 0 or playerBalance(player) < price then notify(player, "РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РґРµРЅРµРі РґР»СЏ Р°СЂРµРЅРґС‹.", false); return false end
    if not changePlayerMoneyCore(player, -price) then notify(player, "РћС€РёР±РєР° РґРµРЅРµР¶РЅРѕР№ РѕРїРµСЂР°С†РёРё.", false); return false end
    local ts = nowStamp()
    RPHomeDB.exec("UPDATE hotels SET tenant_account_id = ?, rent_started_at = ?, rent_expires_at = ?, updated_at = ? WHERE id = ?", id, ts, ts + (tonumber(hotelConfig().rentSeconds) or tonumber(HomeConfig.hotelRentSeconds) or 86400), ts, hotel.id)
    RPHomeDB.reload()
    attachHotelVehicles(RPHomeDB.hotels[hotel.id], id, "hotel_rented")
    syncHouses()
    notify(player, "Р“РѕСЃС‚РёРЅРёС‡РЅС‹Р№ РЅРѕРјРµСЂ Р°СЂРµРЅРґРѕРІР°РЅ РЅР° 24 С‡Р°СЃР°.", true)
    return true
end

addEvent("hotel:rent", true)
addEventHandler("hotel:rent", root, function(publicId)
    if client ~= source then return end
    rentHotel(client, publicId)
end)

addEvent("home:buy", true)
addEventHandler("home:buy", root, function(houseId)
    if client ~= source or not isLogged(client) then return end
    local hotel = hotelFromPublicId(houseId)
    if hotel then
        rentHotel(client, houseId)
        return
    end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    local insideHouse = false
    if house then
        local interior = (homeConfig().getInterior or HomeConfig.getInterior)(house.interior_key)
        insideHouse = interior
            and not house.locked
            and getElementInterior(client) == tonumber(interior.interior)
            and getElementDimension(client) == makeDimension(house.id)
    end
    if not nearHouse(client, house, HomeConfig.markerDistance + 1.5) and not insideHouse then notify(client, "Р’С‹ СЃР»РёС€РєРѕРј РґР°Р»РµРєРѕ РѕС‚ РґРѕРјР°.", false); return end

    if getActiveHotelByAccount(accountId(client)) then notify(client, "РЎРЅР°С‡Р°Р»Р° СЃСЉРµРґСЊС‚Рµ РёР· РѕС‚РµР»СЏ.", false); return end
    local status = getHouseStatus(house.id)
    if status == "free" then
        buyHouse(client, house, house.gov_price)
    elseif status == "sale" then
        buyHouse(client, house, house.sale_price, ownerAccountId(house.id))
    else
        notify(client, "Р”РѕРј РЅРµ РїСЂРѕРґР°С‘С‚СЃСЏ.", false)
    end
end)

addEvent("home:sellState", true)
addEventHandler("home:sellState", root, function(houseId)
    if client ~= source or not isLogged(client) then
        return
    end
    if hotelFromPublicId(houseId) then
        notify(client, "Отель нельзя продать государству.", false)
        return
    end

    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not house then
        notify(client, "Дом не найден.", false)
        return
    end

    local ownerOk = playerHouseId(client) == house.id
    if not ownerOk then
        notify(client, "Вы не владелец этого дома.", false)
        return
    end

    local ownerId = accountId(client)
    local refund = math.floor((tonumber(house.gov_price) or 0) * (tonumber(HomeConfig.stateSellPercent) or 50) / 100)
    local credited, moneyResult
    if refund > 0 then
        credited, moneyResult = changePlayerMoneyCore(client, refund)
    else
        credited, moneyResult = false, "invalid_amount"
    end
    if not credited then
        notify(client, "Ошибка денежной операции. Дом не продан.", false)
        return
    end

    local released = setAccountHouse(client, 0)
    if not released then
        changePlayerMoneyCore(client, -refund)
        notify(client, "Не удалось очистить владение домом. Продажа отменена.", false)
        return
    end

    notifyCarHouseDetached(house.id, ownerId, "house_sold_state")
    RPHomeDB.exec("UPDATE houses SET sale_price = 0, updated_at = ? WHERE id = ?", getRealTime().timestamp, house.id)
    RPHomeDB.reload()
    syncHouses()
    notify(client, "Дом продан государству за $" .. tostring(refund) .. ".", true)
end)

addEvent("home:setSalePrice", true)
addEventHandler("home:setSalePrice", root, function(houseId, price)
    if client ~= source or not isLogged(client) then return end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not house or playerHouseId(client) ~= house.id then return end
    price = math.floor(tonumber(price) or 0)
    if price < HomeConfig.salePrice.min or price > HomeConfig.salePrice.max then
        notify(client, "Р¦РµРЅР° РґРѕР»Р¶РЅР° Р±С‹С‚СЊ РѕС‚ $" .. HomeConfig.salePrice.min .. " РґРѕ $" .. HomeConfig.salePrice.max .. ".", false)
        return
    end
    RPHomeDB.exec("UPDATE houses SET sale_price = ?, updated_at = ? WHERE id = ?", price, getRealTime().timestamp, house.id)
    RPHomeDB.reload()
    syncHouses()
    notify(client, "Р”РѕРј РІС‹СЃС‚Р°РІР»РµРЅ РЅР° РїСЂРѕРґР°Р¶Сѓ.", true)
end)

addEvent("home:cancelSale", true)
addEventHandler("home:cancelSale", root, function(houseId)
    if client ~= source or not isLogged(client) then return end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not house or playerHouseId(client) ~= house.id then return end
    RPHomeDB.exec("UPDATE houses SET sale_price = 0, updated_at = ? WHERE id = ?", getRealTime().timestamp, house.id)
    RPHomeDB.reload()
    syncHouses()
    notify(client, "РџСЂРѕРґР°Р¶Р° РґРѕРјР° СЃРЅСЏС‚Р°.", true)
end)

addEvent("home:toggleLock", true)
addEventHandler("home:toggleLock", root, function(houseId)
    if client ~= source or not isLogged(client) then return end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not house or playerHouseId(client) ~= house.id then return end
    RPHomeDB.exec("UPDATE houses SET locked = ?, updated_at = ? WHERE id = ?", house.locked and 0 or 1, getRealTime().timestamp, house.id)
    RPHomeDB.reload()
    syncHouses()
    notify(client, house.locked and "Р”РѕРј РѕС‚РєСЂС‹С‚." or "Р”РѕРј Р·Р°РєСЂС‹С‚.", true)
end)

local function enterHotel(player, publicId)
    if not isLogged(player) then return end
    checkExpiredHotels()
    local hotel = hotelFromPublicId(publicId) or RPHomeDB.hotels[tonumber(publicId) or 0]
    if hotel then hotel = RPHomeDB.hotels[hotel.id] end
    if not hotel then return end
    if not nearHouse(player, { entrance_x = hotel.entrance_x, entrance_y = hotel.entrance_y, entrance_z = hotel.entrance_z, entrance_interior = hotel.entrance_interior, entrance_dimension = hotel.entrance_dimension }, hotelConfig().enterDistance or HomeConfig.enterDistance) then
        notify(player, "Р’С‹ СЃР»РёС€РєРѕРј РґР°Р»РµРєРѕ РѕС‚ РІС…РѕРґР°.", false)
        return
    end
    if not isHotelRentActive(hotel) or tonumber(hotel.tenant_account_id) ~= accountId(player) then
        notify(player, "РЈ РІР°СЃ РЅРµС‚ РґРѕСЃС‚СѓРїР° Рє СЌС‚РѕРјСѓ РЅРѕРјРµСЂСѓ.", false)
        return
    end
    if hotel.locked then
        notify(player, "Отель закрыт.", false)
        return
    end
    local interior = hotelInteriorConfig()
    local p = interior.playerSpawn or interior.spawn
    if not p then return end
    local dimension = makeHotelDimension(hotel.id)
    if dimension < 1 or dimension >= (tonumber(homeConfig().dimensionBase) or 60000) or dimension > 65535 then
        outputDebugString("[RP Home] Invalid hotel dimension for hotel ID " .. tostring(hotel.id), 1)
        return
    end
    local key = markerKey("hotel", hotel.id)
    if not isElement(controlMarkers[key]) then
        createHotelInteriorMarker(hotel)
    end
    setElementInterior(player, interior.interior)
    setElementDimension(player, dimension)
    setElementPosition(player, p.x, p.y, p.z)
    setPedRotation(player, p.rotation or 0)
    setCameraTarget(player, player)
    fadeCamera(player, true, 0)
    local marker = controlMarkers[key]
    debugHome("Player entered hotel")
    debugHome("Player interior: " .. tostring(getElementInterior(player)))
    debugHome("Player dimension: " .. tostring(getElementDimension(player)))
    debugHome("Hotel marker interior: " .. tostring(isElement(marker) and getElementInterior(marker) or "missing"))
    debugHome("Hotel marker dimension: " .. tostring(isElement(marker) and getElementDimension(marker) or "missing"))
end

local function enterHouse(player, houseId)
    if not isLogged(player) then return end
    local house = RPHomeDB.houses[tonumber(houseId) or 0]
    if not nearHouse(player, house, homeConfig().enterDistance or HomeConfig.enterDistance) then notify(player, "Р’С‹ СЃР»РёС€РєРѕРј РґР°Р»РµРєРѕ РѕС‚ РІС…РѕРґР°.", false); return end
    local allowedByKey = playerHasHouseKey(player, house.id)
    if house.locked and not allowedByKey then
        notify(player, "Р”РѕРј Р·Р°РєСЂС‹С‚.", false)
        return
    end
    local interior = (homeConfig().getInterior or HomeConfig.getInterior)(house.interior_key)
    local p = interior.spawn
    setElementInterior(player, interior.interior)
    setElementDimension(player, makeDimension(house.id))
    setElementPosition(player, p.x, p.y, p.z)
    setPedRotation(player, p.rotation or 0)
    setCameraTarget(player, player)
    fadeCamera(player, true, 0)
end

local function exitHotel(player, publicId)
    if not isLogged(player) then return false end
    local dim = getElementDimension(player)
    -- All hotels share a GTA interior. Only the actual dimension identifies
    -- which hotel's outside exit is valid; never trust the client's selection.
    local hotelId = dim - (tonumber(hotelConfig().dimensionBase) or tonumber(HomeConfig.hotelDimensionBase) or 30000)
    local hotel = RPHomeDB.hotels[hotelId]
    if not hotel or dim ~= makeHotelDimension(hotel.id) then return false end
    local hotelInterior = tonumber((hotelInteriorConfig() or {}).interior)
    if hotelInterior and getElementInterior(player) ~= hotelInterior then return false end
    local p = getHotelOutsidePosition(hotel)
    if not p then return false end
    setElementInterior(player, p.interior or 0)
    setElementDimension(player, p.dimension or 0)
    setElementPosition(player, p.x, p.y, p.z)
    setPedRotation(player, p.rotation or 0)
    setCameraTarget(player, player)
    fadeCamera(player, true, 0)
    return true
end

addEvent("hotel:toggleLock", true)
addEventHandler("hotel:toggleLock", root, function(publicId)
    if client ~= source or not isLogged(client) then return end
    local hotel = hotelFromPublicId(publicId) or RPHomeDB.hotels[tonumber(publicId) or 0]
    if not hotel or not isHotelRentActive(hotel) or tonumber(hotel.tenant_account_id) ~= accountId(client) then return end
    RPHomeDB.exec("UPDATE hotels SET locked = ?, updated_at = ? WHERE id = ?", hotel.locked and 0 or 1, nowStamp(), hotel.id)
    RPHomeDB.reload()
    syncHouses()
    notify(client, hotel.locked and "Отель открыт." or "Отель закрыт.", true)
end)

local function exitHouse(player)
    local dim = getElementDimension(player)
    local houseId = dim - (tonumber(homeConfig().dimensionBase) or tonumber(HomeConfig.dimensionBase) or 60000)
    local house = RPHomeDB.houses[houseId]
    if not house then return false end
    local p = getHouseOutsidePosition(house)
    if not p then return false end
    setElementInterior(player, p.interior or 0)
    setElementDimension(player, p.dimension or 0)
    setElementPosition(player, p.x, p.y, p.z)
    setPedRotation(player, p.rotation or 0)
    setCameraTarget(player, player)
    if type(p.camera) == "table" then
        triggerClientEvent(player, "home:applySpawnCamera", resourceRoot, p.camera)
    end
    fadeCamera(player, true, 0)
    return true
end

addEvent("hotel:enter", true)
addEventHandler("hotel:enter", root, function(publicId)
    if client ~= source then return end
    enterHotel(client, publicId)
end)

addEvent("hotel:exit", true)
addEventHandler("hotel:exit", root, function(publicId)
    if client ~= source then return end
    if not exitHotel(client, publicId) then
        debugHome("Hotel exit failed. Public ID: " .. tostring(publicId) .. ", player dimension: " .. tostring(getElementDimension(client)))
        notify(client, "Не удалось выйти из отеля.", false)
    end
end)

addEvent("home:enter", true)
addEventHandler("home:enter", root, function(houseId)
    if client ~= source then return end
    if hotelFromPublicId(houseId) then enterHotel(client, houseId); return end
    enterHouse(client, houseId)
end)

addEvent("home:exit", true)
addEventHandler("home:exit", root, function()
    if client ~= source then return end
    if exitHouse(client) then return end
    exitHotel(client)
end)

local function extendHotelRent(player, publicId, days)
    if not isLogged(player) then return end
    checkExpiredHotels()
    local hotel = hotelFromPublicId(publicId)
    if not hotel or not isHotelRentActive(hotel) or tonumber(hotel.tenant_account_id) ~= accountId(player) then return end
    days = math.floor(tonumber(days) or 0)
    if days < 1 or days > (tonumber(hotelConfig().maxExtendDays) or tonumber(HomeConfig.hotelMaxExtendDays) or 14) then
        notify(player, "РЎСЂРѕРє РїСЂРѕРґР»РµРЅРёСЏ РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РѕС‚ 1 РґРѕ 14 РґРЅРµР№.", false)
        return
    end
    local price = math.floor((tonumber(hotel.daily_price) or 0) * days)
    if price <= 0 or playerBalance(player) < price then notify(player, "РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РґРµРЅРµРі РґР»СЏ РїСЂРѕРґР»РµРЅРёСЏ.", false); return end
    if not changePlayerMoneyCore(player, -price) then notify(player, "РћС€РёР±РєР° РґРµРЅРµР¶РЅРѕР№ РѕРїРµСЂР°С†РёРё.", false); return end
    local base = math.max(nowStamp(), tonumber(hotel.rent_expires_at) or nowStamp())
    local newExpires = base + days * (tonumber(hotelConfig().rentSeconds) or tonumber(HomeConfig.hotelRentSeconds) or 86400)
    RPHomeDB.exec("UPDATE hotels SET rent_expires_at = ?, updated_at = ? WHERE id = ?", newExpires, nowStamp(), hotel.id)
    RPHomeDB.reload()
    syncHouses()
    notify(player, "РђСЂРµРЅРґР° РїСЂРѕРґР»РµРЅР° РЅР° " .. tostring(days) .. " РґРЅ.", true)
end

addEvent("hotel:extend", true)
addEventHandler("hotel:extend", root, function(publicId, days)
    if client ~= source then return end
    extendHotelRent(client, publicId, days)
end)

addEvent("home:extendHotel", true)
addEventHandler("home:extendHotel", root, function(publicId, days)
    if client ~= source then return end
    extendHotelRent(client, publicId, days)
end)

local function leaveHotelRent(player, publicId)
    if not isLogged(player) then return end
    local hotel = hotelFromPublicId(publicId)
    if not hotel or tonumber(hotel.tenant_account_id) ~= accountId(player) then return end
    expireHotelRent(hotel, "hotel_left")
    notify(player, "Р’С‹ СЃСЉРµС…Р°Р»Рё РёР· РѕС‚РµР»СЏ.", true)
end

addEvent("hotel:leave", true)
addEventHandler("hotel:leave", root, function(publicId)
    if client ~= source then return end
    leaveHotelRent(client, publicId)
end)

addEvent("home:leaveHotel", true)
addEventHandler("home:leaveHotel", root, function(publicId)
    if client ~= source then return end
    leaveHotelRent(client, publicId)
end)

addCommandHandler("createhouse", openCreatePanel)
addCommandHandler("createhotel", openCreateHotelPanel)

addEvent("home:openCreateCommand", true)
addEventHandler("home:openCreateCommand", root, function()
    openCreatePanel(source)
end)

addEvent("home:openCreateHotelCommand", true)
addEventHandler("home:openCreateHotelCommand", root, function()
    openCreateHotelPanel(source)
end)

addEvent("hotel:openCreateCommand", true)
addEventHandler("hotel:openCreateCommand", root, function()
    openCreateHotelPanel(source)
end)

addEvent("home:findCommand", true)
addEventHandler("home:findCommand", root, function(args)
    local player = source
    local number = tonumber(tostring(args or ""):match("(%d+)"))
    if not number then notify(player, "РСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ: /home [РЅРѕРјРµСЂ РґРѕРјР°]", false); return end
    local house = getHouseByNumber(number)
    if not house then
        notify(player, "Р”РѕРј СЃ С‚Р°РєРёРј РЅРѕРјРµСЂРѕРј РЅРµ РЅР°Р№РґРµРЅ.", false)
        return
    end
    triggerClientEvent(player, "home:setGps", resourceRoot, publicHouse(house))
    notify(player, "РњР°СЂС€СЂСѓС‚ Рє РґРѕРјСѓ в„–" .. tostring(house.number) .. " (" .. tostring(house.district) .. ") РїРѕСЃС‚СЂРѕРµРЅ.", true)
end)

addCommandHandler("home", function(player, _, number)
    triggerEvent("home:findCommand", player, tostring(number or ""))
end)

addCommandHandler("homecancel", function(player)
    triggerClientEvent(player, "home:clearGps", resourceRoot)
    notify(player, "GPS-РјРµС‚РєР° СѓРґР°Р»РµРЅР°.", true)
end)

function getPlayerHouse(player)
    local house = getHouseData(playerHouseId(player))
    if house then return house end
    local hotel = getActiveHotelByAccount(accountId(player))
    return hotel and publicHotel(hotel) or false
end

function getHouseByNumber(number)
    number = tonumber(number)
    for _, house in pairs(RPHomeDB.houses) do
        if house.number == number then return house end
    end
    return false
end

function getHouseData(houseId)
    local hotel = hotelFromPublicId(houseId)
    if hotel then
        if not isHotelRentActive(hotel) and (tonumber(hotel.tenant_account_id) or 0) > 0 then expireHotelRent(hotel, "hotel_expired_lookup") end
        return publicHotel(RPHomeDB.hotels[hotel.id])
    end
    return publicHouse(RPHomeDB.houses[tonumber(houseId) or 0])
end

function getPlayerHotel(player)
    local hotel = getActiveHotelByAccount(accountId(player))
    return hotel and publicHotel(hotel) or false
end

function getHotelData(hotelId)
    hotelId = tonumber(hotelId) or 0
    if hotelId < 0 then hotelId = -hotelId end
    local hotel = RPHomeDB.hotels[hotelId]
    if not hotel then return false end
    if not isHotelRentActive(hotel) and (tonumber(hotel.tenant_account_id) or 0) > 0 then expireHotelRent(hotel, "hotel_expired_lookup") end
    return publicHotel(RPHomeDB.hotels[hotelId])
end

function getHouseParkingSpaces(houseId)
    local hotel = hotelFromPublicId(houseId)
    if hotel then
        local p = RPHomeDB.hotelParkings[hotel.id]
        if not p then return {} end
        p.house_id = propertyPublicId("hotel", hotel.id)
        p.slot = 1
        return { p }
    end
    local list = {}
    for _, row in pairs(RPHomeDB.parkings[tonumber(houseId) or 0] or {}) do list[#list + 1] = row end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return list
end

local function carRunning()
    local resource = getResourceFromName("rp_car")
    return resource and getResourceState(resource) == "running"
end

function isHouseParkingSpaceAvailable(houseId, parkingSlot)
    houseId = tonumber(houseId) or 0
    parkingSlot = tonumber(parkingSlot) or 0
    if houseId == 0 or parkingSlot <= 0 then return false end
    if houseId < 0 then
        local hotel = RPHomeDB.hotels[-houseId]
        if not hotel or not isHotelRentActive(hotel) or parkingSlot ~= 1 or not RPHomeDB.hotelParkings[hotel.id] then return false end
    elseif not (RPHomeDB.parkings[houseId] and RPHomeDB.parkings[houseId][parkingSlot]) then return false end
    if carRunning() then
        local ok, occupied = pcall(function()
            return exports.rp_car:isHouseParkingSpaceOccupied(houseId, parkingSlot)
        end)
        if ok and occupied then return false end
    end
    return true
end

function getFreeHouseParkingSpace(houseId)
    local list = getHouseParkingSpaces(houseId)
    for _, space in ipairs(list) do
        if isHouseParkingSpaceAvailable(houseId, space.slot) then return space end
    end
    return false
end

function getPlayerSpawnHousePosition(player)
    local houseId = playerHouseId(player)
    local house = RPHomeDB.houses[houseId]
    if house then
        return getHouseOutsidePosition(house)
    end
    if houseId and houseId > 0 then setAccountHouse(player, 0) end
    local hotel = getActiveHotelByAccount(accountId(player))
    return hotel and getHotelOutsidePosition(hotel) or false
end

function isPlayerHouseOwner(player, houseId)
    return playerHouseId(player) == tonumber(houseId)
end
