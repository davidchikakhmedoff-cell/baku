local houses = {}
local houseMarkers = {}
local parkingMarkers = {}
local buttons = {}
local inputs = {}
local formValues = {}
local activeInput = nil
local inputStates = {}
local window = nil
local windowContext = nil
local selectedHouse = nil
local interiors = HomeConfig.interiors
local gpsBlip = nil
local gpsHouseId = nil
local sx, sy = guiGetScreenSize()
local scale = math.min(sx / 1920, sy / 1080)
local isHomeAdmin = false
local HOME_UI_NAME = "home"
local HOME_MENU_SCALE = 1.05
local homeMenuFont = nil

local createData = nil
local setup = nil

local function s(v) return math.max(1, math.floor(v * scale + 0.5)) end
local function hs(v) return s(v * HOME_MENU_SCALE) end
local function crisp(v) return math.floor(v + 0.5) end
local function rgba(c, a) return tocolor(c[1], c[2], c[3], a or c[4] or 255) end
local function len(v) return utf8 and utf8.len(v) or #v end
local function sub(v, a, b) return utf8 and utf8.sub(v, a, b) or string.sub(v, a, b) end
local function money(v) return "$" .. tostring(math.floor(tonumber(v) or 0)) end
local function isHotel(item) return item and item.property_type == "hotel" end
local function hotelPublicId(hotelId) return -(tonumber(hotelId) or 0) end
local function isPlayerInsideHotelInstance(hotel)
    if not isHotel(hotel) then return false end
    local hotelId = tonumber(hotel.hotel_id) or math.abs(tonumber(hotel.id) or 0)
    local hotelBase = (HotelSystemConfig and tonumber(HotelSystemConfig.dimensionBase)) or tonumber(HomeConfig.hotelDimensionBase) or 70000
    local expectedDimension = tonumber(hotel.inside_dimension) or (hotelBase + hotelId)
    local expectedInterior = HotelSystemConfig and HotelSystemConfig.interior and tonumber(HotelSystemConfig.interior.interior) or nil
    return getElementDimension(localPlayer) == expectedDimension and (not expectedInterior or getElementInterior(localPlayer) == expectedInterior)
end
local function formatRentTime(stamp)
    stamp = tonumber(stamp) or 0
    if stamp <= 0 then return "-" end
    local t = getRealTime(stamp)
    return string.format("%02d.%02d.%04d %02d:%02d", t.monthday, (t.month or 0) + 1, (t.year or 0) + 1900, t.hour, t.minute)
