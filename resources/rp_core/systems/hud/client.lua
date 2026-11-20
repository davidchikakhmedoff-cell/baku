local hud = {
    visible = false,
    scoreboardSuppressed = false,
    notificationSuppressed = false,
    alpha = 0,
    data = {
        player = { name = "Unknown", id = 0, accountId = 0 },
        progression = { level = 1, experience = 0, requiredExperience = 4 },
        economy = { money = 0 },
        vitals = { health = 100, armor = 0 },
        weapon = { id = 0, clip = 0, total = 0, reserve = 0 },
        faction = false
    },
    smooth = { health = 100, armor = 0, money = 0, experience = 0 },
    time = {
        visible = false,
        serverStamp = 0,
        tick = 0,
        hideTick = 0,
        alpha = 0
    },
    initialized = false
}

local screenW, screenH = guiGetScreenSize()
local scale = math.min(screenW / 1920, screenH / 1080)
local renderAttached = false

local function cfg()
    return HUDConfig
end

local function s(value)
    return math.floor(value * scale + 0.5)
end

local function rgba(rgb, alpha)
    return tocolor(rgb[1], rgb[2], rgb[3], alpha or 255)
end

local function color(name, alpha)
    return rgba(cfg().colors[name], alpha)
end

local function lerp(from, to, speed)
    return from + (to - from) * math.max(0, math.min(1, speed))
end

local function animateNumber(current, target, speed)
    current = tonumber(current) or 0
    target = tonumber(target) or 0
    local diff = target - current
    if math.abs(diff) < 1 then return target end
    return current + diff * math.max(0, math.min(1, speed or 0.22))
end

local function roundedRect(x, y, w, h, radius, drawColor)
    if DXUtils and DXUtils.roundedRect then
        DXUtils.roundedRect(x, y, w, h, radius, drawColor)
        return
    end

    dxDrawRectangle(x + radius, y, w - radius * 2, h, drawColor)
    dxDrawRectangle(x, y + radius, radius, h - radius * 2, drawColor)
    dxDrawRectangle(x + w - radius, y + radius, radius, h - radius * 2, drawColor)
    dxDrawCircle(x + radius, y + radius, radius, 180, 270, drawColor, drawColor, 12)
    dxDrawCircle(x + w - radius, y + radius, radius, 270, 360, drawColor, drawColor, 12)
    dxDrawCircle(x + radius, y + h - radius, radius, 90, 180, drawColor, drawColor, 12)
    dxDrawCircle(x + w - radius, y + h - radius, radius, 0, 90, drawColor, drawColor, 12)
end

local function shadow(x, y, w, h, radius, alpha)
    if DXUtils and DXUtils.shadow then
        DXUtils.shadow(x, y, w, h, radius, alpha)
        return
    end

    for i = 4, 1, -1 do
        roundedRect(x - i * 2, y - i * 2, w + i * 4, h + i * 4, radius + i, tocolor(0, 0, 0, alpha / i))
    end
end

local function outlinedText(text, x, y, right, bottom, textColor, scaleValue, font, alignX, alignY, alpha, clip, colorCoded)
    local outline = math.max(1, s(1))
    local outlineColor = tocolor(0, 0, 0, math.min(235, alpha or 255))

    dxDrawText(text, x - outline, y, right - outline, bottom, outlineColor, scaleValue, font, alignX, alignY, clip, false, false, false)
    dxDrawText(text, x + outline, y, right + outline, bottom, outlineColor, scaleValue, font, alignX, alignY, clip, false, false, false)
    dxDrawText(text, x, y - outline, right, bottom - outline, outlineColor, scaleValue, font, alignX, alignY, clip, false, false, false)
    dxDrawText(text, x, y + outline, right, bottom + outline, outlineColor, scaleValue, font, alignX, alignY, clip, false, false, false)
    dxDrawText(text, x, y, right, bottom, textColor, scaleValue, font, alignX, alignY, clip, false, false, colorCoded or false, true)
end

local function fitTextScale(text, targetWidth, font, minScale, maxScale)
    local baseWidth = dxGetTextWidth(text, 1, font) or 0
    if baseWidth <= 0 then return maxScale end

    local scaleValue = targetWidth / baseWidth
    return math.max(minScale, math.min(maxScale, scaleValue))
end

local function setDefaultHudVisible(visible)
    if type(setPlayerHudComponentVisible) ~= "function" then return end

    setPlayerHudComponentVisible("all", visible)
    setPlayerHudComponentVisible("crosshair", true)
    setPlayerHudComponentVisible("radar", true)
    if not visible then
        setPlayerHudComponentVisible("health", false)
        setPlayerHudComponentVisible("armour", false)
        setPlayerHudComponentVisible("money", false)
        setPlayerHudComponentVisible("weapon", false)
        setPlayerHudComponentVisible("ammo", false)
    end
end

local function formatMoney(value)
    local amount = math.max(0, math.floor(tonumber(value) or 0))
    local left, num, right = tostring(amount):match("^([^%d]*%d)(%d*)(.-)$")
    return "$ " .. (left and left .. num:reverse():gsub("(%d%d%d)", "%1 "):reverse() .. right or tostring(amount))
end

local months = {
    "января", "февраля", "марта", "апреля", "мая", "июня",
    "июля", "августа", "сентября", "октября", "ноября", "декабря"
}

local function drawTimeBlock(alpha)
    local nowTick = getTickCount()
    if not hud.time.visible and (hud.time.alpha or 0) <= 0 then return end
    if hud.time.visible and nowTick >= (hud.time.hideTick or 0) then
        hud.time.visible = false
    end
    local target = hud.time.visible and 255 or 0
    hud.time.alpha = lerp(hud.time.alpha or 0, target, hud.time.visible and 0.32 or 0.18)
    if not hud.time.visible and hud.time.alpha < 1 then
        hud.time.alpha = 0
        return
    end
    local localAlpha = math.min(alpha, hud.time.alpha)
    local elapsed = math.floor((getTickCount() - (hud.time.tick or 0)) / 1000)
    local rt = getRealTime((tonumber(hud.time.serverStamp) or 0) + elapsed)
    local dateText = string.format("%02d %s %04d", rt.monthday, months[(rt.month or 0) + 1] or "", (rt.year or 0) + 1900)
    local timeText = string.format("%02d:%02d:%02d", rt.hour, rt.minute, rt.second)
    local w, h = s(230), s(78)
    local x = math.floor((screenW - w) / 2)
    local y = screenH - h - s(42)
    shadow(x, y, w, h, s(8), 44 * localAlpha / 255)
    roundedRect(x, y, w, h, s(8), color("window", 210 * localAlpha / 255))
    dxDrawText(dateText, x + s(16), y + s(12), x + w - s(16), y + s(35), color("text", localAlpha), 1, cfg().fonts.bold, "center", "center", true)
    dxDrawText(timeText, x + s(16), y + s(36), x + w - s(16), y + s(62), color("text", localAlpha), 1.18, cfg().fonts.bold, "center", "center", true)
    dxDrawRectangle(x + s(18), y + h - s(9), w - s(36), s(2), color("primary", 165 * localAlpha / 255))
end

local function currentLocalWeaponData()
    local slot = getPedWeaponSlot(localPlayer) or 0
    local weapon = getPedWeapon(localPlayer, slot) or 0
    if slot == 0 or weapon <= 0 then
        return { id = 0, slot = slot, clip = 0, total = 0, reserve = 0 }
    end

    local clip = getPedAmmoInClip(localPlayer, slot) or getPedAmmoInClip(localPlayer) or 0
    local total = getPedTotalAmmo(localPlayer, slot) or getPedTotalAmmo(localPlayer) or 0

    return {
        id = weapon,
        slot = slot,
        clip = math.max(0, clip),
        total = math.max(0, total),
        reserve = math.max(0, total - clip)
    }
end

local function weaponName(id)
    id = tonumber(id) or 0
    if id == 0 then return "Без оружия" end
    return cfg().weaponNames[id] or "Weapon " .. tostring(id)
end

local function refreshLocalWeaponNow()
    hud.data.weapon = currentLocalWeaponData()
end

local function drawMiniBar(x, y, w, h, value, maxValue, fillName, alpha)
    local progress = math.max(0, math.min(1, (tonumber(value) or 0) / math.max(1, tonumber(maxValue) or 100)))
    local outline = math.max(1, s(1))
    roundedRect(x - outline, y - outline, w + outline * 2, h + outline * 2, math.floor((h + outline * 2) / 2), tocolor(0, 0, 0, 185 * alpha / 255))
    roundedRect(x, y, w, h, math.floor(h / 2), color("track", 58 * alpha / 255))
    if progress > 0 then
        roundedRect(x, y, math.max(h, math.floor(w * progress + 0.5)), h, math.floor(h / 2), color(fillName, 235 * alpha / 255))
    end