end
local function formatLeft(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then return string.format("%d дн. %d ч.", days, hours) end
    return string.format("%d ч. %d мин.", hours, minutes)
end

local function coreClientRunning()
    local resource = getResourceFromName("rp_core")
    return resource and getResourceState(resource) == "running"
end

local function acquireHomeUI()
    if coreClientRunning() and exports.rp_core.openUI then
        return exports.rp_core:openUI(HOME_UI_NAME, true, "no_binds_when_editing")
    end
    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    return true
end

local function releaseHomeUI()
    if coreClientRunning() and exports.rp_core.closeUI then
        exports.rp_core:closeUI(HOME_UI_NAME)
        return
    end
    showCursor(false)
    guiSetInputMode("allow_binds")
end

local function roundedRect(x, y, w, h, r, color)
    r = math.min(r, w / 2, h / 2)
    dxDrawRectangle(x + r, y, w - r * 2, h, color)
    dxDrawRectangle(x, y + r, r, h - r * 2, color)
    dxDrawRectangle(x + w - r, y + r, r, h - r * 2, color)
    dxDrawCircle(x + r, y + r, r, 180, 270, color, color, 12)
    dxDrawCircle(x + w - r, y + r, r, 270, 360, color, color, 12)
    dxDrawCircle(x + r, y + h - r, r, 90, 180, color, color, 12)
    dxDrawCircle(x + w - r, y + h - r, r, 0, 90, color, color, 12)
end

local function shadow(x, y, w, h, r)
    for i = 4, 1, -1 do
        roundedRect(x - i * 2, y - i * 2, w + i * 4, h + i * 4, r + i, tocolor(0, 0, 0, 55 / i))
    end
end

local function inputState(id)
    inputStates[id] = inputStates[id] or { caret = len(formValues[id] or ""), selectionStart = 0, selectionEnd = 0 }
    return inputStates[id]
end

local function clearInputSelection(id)
    local st = inputState(id)
    st.selectionStart = st.caret
    st.selectionEnd = st.caret
end

local function selectionBounds(st)
    return math.min(st.selectionStart, st.selectionEnd), math.max(st.selectionStart, st.selectionEnd)
end

local function hasSelection(st)
    return st.selectionStart ~= st.selectionEnd
end

local function setCaret(id, pos, keepSelection)
    local value = formValues[id] or ""
    local st = inputState(id)
    st.caret = math.max(0, math.min(len(value), tonumber(pos) or len(value)))
    if keepSelection then
        st.selectionEnd = st.caret
    else
        clearInputSelection(id)
    end
end

local function deleteSelection(id)
    local st = inputState(id)
    if not hasSelection(st) then return false end
    local a, b = selectionBounds(st)
    local value = formValues[id] or ""
    formValues[id] = sub(value, 1, a) .. sub(value, b + 1)
    st.caret = a
    clearInputSelection(id)
    return true
end

local function insertInputText(id, text)
    text = tostring(text or "")
    if id == "extendDays" or id == "salePrice" then
        text = text:gsub("%D", "")
    end
    if text == "" then return false end
    deleteSelection(id)
    local value = formValues[id] or ""
    local st = inputState(id)
    local allowed = 64 - len(value)
    if allowed <= 0 then return false end
    if len(text) > allowed then text = sub(text, 1, allowed) end
    formValues[id] = sub(value, 1, st.caret) .. text .. sub(value, st.caret + 1)
    st.caret = st.caret + len(text)
    clearInputSelection(id)
    return true
end

local function caretFromInputX(input, px)
    local value = formValues[input.id] or ""
    local textX = input.x + s(10)
    local font = input.style == "propertyInfo" and "default-bold" or "default"
    if px <= textX then return 0 end
    for i = 1, len(value) do
        local current = textX + dxGetTextWidth(sub(value, 1, i), 1, font)
        if px < current then
            local prev = textX + dxGetTextWidth(sub(value, 1, i - 1), 1, font)
            return (px - prev) < (current - px) and i - 1 or i
        end
    end
    return len(value)
end

local function statusText(house)
    if isHotel(house) then return house.status == "rented" and "Арендован" or "Свободен" end
    if house.status == "free" then return "Свободен" end
    if house.status == "sale" then return "Выставлен на продажу" end
    return "Занят"
end

local function playerPositionData()
    local element = getPedOccupiedVehicle(localPlayer) or localPlayer
    local x, y, z = getElementPosition(element)
    local rx, ry, rz = getElementRotation(element)
    return {
        x = x, y = y, z = z,
        rx = rx or 0, ry = ry or 0, rz = rz or 0,
        rotation = rz or getPedRotation(localPlayer) or 0,
        interior = getElementInterior(element),
        dimension = getElementDimension(element)
    }
end

local function playerSpawnPointData()
    local x, y, z = getElementPosition(localPlayer)
    local _, _, rz = getElementRotation(localPlayer)
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    local rotation = rz or getPedRotation(localPlayer) or 0
    if camX and lookX then
        local dx, dy = lookX - camX, lookY - camY
        if math.abs(dx) > 0.001 or math.abs(dy) > 0.001 then
            local angle
            if math.atan2 then
                angle = math.atan2(-dx, dy)
            elseif math.abs(dy) > 0.001 then
                angle = math.atan(-dx / dy)
                if dy < 0 then angle = angle + math.pi end
            else
                angle = dx > 0 and -math.pi / 2 or math.pi / 2
            end
            rotation = (math.deg(angle) + 360) % 360
        end
    end
    return {
        x = x, y = y, z = z,
        rx = 0, ry = 0, rz = rotation,
        rotation = rotation,
        camX = camX, camY = camY, camZ = camZ,
        lookX = lookX, lookY = lookY, lookZ = lookZ,
        interior = getElementInterior(localPlayer),
        dimension = getElementDimension(localPlayer)
    }
end

local function propertyOwnerName(house)
    if not house or (tonumber(house.owner_account_id) or 0) <= 0 then
        return "Государство"
    end
    local ownerName = tostring(house.owner_name or "")
    if ownerName == "" then return "Государство" end
    return ownerName
end

local function destroyParkingMarkers()
    for _, marker in ipairs(parkingMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    parkingMarkers = {}
end

local function showParkingMarkers()
    destroyParkingMarkers()
    if not createData then return end
    for slot, parking in pairs(createData.parkings or {}) do
        local marker = createMarker(parking.x, parking.y, parking.z - 0.8, "cylinder", 1.0, 102, 187, 106, 145)
        setElementInterior(marker, parking.interior or 0)
        setElementDimension(marker, parking.dimension or 0)
        parkingMarkers[#parkingMarkers + 1] = marker
    end
end

local function resetCreateData(entrance)
    createData = {
        entrance = entrance or playerPositionData(),
        ownerSpawn = entrance or playerPositionData(),
        ownerSpawnConfigured = false,
        parkings = {},
        interiorIndex = 1
    }
end

local function closeWindow(keepMarkers)
    window, windowContext, selectedHouse, activeInput = nil, nil, nil, nil
    buttons, inputs = {}, {}
    inputStates = {}
    releaseHomeUI()
    if not keepMarkers then destroyParkingMarkers() end
end

local function beginWindow(kind, house, context)
    if not window and not acquireHomeUI() then return false end
    window = kind
    windowContext = context
    selectedHouse = house
    buttons, inputs = {}, {}
    formValues = {}
    inputStates = {}
    return true
end

local function addButton(id, text, x, y, w, h, color, enabled, style)
    buttons[#buttons + 1] = {
        id = id,
        text = text,
        x = x,
        y = y,
        w = w,
        h = h,
        color = color or HomeConfig.colors.primary,
        enabled = enabled ~= false,
        style = style or ((window == "create" or window == "admin") and "propertyMenu" or nil)
    }
end

local function addInput(id, label, value, x, y, w, h, style)
    if formValues[id] == nil then formValues[id] = tostring(value or "") end
    inputs[#inputs + 1] = { id = id, label = label, value = formValues[id], x = x, y = y, w = w, h = h or s(40), style = style or ((window == "create" or window == "admin") and "propertyInfo" or nil) }
end

local function inputValue(id)
    return formValues[id] or ""
end

local function copyFormValues()
    local copy = {}
    for key, value in pairs(formValues) do copy[key] = value end
    return copy
end

local function currentInteriorKey()
    if createData and createData.propertyType == "hotel" then return "hotel" end
    return (interiors[createData.interiorIndex] or interiors[1]).key
end

local function parkingCount()
    if createData and createData.propertyType == "hotel" then return 1 end
    return math.max(0, math.min(20, math.floor(tonumber(inputValue("parking")) or 0)))
end

local function savedParkingCount()
    local count = 0
    for i = 1, parkingCount() do
        if createData.parkings[i] then count = count + 1 end
    end
    return count
end

local function openCreate(interiorList, entrance)
    interiors = interiorList or interiors
    resetCreateData(entrance)
    createData.propertyType = "house"
    if not beginWindow("create") then return end
    formValues.number = ""
    formValues.district = ""
    formValues.price = ""
    formValues.parking = "0"
    showParkingMarkers()
end

local function openCreateHotel(entrance)
    resetCreateData(entrance)
    createData.propertyType = "hotel"
    if not beginWindow("create") then return end
    formValues.number = ""
    formValues.district = ""
    formValues.price = ""
    formValues.parking = "1"
    showParkingMarkers()
end

local function openExtendHotel(hotel)
    if not beginWindow("extendHotel", hotel) then return end
    formValues.extendDays = "1"
end

local function openSale(house)
    if not beginWindow("sale", house) then return end
    formValues.salePrice = house.sale_price and house.sale_price > 0 and tostring(house.sale_price) or ""
end

local function openAdminEdit(house)
    resetCreateData()
    createData.propertyType = isHotel(house) and "hotel" or "house"
    if not beginWindow("admin", house) then return end
    formValues.number = tostring(house.number or "")
    formValues.district = tostring(house.district or "")
    formValues.price = tostring((isHotel(house) and house.daily_price) or house.gov_price or "")
    formValues.parking = tostring(isHotel(house) and 1 or (house.parking_count or 0))
    formValues.owner = ""
    createData.entrance = { x = house.x, y = house.y, z = house.z, rotation = house.rotation or 0, interior = house.interior or 0, dimension = house.dimension or 0 }
    createData.ownerSpawn = {
        x = house.spawn_x or house.x,
        y = house.spawn_y or house.y,
        z = house.spawn_z or house.z,
        rotation = house.spawn_rotation or house.rotation or 0,
        camX = house.spawn_cam_x,
        camY = house.spawn_cam_y,
        camZ = house.spawn_cam_z,
        lookX = house.spawn_look_x,
        lookY = house.spawn_look_y,
        lookZ = house.spawn_look_z,
        interior = house.spawn_interior or house.interior or 0,
        dimension = house.spawn_dimension or house.dimension or 0
    }
    createData.ownerSpawnConfigured = house.spawn_configured == true
    createData.parkings = {}
    for _, parking in ipairs(house.parkings or {}) do
        createData.parkings[tonumber(parking.slot) or #createData.parkings + 1] = parking
    end
    for i, item in ipairs(interiors) do
        if item.key == house.interior_key then createData.interiorIndex = i end
    end
    showParkingMarkers()
end

local function drawPanel(x, y, w, h)
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
end

local function drawButton(button)
    local mx, my = getCursorPosition()
    mx, my = (mx or 0) * sx, (my or 0) * sy
    local hover = button.enabled and mx >= button.x and mx <= button.x + button.w and my >= button.y and my <= button.y + button.h

    if button.style == "propertyMenu" then
        local background
        local textColor
        if not button.enabled then
            background = tocolor(14, 14, 14, 255)
            textColor = tocolor(47, 47, 47, 255)
        elseif hover then
            background = tocolor(17, 17, 17, 255)
            textColor = tocolor(255, 255, 255, 255)
        else
            background = tocolor(14, 14, 14, 255)
            textColor = tocolor(245, 245, 245, 255)
        end
        dxDrawRectangle(button.x, button.y, button.w, button.h, tocolor(0, 0, 0, 255))
        dxDrawRectangle(button.x + 1, button.y + 1, button.w - 2, button.h - 2, background)
        dxDrawRectangle(button.x + s(3), button.y + 1, button.w - s(6), 1, tocolor(18, 18, 18, 255))
        dxDrawRectangle(button.x + s(3), button.y + button.h - 2, button.w - s(6), 1, tocolor(5, 5, 5, 255))
        dxDrawText(button.text, button.x + hs(5), button.y, button.x + button.w - hs(5), button.y + button.h, textColor, 1, "default-bold", "center", "center", true)
        return
    end

    local accent = button.color or HomeConfig.colors.primary
    local bg = hover and {45, 52, 56} or {29, 35, 42}
    roundedRect(button.x, button.y, button.w, button.h, s(8), tocolor(bg[1], bg[2], bg[3], 235))
    dxDrawRectangle(button.x + s(12), button.y + button.h - s(2), button.w - s(24), s(1), tocolor(accent[1], accent[2], accent[3], hover and 150 or 90))
    dxDrawText(button.text, crisp(button.x + s(12)), crisp(button.y), crisp(button.x + button.w - s(12)), crisp(button.y + button.h), tocolor(255, 255, 255, 245), 1, "default-bold", "center", "center", true)
end

local function drawInput(input)
    local value = formValues[input.id] or ""
    local st = inputState(input.id)
    st.caret = math.max(0, math.min(len(value), st.caret or len(value)))

    if input.style == "propertyInfo" then
        local flatSalePrice = input.id == "salePrice"
        dxDrawText(input.label, input.x, input.y - s(17), input.x + input.w, input.y - s(2), rgba(HomeConfig.colors.primary), flatSalePrice and 1 or 0.9, "default-bold", "left", "center", true)
        dxDrawRectangle(input.x, input.y, input.w, input.h, tocolor(0, 0, 0, 255))
        dxDrawRectangle(input.x + 1, input.y + 1, input.w - 2, input.h - 2, flatSalePrice and tocolor(9, 9, 9, 255) or tocolor(14, 14, 14, 255))
        if not flatSalePrice then
            dxDrawRectangle(input.x + s(3), input.y + 1, input.w - s(6), 1, tocolor(18, 18, 18, 255))
            dxDrawRectangle(input.x + s(3), input.y + input.h - 2, input.w - s(6), 1, tocolor(5, 5, 5, 255))
        end
        if activeInput == input.id and hasSelection(st) then
            local a, b = selectionBounds(st)
            local selectionX = input.x + s(10) + dxGetTextWidth(sub(value, 1, a), 1, "default-bold")
            local selectionW = dxGetTextWidth(sub(value, a + 1, b), 1, "default-bold")
            dxDrawRectangle(selectionX, input.y + s(6), math.max(1, selectionW), input.h - s(12), tocolor(HomeConfig.colors.primary[1], HomeConfig.colors.primary[2], HomeConfig.colors.primary[3], 100))
        end
        local displayValue = flatSalePrice and value == "" and "введите цену" or value
        local valueColor = flatSalePrice and value == "" and tocolor(100, 100, 100, 255) or tocolor(245, 245, 245, 255)
        dxDrawText(displayValue, input.x + s(10), input.y, input.x + input.w - s(10), input.y + input.h, valueColor, 1, "default-bold", "left", "center", true)
        if activeInput == input.id and (getTickCount() % 1000) < 520 then
            local cursorX = input.x + s(10) + dxGetTextWidth(sub(value, 1, st.caret), 1, "default-bold")
            dxDrawRectangle(math.min(cursorX, input.x + input.w - s(10)), input.y + s(6), 1, input.h - s(12), tocolor(245, 245, 245, 255))
        end
        return
    end

    dxDrawText(input.label, crisp(input.x), crisp(input.y - s(18)), crisp(input.x + input.w), crisp(input.y), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    roundedRect(input.x, input.y, input.w, input.h, s(7), rgba(HomeConfig.colors.panel2, 232))
    dxDrawRectangle(input.x, input.y + input.h - 2, input.w, 2, activeInput == input.id and rgba(HomeConfig.colors.primary) or tocolor(70, 78, 88, 220))
    if activeInput == input.id and hasSelection(st) then
        local a, b = selectionBounds(st)
        local sx = input.x + s(10) + dxGetTextWidth(sub(value, 1, a), 1, "default")
        local sw = dxGetTextWidth(sub(value, a + 1, b), 1, "default")
        dxDrawRectangle(sx, input.y + s(8), math.max(1, sw), input.h - s(16), tocolor(HomeConfig.colors.primary[1], HomeConfig.colors.primary[2], HomeConfig.colors.primary[3], 115))
    end
    dxDrawText(value, crisp(input.x + s(10)), crisp(input.y), crisp(input.x + input.w - s(10)), crisp(input.y + input.h), rgba(HomeConfig.colors.white), 1, "default-bold", "left", "center", true)
    if activeInput == input.id and (getTickCount() % 1000) < 520 then
        local cursorX = input.x + s(10) + dxGetTextWidth(sub(value, 1, st.caret), 1, "default")
        dxDrawRectangle(math.min(cursorX, input.x + input.w - s(10)), input.y + s(9), 1, input.h - s(18), rgba(HomeConfig.colors.white))
    end
end

local function drawHouseMenu()
    local house = selectedHouse
    if not house then closeWindow(); return end
    local inside = getElementDimension(localPlayer) == (HomeConfig.dimensionBase + tonumber(house.id))
    local lines = {
        {"Статус", statusText(house)},
        {"Владелец", propertyOwnerName(house)},
        {"Гос. стоимость", money(house.gov_price)},
        {"Цена продажи", house.sale_price and house.sale_price > 0 and money(house.sale_price) or "-"},
        {"Класс", house.house_class and ("Класс " .. tostring(house.house_class)) or "-"},
        {"Парковки", tostring(house.parking_count or 0)},
        {"Доступ", house.locked and "Закрыт" or "Открыт"}
    }

    local actions = {}
    local own = tonumber(getElementData(localPlayer, "auth:houseId")) == tonumber(house.id)
    if inside then
        actions[#actions + 1] = { "exitHouse", "Выйти из дома" }
    elseif house.status == "free" or house.status == "sale" then
        actions[#actions + 1] = { "buy", house.status == "free" and "Купить" or "Купить у владельца" }
    end

    if own then
        if not inside then actions[#actions + 1] = { "enter", "Войти" } end
        actions[#actions + 1] = { "lock", house.locked and "Открыть дом" or "Закрыть дом" }
        actions[#actions + 1] = { "sale", house.status == "sale" and "Изменить цену продажи" or "Выставить на продажу" }
        if house.status == "sale" then actions[#actions + 1] = { "cancelSale", "Снять с продажи" } end
        actions[#actions + 1] = { "sellState", "Продать государству", HomeConfig.colors.red }
    elseif not inside and (house.status == "owned" or house.status == "sale") then
        actions[#actions + 1] = { "enter", "Войти" }
    end
    if not inside and isHomeAdmin then actions[#actions + 1] = { "admin", "Админ" } end
    actions[#actions + 1] = { "close", "Закрыть", HomeConfig.colors.muted }

    local w = s(460)
    local h = s(92) + #lines * s(27) + s(18) + #actions * s(44) + s(22)
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    drawPanel(x, y, w, h)
    dxDrawText("Дом №" .. tostring(house.number), x + s(22), y + s(14), x + w - s(22), y + s(42), rgba(HomeConfig.colors.white), homeMenuFont and 1 or 0.9, homeMenuFont or "default-bold", "left", "center", true)
    dxDrawText(house.district, x + s(22), y + s(38), x + w - s(22), y + s(60), rgba(HomeConfig.colors.primary), 1, "default-bold", "left", "center", true)

    local yy = y + s(78)
    for _, row in ipairs(lines) do
        dxDrawText(row[1], x + s(22), yy, x + s(175), yy + s(22), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
        dxDrawText(row[2], x + s(180), yy, x + w - s(22), yy + s(22), rgba(HomeConfig.colors.white), 1, "default-bold", "right", "center", true)
        yy = yy + s(27)
    end

    local btnX, btnY, btnW, btnH = x + s(22), y + h - s(22) - #actions * s(44), w - s(44), s(36)
    for index, action in ipairs(actions) do
        addButton(action[1], action[2], btnX, btnY + (index - 1) * s(44), btnW, btnH, action[3])
    end
end

drawHouseMenu = function()
    local house = selectedHouse
    if not house then closeWindow(); return end

    local inside
    if isHotel(house) then
        inside = (windowContext and windowContext.hotelInside == true) or isPlayerInsideHotelInstance(house)
    else
        local baseDimension = (HomeSystemConfig and HomeSystemConfig.dimensionBase) or HomeConfig.dimensionBase
        inside = getElementDimension(localPlayer) == (baseDimension + tonumber(house.id))
    end
    local ownHotel = isHotel(house) and house.is_tenant == true
    local ownHouse = not isHotel(house) and tonumber(getElementData(localPlayer, "auth:houseId")) == tonumber(house.id)
    local lines

    if isHotel(house) then
        local expires = tonumber(house.rent_expires_at) or 0
        lines = {
            {"Статус", statusText(house)},
            {"Арендатор", house.tenant_name or "Нет"},
            {"Цена за сутки", money(house.daily_price or house.gov_price)},
            {"Аренда до", formatRentTime(expires)},
            {"Осталось", expires > 0 and formatLeft(expires - getRealTime().timestamp) or "-"},
            {"Парковка", tostring(house.parking_count or 0) .. " / 1"},
            {"Доступ", house.locked and "Закрыт" or "Открыт"}
        }
    else
        lines = {
            {"Статус", statusText(house)},
            {"Владелец", propertyOwnerName(house)},
            {"Гос. стоимость", money(house.gov_price)},
            {"Цена продажи", house.sale_price and house.sale_price > 0 and money(house.sale_price) or "-"},
            {"Класс", house.house_class and ("Класс " .. tostring(house.house_class)) or "-"},
            {"Парковки", tostring(house.parking_count or 0)},
            {"Доступ", house.locked and "Закрыт" or "Открыт"}
        }
    end

    local actions = {}
    if isHotel(house) then
        if inside then
            if ownHotel then
                actions[#actions + 1] = { "extendHotel", "Продлить аренду" }
                actions[#actions + 1] = { "leaveHotel", "Съехать из отеля", HomeConfig.colors.red }
                actions[#actions + 1] = { "lock", house.locked and "Открыть отель" or "Закрыть отель" }
            end
            actions[#actions + 1] = { "exitHouse", "Выйти из отеля" }
        else
            if house.status == "free" then
                actions[#actions + 1] = { "rentHotel", "Арендовать" }
            elseif ownHotel then
                if not house.locked then actions[#actions + 1] = { "enter", "Войти" } end
                actions[#actions + 1] = { "lock", house.locked and "Открыть отель" or "Закрыть отель" }
            end
            if isHomeAdmin then actions[#actions + 1] = { "admin", "Админ" } end
        end
    else
        if inside then
            actions[#actions + 1] = { "exitHouse", "Выйти из дома" }
        elseif not ownHouse and (house.status == "free" or house.status == "sale") then
            actions[#actions + 1] = { "buy", house.status == "free" and "Купить" or "Купить у владельца" }
        end

        if ownHouse then
            if not inside then actions[#actions + 1] = { "enter", "Войти" } end
            actions[#actions + 1] = { "lock", house.locked and "Открыть дом" or "Закрыть дом" }
            if inside then
                actions[#actions + 1] = { "sale", house.status == "sale" and "Изменить цену продажи" or "Выставить на продажу" }
                if house.status == "sale" then actions[#actions + 1] = { "cancelSale", "Снять с продажи" } end
                actions[#actions + 1] = { "houseInfo", "Информация о доме" }
            end
        elseif inside and not house.locked then
            actions[#actions + 1] = { "houseInfo", "Информация о доме" }
        elseif not inside and (house.status == "owned" or house.status == "sale") then
            actions[#actions + 1] = { "enter", "Войти" }
        end
        if not inside and isHomeAdmin then actions[#actions + 1] = { "admin", "Админ" } end
    end
    local compactActions = {}
    local hasLockAction = false
    for _, action in ipairs(actions) do
        if action[1] == "lock" then
            hasLockAction = true
            compactActions[#compactActions + 1] = { "lock", "Открыть замок", nil, house.locked == true }
            compactActions[#compactActions + 1] = { "lock", "Закрыть замок", nil, house.locked ~= true }
        else
            compactActions[#compactActions + 1] = action
        end
    end
    if not hasLockAction then
        local lockIndex = math.min(2, #compactActions + 1)
        table.insert(compactActions, lockIndex, { "lock", "Открыть замок", nil, false })
        table.insert(compactActions, lockIndex + 1, { "lock", "Закрыть замок", nil, false })
    end
    compactActions[#compactActions + 1] = { "close", "Закрыть", HomeConfig.colors.muted }
    actions = compactActions

    local baseMenuW = hs(230)
    local buttonH = s(30)
    local buttonGap = s(5)
    local buttonStep = buttonH + buttonGap
    local topPadding = s(35)
    local bottomPadding = s(10)
    local baseButtonW = baseMenuW - hs(20)
    local btnW = crisp(baseButtonW * 1.05)
    local edgePadding = s(10)
    local w = btnW + edgePadding * 2
    local h = topPadding + math.max(0, #actions - 1) * buttonStep + buttonH + bottomPadding
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))

    local title = (isHotel(house) and "ОТЕЛЬ №" or "ДОМ №") .. tostring(house.number)
    local titleFont = homeMenuFont or "default-bold"
    local titleScale = homeMenuFont and 1 or 0.9
    dxDrawText(title, x + hs(10), y + hs(2), x + w - hs(10), y + hs(30), tocolor(245, 245, 245, 255), titleScale, titleFont, "left", "center", true)

    local btnX = x + edgePadding
    local btnY, btnH = y + topPadding, buttonH
    for index, action in ipairs(actions) do
        addButton(action[1], action[2], btnX, btnY + (index - 1) * buttonStep, btnW, btnH, action[3], action[4], "propertyMenu")
    end
end

local function drawBuyInfo()
    local house = selectedHouse
    if not house then closeWindow(); return end
    local ownerInfo = not isHotel(house) and tonumber(getElementData(localPlayer, "auth:houseId")) == tonumber(house.id)

    local w, h = s(400), s(260)
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))

    local titleFont = homeMenuFont or "default-bold"
    local titleScale = homeMenuFont and 1 or 0.9
    dxDrawText("ИНФОРМАЦИЯ", x + s(10), y + s(5), x + w - s(10), y + s(36), tocolor(245, 245, 245, 255), titleScale, titleFont, "left", "center", true)

    local purchasePrice = house.status == "sale" and tonumber(house.sale_price) or tonumber(house.gov_price)
    purchasePrice = purchasePrice or 0
    local leftRows = {
        { "номер", tostring(house.number or "-") },
        { "класс", tostring(house.house_class or "-") },
        { "начальная цена", money(house.gov_price or 0) }
    }
    local rightRows = {
        { "парковочных мест", tostring(house.parking_count or 0) },
        { "район", tostring(house.district or "-") },
        { "владелец", propertyOwnerName(house) },
        { house.status == "sale" and "выставлен на продажу за" or "стоимость покупки", money(purchasePrice) }
    }

    local labelColor = rgba(HomeConfig.colors.primary)
    local valueColor = tocolor(245, 245, 245, 255)
    local function drawInfoRows(rows, left, right)
        for index, row in ipairs(rows) do
            local rowY = y + s(43) + (index - 1) * s(35)
            dxDrawText(row[1], left, rowY, right, rowY + s(13), labelColor, 0.90, "default-bold", "left", "center", true)
            dxDrawText(row[2], left, rowY + s(10), right, rowY + s(28), valueColor, 1, "default-bold", "left", "center", true)
        end
    end
    drawInfoRows(leftRows, x + s(14), x + s(190))
    drawInfoRows(rightRows, x + s(228), x + w - s(14))

    local buttonY = y + h - s(35)
    if ownerInfo then
        addButton("sellState", "Продать государству", x + s(5), buttonY, s(160), s(30), nil, true, "propertyMenu")
    else
        local canBuy = house.status == "free" or house.status == "sale"
        addButton("confirmBuy", "Купить", x + s(5), buttonY, s(160), s(30), nil, canBuy, "propertyMenu")
    end
    addButton("backHouse", "Назад", x + w - s(115), buttonY, s(110), s(30), nil, true, "propertyMenu")
end

local function drawCreateLike(isAdminEdit)
    local count = parkingCount()
    local slotRows = count > 0 and math.ceil(math.min(count, 20) / 5) or 0
    local formRowsH = isAdminEdit and s(228) or s(152)
    local contentH = formRowsH + s(236) + slotRows * s(30)
    local actionH = isAdminEdit and s(180) or s(96)
    local w = s(560)
    local h = math.min(s(720), s(82) + contentH + actionH + s(26))
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    drawPanel(x, y, w, h)
    dxDrawText(isAdminEdit and ("Редактирование дома #" .. tostring(selectedHouse.number)) or "Создание дома", x + s(22), y + s(16), x + w - s(22), y + s(48), rgba(HomeConfig.colors.white), homeMenuFont and 1 or 0.9, homeMenuFont or "default-bold", "left", "center", true)

    local startY = y + s(82)
    addInput("number", "Номер дома", isAdminEdit and selectedHouse.number or "", x + s(24), startY, s(240))
    addInput("district", "Район", isAdminEdit and selectedHouse.district or "", x + s(296), startY, s(240))
    addInput("price", "Государственная цена", isAdminEdit and selectedHouse.gov_price or "", x + s(24), startY + s(76), s(240))
    addInput("parking", "Количество парковок", isAdminEdit and selectedHouse.parking_count or "0", x + s(296), startY + s(76), s(240))
    if isAdminEdit then addInput("owner", "Назначить владельца по ID аккаунта", "", x + s(24), startY + s(152), s(512)) end

    local iy = isAdminEdit and startY + s(228) or startY + s(152)
    local interior = interiors[createData.interiorIndex] or interiors[1]
    dxDrawText("Класс дома: " .. tostring(interior.class or "-") .. " (" .. tostring(interior.className or interior.name or "-") .. ")", x + s(24), iy, x + w - s(24), iy + s(30), rgba(HomeConfig.colors.primary), 1, "default-bold", "left", "center", true)
    addButton("intPrev", "<", x + w - s(118), iy, s(40), s(30))
    addButton("intNext", ">", x + w - s(70), iy, s(40), s(30))

    local ep = createData.entrance
    dxDrawText(string.format("Вход: %.2f, %.2f, %.2f | ID внутр. %d, измерение %d", ep.x, ep.y, ep.z, ep.interior, ep.dimension), x + s(24), iy + s(46), x + w - s(24), iy + s(70), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    dxDrawText("Точка входа зафиксирована при /createhouse.", x + s(24), iy + s(70), x + w - s(24), iy + s(94), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    local sp = createData.ownerSpawn or ep
    dxDrawText(string.format("Спавн у дома: %.2f, %.2f, %.2f%s", sp.x, sp.y, sp.z, createData.ownerSpawnConfigured and "" or " (по умолчанию)"), x + s(24), iy + s(94), x + w - s(24), iy + s(118), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    addButton("setupSpawn", "Выбрать место появления", x + s(24), iy + s(124), w - s(48), s(34))

    addButton("setupParking", count == 0 and "Парковки не нужны" or "Настроить парковки", x + s(24), iy + s(166), w - s(48), s(34))
    dxDrawText("Сохранено парковок: " .. tostring(savedParkingCount()) .. " / " .. tostring(count), x + s(24), iy + s(206), x + w - s(24), iy + s(230), rgba(HomeConfig.colors.muted), 1, "default", "left", "center")
    if count > 0 then
        local slotW = math.floor((w - s(48) - s(8) * 4) / 5)
        for i = 1, math.min(count, 20) do
            local bx = x + s(24) + ((i - 1) % 5) * (slotW + s(8))
            local by = iy + s(238) + math.floor((i - 1) / 5) * s(30)
            addButton("repark:" .. tostring(i), tostring(i), bx, by, slotW, s(24), createData.parkings[i] and HomeConfig.colors.green or HomeConfig.colors.muted)
        end
    end

    local actionX, actionW, actionH = x + s(24), w - s(48), s(34)
    local actionY = y + h - (isAdminEdit and s(180) or s(92))
    addButton(isAdminEdit and "saveAdmin" or "create", isAdminEdit and "Сохранить" or "Создать дом", actionX, actionY, actionW, actionH)
    if isAdminEdit then
        addButton("freeHouse", "Освободить дом", actionX, actionY + s(42), actionW, actionH, HomeConfig.colors.red)
        addButton("deleteHouse", "Удалить дом", actionX, actionY + s(84), actionW, actionH, HomeConfig.colors.red)
        addButton("close", "Закрыть", actionX, actionY + s(126), actionW, actionH, HomeConfig.colors.muted)
    else
        addButton("close", "Закрыть", actionX, actionY + s(42), actionW, actionH, HomeConfig.colors.muted)
    end
end

drawCreateLike = function(isAdminEdit)
    local hotelMode = createData and createData.propertyType == "hotel" or isHotel(selectedHouse)
    local count = parkingCount()
    local slotRows = count > 0 and math.ceil(math.min(count, 20) / 5) or 0
    local hasOwnerInput = isAdminEdit and not hotelMode
    local formRowsH = hasOwnerInput and s(228) or s(152)
    local extraH = hotelMode and s(244) or s(236)
    local contentH = formRowsH + extraH + slotRows * s(30)
    local actionH = isAdminEdit and s(180) or s(96)
    local w = s(560)
    local h = math.min(s(720), s(82) + contentH + actionH + s(26))
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    drawPanel(x, y, w, h)

    local title
    if isAdminEdit then
        title = (hotelMode and "Редактирование отеля №" or "Редактирование дома №") .. tostring(selectedHouse.number)
    else
        title = hotelMode and "Создание отеля" or "Создание дома"
    end
    dxDrawText(title, x + s(22), y + s(16), x + w - s(22), y + s(48), rgba(HomeConfig.colors.white), homeMenuFont and 1 or 0.9, homeMenuFont or "default-bold", "left", "center", true)

    local startY = y + s(82)
    addInput("number", hotelMode and "Номер отеля" or "Номер дома", isAdminEdit and selectedHouse.number or "", x + s(24), startY, s(240))
    addInput("district", "Район", isAdminEdit and selectedHouse.district or "", x + s(296), startY, s(240))
    addInput("price", hotelMode and "Цена аренды за сутки" or "Государственная цена", isAdminEdit and ((hotelMode and selectedHouse.daily_price) or selectedHouse.gov_price) or "", x + s(24), startY + s(76), s(240))
    if hotelMode then
        addInput("parking", "Парковка", "1", x + s(296), startY + s(76), s(240))
    else
        addInput("parking", "Количество парковок", isAdminEdit and selectedHouse.parking_count or "0", x + s(296), startY + s(76), s(240))
    end
    if hasOwnerInput then addInput("owner", "Назначить владельца по ID аккаунта", "", x + s(24), startY + s(152), s(512)) end

    local iy = startY + (hasOwnerInput and s(228) or s(152))
    if hotelMode then
        dxDrawText("Интерьер отеля: общий гостиничный номер", x + s(24), iy, x + w - s(24), iy + s(30), rgba(HomeConfig.colors.primary), 1, "default-bold", "left", "center", true)
    else
        local interior = interiors[createData.interiorIndex] or interiors[1]
        dxDrawText("Класс дома: " .. tostring(interior.class or "-") .. " (" .. tostring(interior.className or interior.name or "-") .. ")", x + s(24), iy, x + w - s(24), iy + s(30), rgba(HomeConfig.colors.primary), 1, "default-bold", "left", "center", true)
        addButton("intPrev", "<", x + w - s(118), iy, s(40), s(30))
        addButton("intNext", ">", x + w - s(70), iy, s(40), s(30))
    end

    local ep = createData.entrance
    dxDrawText(string.format("Вход: %.2f, %.2f, %.2f | интерьер %d, dimension %d", ep.x, ep.y, ep.z, ep.interior, ep.dimension), x + s(24), iy + s(46), x + w - s(24), iy + s(70), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    dxDrawText(hotelMode and "Точка входа зафиксирована при /createhotel." or "Точка входа зафиксирована при /createhouse.", x + s(24), iy + s(70), x + w - s(24), iy + s(94), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    local sp = createData.ownerSpawn or ep
    dxDrawText(string.format("%s: %.2f, %.2f, %.2f%s", hotelMode and "Спавн у отеля" or "Спавн у дома", sp.x, sp.y, sp.z, createData.ownerSpawnConfigured and "" or " (по умолчанию)"), x + s(24), iy + s(94), x + w - s(24), iy + s(118), rgba(HomeConfig.colors.muted), 1, "default", "left", "center", true)
    addButton("setupSpawn", "Выбрать место появления", x + s(24), iy + s(124), w - s(48), s(34))

    addButton("setupParking", hotelMode and "Настроить парковку" or (count == 0 and "Парковки не нужны" or "Настроить парковки"), x + s(24), iy + s(166), w - s(48), s(34))
    dxDrawText("Сохранено парковок: " .. tostring(savedParkingCount()) .. " / " .. tostring(count), x + s(24), iy + s(206), x + w - s(24), iy + s(230), rgba(HomeConfig.colors.muted), 1, "default", "left", "center")
    if count > 0 then
        local slotW = math.floor((w - s(48) - s(8) * 4) / 5)
        for i = 1, math.min(count, 20) do
            local bx = x + s(24) + ((i - 1) % 5) * (slotW + s(8))
            local by = iy + s(238) + math.floor((i - 1) / 5) * s(30)
            addButton("repark:" .. tostring(i), tostring(i), bx, by, slotW, s(24), createData.parkings[i] and HomeConfig.colors.green or HomeConfig.colors.muted)
        end
    end

    local actionX, actionW, actionH = x + s(24), w - s(48), s(34)
    local actionY = y + h - (isAdminEdit and s(180) or s(92))
    addButton(isAdminEdit and "saveAdmin" or "create", isAdminEdit and "Сохранить" or (hotelMode and "Создать отель" or "Создать дом"), actionX, actionY, actionW, actionH)
    if isAdminEdit then
        addButton("freeHouse", hotelMode and "Выселить арендатора" or "Освободить дом", actionX, actionY + s(42), actionW, actionH, HomeConfig.colors.red)
        addButton("deleteHouse", hotelMode and "Удалить отель" or "Удалить дом", actionX, actionY + s(84), actionW, actionH, HomeConfig.colors.red)
        addButton("close", "Закрыть", actionX, actionY + s(126), actionW, actionH, HomeConfig.colors.muted)
    else
        addButton("close", "Закрыть", actionX, actionY + s(42), actionW, actionH, HomeConfig.colors.muted)
    end
end

local function drawSale()
    local house = selectedHouse
    if not house then closeWindow(); return end
    local w, h = s(400), s(170)
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + s(1), y + s(1), w - s(2), h - s(2), tocolor(0, 0, 0, 130))

    local titleScale = homeMenuFont and 1 or 0.9
    dxDrawText("ВЫСТАВИТЬ НА ПРОДАЖУ", x + s(10), y + s(5), x + w - s(10), y + s(36), rgba(HomeConfig.colors.white), titleScale, homeMenuFont or "default-bold", "left", "center", true)
    addInput("salePrice", "цена продажи", house.sale_price and house.sale_price > 0 and house.sale_price or "", x + s(14), y + s(64), w - s(28), s(30), "propertyInfo")

    local buttonY = y + h - s(35)
    addButton("confirmSale", "Сохранить", x + s(5), buttonY, s(160), s(30), nil, true, "propertyMenu")
    addButton("backHouse", "Назад", x + w - s(115), buttonY, s(110), s(30), nil, true, "propertyMenu")
end

local function drawSellStateConfirm()
    local house = selectedHouse
    if not house then closeWindow(); return end
    local percent = tonumber((HomeSystemConfig and HomeSystemConfig.stateSellPercent) or HomeConfig.stateSellPercent) or 50
    local refund = math.floor((tonumber(house.gov_price) or 0) * percent / 100)
    local w, h = s(400), s(170)
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + s(1), y + s(1), w - s(2), h - s(2), tocolor(0, 0, 0, 130))

    local titleScale = homeMenuFont and 1 or 0.9
    dxDrawText("ПРОДАЖА ГОСУДАРСТВУ", x + s(10), y + s(5), x + w - s(10), y + s(36), rgba(HomeConfig.colors.white), titleScale, homeMenuFont or "default-bold", "left", "center", true)
    dxDrawText("Вы действительно хотите продать дом государству?\nВы получите " .. money(refund) .. ".", x + s(14), y + s(43), x + w - s(14), y + s(122), rgba(HomeConfig.colors.white), 1, "default-bold", "center", "center", true, true)

    local buttonY = y + h - s(35)
    addButton("confirmSellState", "Да", x + s(5), buttonY, s(110), s(30), nil, true, "propertyMenu")
    addButton("backHouseInfo", "Нет", x + w - s(115), buttonY, s(110), s(30), nil, true, "propertyMenu")
end

local function drawExtendHotel()
    local hotel = selectedHouse
    if not hotel then closeWindow(); return end
    local maxDays = (HotelSystemConfig and tonumber(HotelSystemConfig.maxExtendDays)) or tonumber(HomeConfig.hotelMaxExtendDays) or 14
    local days = math.max(1, math.min(maxDays, math.floor(tonumber(inputValue("extendDays")) or 1)))
    local daily = tonumber(hotel.daily_price or hotel.gov_price) or 0
    local total = days * daily
    local base = math.max(getRealTime().timestamp, tonumber(hotel.rent_expires_at) or getRealTime().timestamp)
    local rentSeconds = (HotelSystemConfig and tonumber(HotelSystemConfig.rentSeconds)) or tonumber(HomeConfig.hotelRentSeconds) or 86400
    local newExpires = base + days * rentSeconds
    local w, h = s(400), s(220)
    local x, y = crisp((sx - w) / 2), crisp((sy - h) / 2)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + s(1), y + s(1), w - s(2), h - s(2), tocolor(0, 0, 0, 130))

    local titleScale = homeMenuFont and 1 or 0.9
    dxDrawText("ПРОДЛЕНИЕ АРЕНДЫ", x + s(10), y + s(5), x + w - s(10), y + s(36), rgba(HomeConfig.colors.white), titleScale, homeMenuFont or "default-bold", "left", "center", true)

    local stepperX, stepperY = x + s(14), y + s(89)
    local stepperW, arrowW = s(170), s(42)
    dxDrawText("количество дней (1-" .. tostring(maxDays) .. ")", stepperX, stepperY - s(17), stepperX + stepperW, stepperY - s(2), rgba(HomeConfig.colors.primary), 0.9, "default-bold", "left", "center", true)
    addButton("extendDaysDec", "<<", stepperX, stepperY, arrowW, s(30), nil, days > 1, "propertyMenu")
    addButton("extendDaysInc", ">>", stepperX + stepperW - arrowW, stepperY, arrowW, s(30), nil, days < maxDays, "propertyMenu")
    dxDrawRectangle(stepperX + arrowW + s(2), stepperY, stepperW - arrowW * 2 - s(4), s(30), tocolor(0, 0, 0, 255))
    dxDrawRectangle(stepperX + arrowW + s(3), stepperY + 1, stepperW - arrowW * 2 - s(6), s(28), tocolor(14, 14, 14, 255))
    dxDrawText(tostring(days), stepperX + arrowW + s(4), stepperY, stepperX + stepperW - arrowW - s(4), stepperY + s(30), rgba(HomeConfig.colors.white), 1, "default-bold", "center", "center", true)

    local labelColor = rgba(HomeConfig.colors.primary)
    local valueColor = rgba(HomeConfig.colors.white)
    local function drawGroup(label, value, left, top, right)
        dxDrawText(label, left, top, right, top + s(13), labelColor, 0.9, "default-bold", "left", "center", true)
        dxDrawText(value, left, top + s(10), right, top + s(28), valueColor, 1, "default-bold", "left", "center", true)
    end

    drawGroup("цена за сутки", money(daily), x + s(228), y + s(47), x + w - s(14))
    drawGroup("итого", money(total), x + s(228), y + s(82), x + w - s(14))
    drawGroup("новая дата", formatRentTime(newExpires), x + s(228), y + s(117), x + w - s(14))

    addButton("confirmExtendHotel", "Продлить", x + s(5), y + h - s(35), s(160), s(30), nil, true, "propertyMenu")
    addButton("backHouse", "Назад", x + w - s(115), y + h - s(35), s(110), s(30), nil, true, "propertyMenu")
end

local function drawSetupHint()
    if not setup then return end
    local text
    if setup.type == "spawn" then
        text = "Встаньте в точку появления владельца возле дома и нажмите " .. string.upper(HomeConfig.parkingSetupKey or "h") .. ". Backspace - отмена."
    else
        text = "Установите персонажа или тестовый транспорт на место парковки №" .. tostring(setup.slot) .. " и нажмите " .. string.upper(HomeConfig.parkingSetupKey or "h") .. ". Backspace - отмена."
    end
    dxDrawRectangle(sx / 2 - s(380), s(28), s(760), s(54), rgba(HomeConfig.colors.panel))
    dxDrawText(text, sx / 2 - s(360), s(28), sx / 2 + s(360), s(82), rgba(HomeConfig.colors.white), 1, "default-bold", "center", "center", true, true)
end

addEventHandler("onClientRender", root, function()
    local px, py, pz = getElementPosition(localPlayer)
    local labelCfg = HomeConfig.propertyLabel or {}
    local labelDistance = tonumber(labelCfg.distance) or 12
    for _, house in pairs(houses) do
        local distance = getDistanceBetweenPoints3D(px, py, pz, house.x, house.y, house.z)
        if distance <= labelDistance and getElementInterior(localPlayer) == (house.interior or 0) and getElementDimension(localPlayer) == (house.dimension or 0) then
            local x, y = getScreenFromWorldPosition(house.x, house.y, house.z + (tonumber(labelCfg.zOffset) or 2.25))
            if x and y then
                local hotel = isHotel(house)
                local text = (hotel and "Отель №" or "Дом №") .. tostring(house.number)
                local textColor = hotel and (labelCfg.hotelColor or HomeConfig.colors.red) or (labelCfg.houseColor or HomeConfig.colors.primary)
                local outlineColor = labelCfg.outlineColor or {0, 0, 0, 220}
                local font = tostring(labelCfg.font or "default-bold")
                local textScale = tonumber(labelCfg.scale) or 0.9
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        if ox ~= 0 or oy ~= 0 then
                            dxDrawText(text, x - s(90) + ox, y - s(14) + oy, x + s(90) + ox, y + s(14) + oy, rgba(outlineColor), textScale, font, "center", "center", true)
                        end
                    end
                end
                dxDrawText(text, x - s(90), y - s(14), x + s(90), y + s(14), rgba(textColor), textScale, font, "center", "center", true)
            end
        end
    end
    drawSetupHint()
    if not window then return end
    buttons, inputs = {}, {}
    if window == "house" then drawHouseMenu()
    elseif window == "buy" then drawBuyInfo()
    elseif window == "create" then drawCreateLike(false)
    elseif window == "admin" then drawCreateLike(true)
    elseif window == "sale" then drawSale()
    elseif window == "sellStateConfirm" then drawSellStateConfirm()
    elseif window == "extendHotel" then drawExtendHotel() end
    for _, input in ipairs(inputs) do drawInput(input) end
    for _, button in ipairs(buttons) do drawButton(button) end
end)

local function rebuildMarkers()
    for _, marker in pairs(houseMarkers) do if isElement(marker) then destroyElement(marker) end end
    houseMarkers = {}
    for _, house in pairs(houses) do
        local cfg = isHotel(house) and (HotelSystemConfig and HotelSystemConfig.outsideMarker or nil) or (HomeSystemConfig and HomeSystemConfig.marker or nil)
        cfg = cfg or {}
        local color = cfg.color or {79, 195, 247}
        local markerType = tostring(cfg.type or "cylinder")
        local defaultZOffset = markerType == "arrow" and 1.0 or -1.0
        local marker = createMarker(house.x, house.y, house.z + (tonumber(cfg.zOffset) or defaultZOffset), markerType, cfg.size or HomeConfig.markerSize or 1.0, color[1], color[2], color[3], cfg.alpha or HomeConfig.markerAlpha or 180)
        setElementInterior(marker, house.interior or 0)
        setElementDimension(marker, house.dimension or 0)
        if isHotel(house) then
            setElementData(marker, "hotel:hotelId", tonumber(house.hotel_id) or math.abs(tonumber(house.id) or 0), false)
        else
            setElementData(marker, "home:houseId", house.id, false)
        end
        houseMarkers[house.id] = marker
    end
end

local function collectPayload(isAdminEdit)
    local count = parkingCount()
    local parkings = {}
    for i = 1, count do
        if not createData.parkings[i] then return false end
        parkings[i] = createData.parkings[i]
    end
    local p = createData.entrance
    local sp = createData.ownerSpawn or p
    return {
        property_type = createData.propertyType or "house",
        number = inputValue("number"),
        district = inputValue("district"),
        gov_price = inputValue("price"),
        daily_price = inputValue("price"),
        parking_count = count,
        interior_key = currentInteriorKey(),
        x = p.x, y = p.y, z = p.z,
        rotation = p.rotation,
        interior = p.interior,
        dimension = p.dimension,
        spawn_x = sp.x,
        spawn_y = sp.y,
        spawn_z = sp.z,
        spawn_rotation = sp.rotation,
        spawn_cam_x = sp.camX,
        spawn_cam_y = sp.camY,
        spawn_cam_z = sp.camZ,
        spawn_look_x = sp.lookX,
        spawn_look_y = sp.lookY,
        spawn_look_z = sp.lookZ,
        spawn_interior = sp.interior,
        spawn_dimension = sp.dimension,
        spawn_configured = createData.ownerSpawnConfigured == true,
        parkings = parkings,
        owner_account_id = isAdminEdit and inputValue("owner") or nil,
        locked = selectedHouse and selectedHouse.locked
    }
end

local function reopenSetupWindow()
    local kind = setup.window
    local house = setup.house
    local values = setup.formValues or {}
    setup = nil
    showParkingMarkers()
    if kind == "admin" and house then
        beginWindow("admin", house)
    else
        beginWindow("create")
    end
    formValues = values
end

local function startParkingSetup(slot)
    local count = parkingCount()
    if count <= 0 then return end
    slot = tonumber(slot)
    if not slot then
        slot = 1
        while createData.parkings[slot] and slot <= count do slot = slot + 1 end
        if slot > count then slot = 1 end
    end
    setup = { type = "parking", slot = slot, window = window, house = selectedHouse, formValues = copyFormValues() }
    closeWindow(true)
    showCursor(false)
    guiSetInputMode("allow_binds")
end

local function startSpawnSetup()
    setup = { type = "spawn", window = window, house = selectedHouse, formValues = copyFormValues() }
    closeWindow(true)
    showCursor(false)
    guiSetInputMode("allow_binds")
end

local function saveSetupSlot()
    if not setup then return end
    if setup.type == "spawn" then
        createData.ownerSpawn = playerSpawnPointData()
        createData.ownerSpawnConfigured = true
        reopenSetupWindow()
        return
    end
    createData.parkings[setup.slot] = playerPositionData()
    local count = parkingCount()
    local nextSlot = setup.slot + 1
    while nextSlot <= count and createData.parkings[nextSlot] do nextSlot = nextSlot + 1 end
    if nextSlot <= count then
        setup.slot = nextSlot
        showParkingMarkers()
        return
    end
    reopenSetupWindow()
end

local function cancelSetup()
    if not setup then return end
    reopenSetupWindow()
end

local function clickButton(id)
    if id == "close" then closeWindow()
    elseif id == "buy" then beginWindow("buy", selectedHouse)
    elseif id == "houseInfo" then beginWindow("buy", selectedHouse, { ownerInfo = true })
    elseif id == "confirmBuy" then triggerServerEvent("home:buy", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "backHouse" then beginWindow("house", selectedHouse)
    elseif id == "backHouseInfo" then beginWindow("buy", selectedHouse, { ownerInfo = true })
    elseif id == "rentHotel" then triggerServerEvent("hotel:rent", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "enter" then triggerServerEvent(isHotel(selectedHouse) and "hotel:enter" or "home:enter", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "exitHouse" then triggerServerEvent(isHotel(selectedHouse) and "hotel:exit" or "home:exit", localPlayer, isHotel(selectedHouse) and selectedHouse.id or nil); closeWindow()
    elseif id == "extendHotel" then openExtendHotel(selectedHouse)
    elseif id == "extendDaysDec" then
        formValues.extendDays = tostring(math.max(1, math.floor(tonumber(inputValue("extendDays")) or 1) - 1))
    elseif id == "extendDaysInc" then
        local maxDays = (HotelSystemConfig and tonumber(HotelSystemConfig.maxExtendDays)) or tonumber(HomeConfig.hotelMaxExtendDays) or 14
        formValues.extendDays = tostring(math.min(maxDays, math.floor(tonumber(inputValue("extendDays")) or 1) + 1))
    elseif id == "confirmExtendHotel" then triggerServerEvent("hotel:extend", localPlayer, selectedHouse.id, inputValue("extendDays")); closeWindow()
    elseif id == "leaveHotel" then triggerServerEvent("hotel:leave", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "lock" then triggerServerEvent(isHotel(selectedHouse) and "hotel:toggleLock" or "home:toggleLock", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "sellState" then beginWindow("sellStateConfirm", selectedHouse)
    elseif id == "confirmSellState" then triggerServerEvent("home:sellState", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "cancelSale" then triggerServerEvent("home:cancelSale", localPlayer, selectedHouse.id); closeWindow()
    elseif id == "sale" then openSale(selectedHouse)
    elseif id == "confirmSale" then triggerServerEvent("home:setSalePrice", localPlayer, selectedHouse.id, inputValue("salePrice")); closeWindow()
    elseif id == "admin" and isHomeAdmin then openAdminEdit(selectedHouse)
    elseif id == "intPrev" then createData.interiorIndex = createData.interiorIndex <= 1 and #interiors or createData.interiorIndex - 1
    elseif id == "intNext" then createData.interiorIndex = createData.interiorIndex >= #interiors and 1 or createData.interiorIndex + 1
    elseif id == "setupSpawn" then startSpawnSetup()
    elseif id == "setupParking" then startParkingSetup()
    elseif id:sub(1, 7) == "repark:" then startParkingSetup(tonumber(id:sub(8)))
    elseif id == "create" then
        local payload = collectPayload(false)
        if payload then
            triggerServerEvent(createData.propertyType == "hotel" and "hotel:create" or "home:create", localPlayer, payload)
            closeWindow()
        end
    elseif id == "saveAdmin" then
        local payload = collectPayload(true)
        if payload then triggerServerEvent(isHotel(selectedHouse) and "hotel:adminUpdate" or "home:adminUpdate", localPlayer, selectedHouse.id, payload); closeWindow() end
    elseif id == "freeHouse" then triggerServerEvent(isHotel(selectedHouse) and "hotel:adminUpdate" or "home:adminUpdate", localPlayer, selectedHouse.id, { free = true }); closeWindow()
    elseif id == "deleteHouse" then triggerServerEvent(isHotel(selectedHouse) and "hotel:adminUpdate" or "home:adminUpdate", localPlayer, selectedHouse.id, { delete = true }); closeWindow()
    end
end

addEvent("home:syncHouses", true)
addEventHandler("home:syncHouses", resourceRoot, function(list)
    houses = {}
    for _, house in ipairs(list or {}) do
        local id = tonumber(house.id) or house.id
        house.id = id
        houses[id] = house
    end
    if gpsHouseId and not houses[gpsHouseId] then
        if isElement(gpsBlip) then destroyElement(gpsBlip) end
        gpsBlip, gpsHouseId = nil, nil
    end
    if selectedHouse and selectedHouse.id and not houses[selectedHouse.id] then
        closeWindow()
    elseif selectedHouse and selectedHouse.id and houses[selectedHouse.id] then
        selectedHouse = houses[selectedHouse.id]
    end
    rebuildMarkers()
end)

addEvent("home:setAdminState", true)
addEventHandler("home:setAdminState", resourceRoot, function(state)
    isHomeAdmin = state == true
end)

addEvent("home:openCreatePanel", true)
addEventHandler("home:openCreatePanel", resourceRoot, openCreate)

addEvent("home:openCreateHotelPanel", true)
addEventHandler("home:openCreateHotelPanel", resourceRoot, openCreateHotel)

addEvent("hotel:openCreatePanel", true)
addEventHandler("hotel:openCreatePanel", resourceRoot, openCreateHotel)

addEventHandler("onClientResourceStart", resourceRoot, function()
    homeMenuFont = dxCreateFont(":rp_core/CompactC.ttf", hs(13), false, "cleartype")
    triggerServerEvent("home:requestSync", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    releaseHomeUI()
    destroyParkingMarkers()
end)

addEventHandler("onClientMarkerHit", root, function(player, matchingDimension)
    if player ~= localPlayer or not matchingDimension then return end
    if isPedInVehicle(localPlayer) then return end
    local hotelControlId = getElementData(source, "hotel:controlHotelId")
    if hotelControlId then
        local house = houses[hotelPublicId(hotelControlId)]
        if house then
            if HomeConfig.DebugMode then
                outputDebugString("[RP HOME] Hotel interior marker hit", 3)
                outputDebugString("[RP HOME] Opening hotel menu", 3)
                outputDebugString("[RP HOME] Menu context: hotelInside=true, player dimension=" .. tostring(getElementDimension(localPlayer)), 3)
            end
            beginWindow("house", house, { hotelInside = true, marker = source })
        else
            if HomeConfig.DebugMode then
                outputDebugString("[RP HOME] Hotel interior marker hit, but synced hotel data is missing. Hotel ID: " .. tostring(hotelControlId), 2)
            end
            triggerServerEvent("home:requestSync", localPlayer)
        end
        return
    end
    local outsideHotelId = getElementData(source, "hotel:hotelId")
    if outsideHotelId then
        local house = houses[hotelPublicId(outsideHotelId)]
        if house then
            beginWindow("house", house, isPlayerInsideHotelInstance(house) and { hotelInside = true, marker = source } or nil)
        end
        return
    end
    local houseId = getElementData(source, "home:houseId") or getElementData(source, "home:controlHouseId")
    local normalizedId = tonumber(houseId) or houseId
    local house = houses[normalizedId] or houses[houseId]
    if house then
        beginWindow("house", house, isPlayerInsideHotelInstance(house) and { hotelInside = true, marker = source } or nil)
        return
    end
end)

addEventHandler("onClientClick", root, function(button, state, cx, cy)
    if button ~= "left" or state ~= "down" or not window then return end
    activeInput = nil
    for _, input in ipairs(inputs) do
        if cx >= input.x and cx <= input.x + input.w and cy >= input.y and cy <= input.y + input.h then
            activeInput = input.id
            local pos = caretFromInputX(input, cx)
            local st = inputState(input.id)
            st.caret = pos
            st.selectionStart = pos
            st.selectionEnd = pos
            st.dragAnchor = pos
            st.mouseSelecting = true
            return
        end
    end
    for _, item in ipairs(buttons) do
        if item.enabled and cx >= item.x and cx <= item.x + item.w and cy >= item.y and cy <= item.y + item.h then
            clickButton(item.id)
            return
        end
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if activeInput then insertInputText(activeInput, char) end
end)

addEventHandler("onClientKey", root, function(key, press)
    if not press then return end
    if setup then
        if key == (HomeConfig.parkingSetupKey or "h") then saveSetupSlot(); cancelEvent(); return end
        if key == "backspace" or key == "escape" then cancelSetup(); cancelEvent(); return end
    end
    if key == "escape" and window then closeWindow(); cancelEvent(); return end
    if activeInput then
        local value = formValues[activeInput] or ""
        local st = inputState(activeInput)
        local ctrl = getKeyState("lctrl") or getKeyState("rctrl")
        local shift = getKeyState("lshift") or getKeyState("rshift")

        if ctrl and key == "a" then
            st.selectionStart = 0
            st.selectionEnd = len(value)
            st.caret = len(value)
            cancelEvent()
            return
        elseif ctrl and key == "c" then
            if hasSelection(st) then
                local a, b = selectionBounds(st)
                setClipboard(sub(value, a + 1, b))
            end
            cancelEvent()
            return
        elseif ctrl and key == "x" then
            if hasSelection(st) then
                local a, b = selectionBounds(st)
                setClipboard(sub(value, a + 1, b))
                deleteSelection(activeInput)
            end
            cancelEvent()
            return
        elseif ctrl and key == "v" then
            return
        elseif key == "backspace" then
            if not deleteSelection(activeInput) and st.caret > 0 then
                formValues[activeInput] = sub(value, 1, st.caret - 1) .. sub(value, st.caret + 1)
                setCaret(activeInput, st.caret - 1)
            end
        elseif key == "delete" then
            if not deleteSelection(activeInput) and st.caret < len(value) then
                formValues[activeInput] = sub(value, 1, st.caret) .. sub(value, st.caret + 2)
                setCaret(activeInput, st.caret)
            end
        elseif key == "arrow_l" then
            if shift and not hasSelection(st) then st.selectionStart = st.caret end
            setCaret(activeInput, st.caret - 1, shift)
        elseif key == "arrow_r" then
            if shift and not hasSelection(st) then st.selectionStart = st.caret end
            setCaret(activeInput, st.caret + 1, shift)
        elseif key == "home" then
            if shift and not hasSelection(st) then st.selectionStart = st.caret end
            setCaret(activeInput, 0, shift)
        elseif key == "end" then
            if shift and not hasSelection(st) then st.selectionStart = st.caret end
            setCaret(activeInput, len(value), shift)
        else
            return
        end
        cancelEvent()
    end
end)

addEventHandler("onClientPaste", root, function(text)
    if activeInput then insertInputText(activeInput, text) end
end)

addEventHandler("onClientCursorMove", root, function(_, _, cx)
    if not activeInput then return end
    local st = inputState(activeInput)
    if not st.mouseSelecting then return end
    for _, input in ipairs(inputs) do
        if input.id == activeInput then
            st.caret = caretFromInputX(input, cx)
            st.selectionStart = st.dragAnchor or st.caret
            st.selectionEnd = st.caret
            return
        end
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if button == "left" and state == "up" and activeInput then
        inputState(activeInput).mouseSelecting = false
    end
end)

addEvent("home:setGps", true)
addEventHandler("home:setGps", resourceRoot, function(house)
    if isElement(gpsBlip) then destroyElement(gpsBlip) end
    gpsBlip = createBlip(house.x, house.y, house.z, HomeConfig.gpsBlipIcon, 2, 79, 195, 247, 255, 0, 99999)
    gpsHouseId = house.id
end)

addEvent("home:clearGps", true)
addEventHandler("home:clearGps", resourceRoot, function()
    if isElement(gpsBlip) then destroyElement(gpsBlip) end
    gpsBlip, gpsHouseId = nil, nil
end)

addEvent("home:applySpawnCamera", true)
addEventHandler("home:applySpawnCamera", resourceRoot, function(camera)
    if type(camera) ~= "table" or not camera.x or not camera.y or not camera.z or not camera.lx or not camera.ly or not camera.lz then return end
    setCameraMatrix(camera.x, camera.y, camera.z, camera.lx, camera.ly, camera.lz)
    setTimer(function()
        if isElement(localPlayer) then setCameraTarget(localPlayer) end
    end, 120, 1)
end)