end

local wantedStar = svgCreate(32, 32, [[<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><polygon points="16,1 20.5,10.8 31,12 23,19.6 25,30 16,24.7 7,30 9,19.6 1,12 11.5,10.8" fill="#ffffff" stroke="#181818" stroke-width="1.2"/></svg>]])
local function drawWantedStars(right, y, alpha)
    local level = math.max(0, math.min(6, tonumber(getPlayerWantedLevel(localPlayer)) or 0))
    if level == 0 or not isElement(wantedStar) then return end
    local size, gap = s(20), s(5)
    for index = 1, 6 do
        local active = index <= level
        local tint = active and tocolor(255, 200, 70, alpha) or tocolor(80, 84, 90, alpha * 0.65)
        dxDrawImage(right - (7 - index) * (size + gap) + gap, y, size, size, wantedStar, 0, 0, 0, tint)
    end
end

local function drawHud()
    local suppressed = hud.scoreboardSuppressed or hud.notificationSuppressed
    local targetAlpha = hud.visible and not suppressed and 255 or 0
    hud.alpha = lerp(hud.alpha, targetAlpha, cfg().animation.fadeSpeed)
    if hud.alpha < 1 then
        if not suppressed then
            drawTimeBlock(255)
        end
        return
    end

    refreshLocalWeaponNow()

    local alpha = hud.alpha
    local layout = cfg().layout
    local data = hud.data
    local weapon = data.weapon or { id = 0, clip = 0, reserve = 0 }
    local noWeapon = (tonumber(weapon.id) or 0) == 0
    local rawArmor = tonumber(data.vitals.armor) or 0
    local w = s(272)
    local h = s(116)
    local x = math.floor(screenW - w - s(layout.marginX) + 0.5)
    local y = math.floor(s(layout.marginY) + 0.5)
    local pad = s(11)

    hud.smooth.health = lerp(hud.smooth.health, tonumber(data.vitals.health) or 0, cfg().animation.barSpeed)
    hud.smooth.armor = lerp(hud.smooth.armor, rawArmor, cfg().animation.barSpeed)
    hud.smooth.money = animateNumber(hud.smooth.money, tonumber(data.economy.money) or 0, 0.24)

    local barX, barW = x + pad, w - pad * 2
    local moneyY = y + s(4)
    local moneyText = formatMoney(math.floor(hud.smooth.money + 0.5))
    local moneyScale = fitTextScale(moneyText, barW, cfg().fonts.bold, 1.45, 3.2)
    outlinedText(moneyText, barX, moneyY, barX + barW, moneyY + s(48), color("text", alpha), moneyScale, cfg().fonts.bold, "right", "center", alpha, true)

    local barY = y + s(59)
    drawMiniBar(barX, barY, barW, s(4), hud.smooth.health, 100, "hp", alpha)
    drawMiniBar(barX, barY + s(8), barW, s(4), hud.smooth.armor, 100, "armor", alpha)

    local weaponY = barY + s(17)
    outlinedText(weaponName(weapon.id), barX, weaponY, barX + barW, weaponY + s(20), color("text", alpha), 0.98, cfg().fonts.bold, "left", "center", alpha, true)
    if not noWeapon then
        outlinedText(tostring(weapon.clip or 0) .. " / " .. tostring(weapon.reserve or 0), barX, weaponY + s(18), barX + barW, weaponY + s(34), color("muted", alpha), 0.86, cfg().fonts.bold, "left", "center", alpha, true)
    end

    drawWantedStars(barX + barW, weaponY + s(42), alpha)
    drawTimeBlock(alpha)
end

local function applyFlatUpdate(update)
    if type(update) ~= "table" then return end

    if update.name ~= nil then hud.data.player.name = tostring(update.name) end
    if update.id ~= nil then hud.data.player.id = tonumber(update.id) or 0 end
    if update.accountId ~= nil then hud.data.player.accountId = tonumber(update.accountId) or 0 end
    if update.money ~= nil then hud.data.economy.money = tonumber(update.money) or 0 end
    if update.health ~= nil then hud.data.vitals.health = tonumber(update.health) or 0 end
    if update.armor ~= nil then hud.data.vitals.armor = tonumber(update.armor) or 0 end
    if update.faction ~= nil then hud.data.faction = update.faction end

    refreshLocalWeaponNow()
end

local function setHudData(data)
    if type(data) ~= "table" then return end

    hud.data.player = data.player or hud.data.player
    hud.data.economy = data.economy or hud.data.economy
    hud.data.vitals = data.vitals or hud.data.vitals
    hud.data.faction = data.faction or false
    refreshLocalWeaponNow()

    hud.smooth.health = tonumber(hud.data.vitals.health) or hud.smooth.health
    hud.smooth.armor = tonumber(hud.data.vitals.armor) or hud.smooth.armor
    hud.smooth.money = tonumber(hud.data.economy.money) or hud.smooth.money
    hud.initialized = true
end

local function attachRender()
    if renderAttached then return end
    addEventHandler("onClientRender", root, drawHud)
    renderAttached = true
end

local function showHud(data)
    setHudData(data)
    hud.visible = true
    setDefaultHudVisible(false)
    if hud.scoreboardSuppressed then
        setPlayerHudComponentVisible("radar", false)
    end
    if type(data) ~= "table" then
        triggerServerEvent(cfg().events.request, localPlayer)
    end
end

local function hideHud()
    hud.visible = false
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    screenW, screenH = guiGetScreenSize()
    scale = math.min(screenW / 1920, screenH / 1080)
    attachRender()
    setDefaultHudVisible(false)
    triggerServerEvent(cfg().events.request, localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(wantedStar) then destroyElement(wantedStar) end
    setDefaultHudVisible(true)
end)

addEvent(cfg().events.show, true)
addEventHandler(cfg().events.show, resourceRoot, function(data)
    showHud(data)
end)

addEvent(cfg().events.hide, true)
addEventHandler(cfg().events.hide, resourceRoot, function()
    hideHud()
end)

addEvent(cfg().events.update, true)
addEventHandler(cfg().events.update, resourceRoot, function(update)
    applyFlatUpdate(update)
end)

addEvent("rp:time:toggle", true)
addEventHandler("rp:time:toggle", resourceRoot, function(serverStamp)
    hud.time.visible = true
    hud.time.serverStamp = tonumber(serverStamp) or 0
    hud.time.tick = getTickCount()
    hud.time.hideTick = hud.time.tick + 5000
    if not renderAttached then attachRender() end
end)

addEvent("HUD:show", true)
addEventHandler("HUD:show", root, function(data)
    showHud(data)
end)

addEvent("HUD:hide", true)
addEventHandler("HUD:hide", root, function()
    hideHud()
end)

addEvent("rp:hud:setScoreboardSuppressed", false)
addEventHandler("rp:hud:setScoreboardSuppressed", root, function(suppressed)
    hud.scoreboardSuppressed = suppressed == true
    if hud.scoreboardSuppressed then
        hud.alpha = 0
    end
end)

addEvent("rp:hud:setNotificationSuppressed", false)
addEventHandler("rp:hud:setNotificationSuppressed", root, function(suppressed)
    hud.notificationSuppressed = suppressed == true
    if hud.notificationSuppressed then
        hud.alpha = 0
    end
end)

addEvent("auth:loggedOut", true)
addEventHandler("auth:loggedOut", resourceRoot, function()
    hideHud()
end)

local function updateLocalVitals()
    local accountId = tonumber(getElementData(localPlayer, "auth:playerId"))
    if hud.initialized and accountId and tonumber(hud.data.player.accountId) ~= accountId then return end
    applyFlatUpdate({
        health = math.max(0, math.min(100, getElementHealth(localPlayer) or 0)),
        armor = math.max(0, math.min(100, getPedArmor(localPlayer) or 0))
    })
end

-- Local-only notification from resources that explicitly synchronize native HP.
addEvent("rp:hud:refreshLocalVitals", false)
addEventHandler("rp:hud:refreshLocalVitals", root, function()
    if source == localPlayer then updateLocalVitals() end
end)

local function updateLocalWeapon()
    refreshLocalWeaponNow()
end

local function updateLocalMoney()
    applyFlatUpdate({ money = getPlayerMoney(localPlayer) or 0 })
end

local function requestFastSync()
    if source ~= localPlayer then return end
    updateLocalVitals()
    updateLocalWeapon()
    updateLocalMoney()
end

addEventHandler("onClientPlayerDamage", root, requestFastSync)
addEventHandler("onClientPlayerWeaponSwitch", root, requestFastSync)
addEventHandler("onClientPlayerWeaponFire", root, requestFastSync)
addEventHandler("onClientPlayerWasted", root, requestFastSync)
addEventHandler("onClientPlayerSpawn", root, requestFastSync)
addEventHandler("onClientPlayerMoneyChange", root, requestFastSync)
