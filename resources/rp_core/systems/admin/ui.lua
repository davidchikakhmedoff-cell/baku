AdminPanel = {
    visible = false,
    alpha = 0,
    targetAlpha = 0,
    level = 0,
    levelNames = {},
    players = {},
    selectedId = nil,
    allowedActions = {},
    adminTypeName = "",
    hitboxes = {},
    modal = nil,
    scroll = 0,
    lastRefresh = 0
}

local banUnits = { "minutes", "hours", "days", "weeks", "months", "permanent" }
local ADMIN_UI_NAME = "admin"

local function s(value) return DXUtils.s(value) end
local function color(name, alpha) return DXUtils.color(AuthConfig.colors[name], alpha or 255) end
local function crisp(value) return math.floor(value + 0.5) end
local adminTitleFont = dxCreateFont("CompactC.ttf", s(14), false, "cleartype")

local function findSelected()
    for _, player in ipairs(AdminPanel.players) do
        if player.id == AdminPanel.selectedId then return player end
    end
    return AdminPanel.players[1]
end

local function hasSelected()
    for _, player in ipairs(AdminPanel.players) do
        if player.id == AdminPanel.selectedId then return true end
    end
    return false
end

local function filteredPlayers()
    local result = {}
    local needle = AdminPanel.search:getText():lower()
    for _, player in ipairs(AdminPanel.players) do
        local name = tostring(player.name or "")
        local id = tostring(player.id or "")
        if needle == "" or name:lower():find(needle, 1, true) or id:find(needle, 1, true) then
            result[#result + 1] = player
        end
    end
    return result
end

local function drawButton(box, title, subtitle, alpha)
    local hovered = DXUtils.inBox(box.x, box.y, box.w, box.h)
    local x, y, w, h = crisp(box.x), crisp(box.y), crisp(box.w), crisp(box.h)
    local bg = hovered and 17 or 14
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, alpha))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(bg, bg, bg, alpha))
    dxDrawRectangle(x + s(3), y + 1, w - s(6), 1, tocolor(18, 18, 18, alpha))
    dxDrawRectangle(x + s(3), y + h - 2, w - s(6), 1, tocolor(5, 5, 5, alpha))

    if subtitle and subtitle ~= "" then
        local mid = y + math.floor(h / 2)
        local chatFont = ChatConfig and ChatConfig.layout.font or "default-bold"
        local chatScale = ChatConfig and ChatConfig.layout.fontScale or 1
        dxDrawText(title, x + s(12), y + s(3), x + w - s(12), mid, tocolor(255, 255, 255, alpha), 1.05, "default-bold", "left", "bottom")
        dxDrawText(subtitle, x + s(12), mid, x + w - s(12), y + h - s(4), color("primary", alpha), chatScale * 0.95, chatFont, "left", "top")
    else
        dxDrawText(title, x + s(12), y, x + w - s(12), y + h, tocolor(255, 255, 255, alpha), 1, "default-bold", "center", "center", true)
    end
end

local function drawSection(x, y, w, h, title, alpha)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230 * alpha / 255))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130 * alpha / 255))
    dxDrawText(title, x + s(16), y + s(8), x + w - s(16), y + s(36), tocolor(245, 245, 245, alpha), 1, "default-bold", "left", "center", true)
    dxDrawRectangle(x + s(16), y + s(42), w - s(32), 1, color("primary", 55 * alpha / 255))
end

function AdminPanel.open(level, players, levelNames, allowedActions, adminTypeName)
    if RPUIManager and not RPUIManager.acquire(ADMIN_UI_NAME, { cursor = true, inputMode = "no_binds_when_editing" }) then return end
    local wasVisible = AdminPanel.visible
    AdminPanel.level = tonumber(level) or 0
    AdminPanel.levelNames = levelNames or {}
    AdminPanel.allowedActions = allowedActions or {}
    AdminPanel.adminTypeName = adminTypeName or ""
    AdminPanel.players = players or {}
    AdminPanel.selectedId = AdminPanel.selectedId or (AdminPanel.players[1] and AdminPanel.players[1].id)
    AdminPanel.visible = true
    AdminPanel.targetAlpha = 255
    AdminPanel.search:blur()
    if not wasVisible then addEventHandler("onClientRender", root, AdminPanel.render) end
end

function AdminPanel.close()
    AdminPanel.visible = false
    AdminPanel.targetAlpha = 0
    AdminPanel.modal = nil
    if DXInput.active == AdminPanel.search then AdminPanel.search:blur() end
    if RPUIManager then RPUIManager.release(ADMIN_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
    removeEventHandler("onClientRender", root, AdminPanel.render)
end

function AdminPanel.updatePlayers(players)
    AdminPanel.players = players or {}
    if not hasSelected() then AdminPanel.selectedId = AdminPanel.players[1] and AdminPanel.players[1].id or nil end
end

local function drawPlayerSearch(x, y, w, h, alpha)
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    dxDrawRectangle(x, y, w, h, tocolor(8, 8, 8, alpha))

    local text = AdminPanel.search:getText()
    local shown = text ~= "" and text or AdminPanel.search.placeholder
    local textColor = text ~= "" and tocolor(190, 190, 190, alpha) or tocolor(105, 105, 105, alpha)
    local textX, textRight = x + s(4), x + w - s(4)
    local fontScale = ChatConfig and ChatConfig.layout.fontScale or 1
    local font = ChatConfig and ChatConfig.layout.font or "default-bold"
    AdminPanel.search.lastLayout = { textX = textX, textRight = textRight, scale = fontScale, font = font }
    dxDrawText(shown, textX, y, textRight, y + h, textColor, fontScale, font, "left", "center", true)

    if DXInput.active == AdminPanel.search and (getTickCount() % 1000) < 520 then
        local cursorX = math.min(textX + dxGetTextWidth(text, fontScale, font), textRight)
        dxDrawRectangle(crisp(cursorX), y + s(5), 1, h - s(10), tocolor(220, 220, 220, alpha))
    end
end

local function renderPlayerList(x, y, w, h, alpha)
    drawSection(x, y, w, h, "Игроки", alpha)
    local rows = filteredPlayers()
    local rowH = s(23)
    local listTop = y + s(103)
    local visible = math.floor((h - s(117)) / rowH)
    local maxScroll = math.max(0, #rows - visible)
    AdminPanel.scroll = math.max(0, math.min(AdminPanel.scroll, maxScroll))

    drawPlayerSearch(x + s(16), y + s(54), w - s(32), s(23), alpha)
    local tableFont = ChatConfig and ChatConfig.layout.font or "default-bold"
    local chatScale = 1
    local headY, headH = y + s(82), s(21)
    local headerColor = tocolor(195, 195, 195, alpha)
    dxDrawText("ID", x + s(20), headY, x + s(72), headY + headH, headerColor, chatScale * 0.86, tableFont, "left", "center")
    dxDrawText("Имя", x + s(82), headY, x + w - s(20), headY + headH, headerColor, chatScale * 0.86, tableFont, "left", "center")

    for i = 1, visible do
        local player = rows[AdminPanel.scroll + i]
        if not player then break end
        local ry = listTop + (i - 1) * rowH
        local selected = player.id == AdminPanel.selectedId
        if selected then
            dxDrawRectangle(x + s(16), ry, w - s(32), rowH, tocolor(47, 113, 151, alpha))
        end
        local rowScale = chatScale
        dxDrawText(tostring(player.id), x + s(20), ry, x + s(72), ry + rowH, tocolor(255,255,255,alpha), rowScale, tableFont, "left", "center")
        dxDrawText(player.name, x + s(82), ry, x + w - s(20), ry + rowH, tocolor(255,255,255,alpha), rowScale, tableFont, "left", "center", true)
        AdminPanel.hitboxes["player:" .. tostring(player.id)] = { x = x + s(16), y = ry, w = w - s(32), h = rowH, id = player.id }
    end
end

local function renderActions(x, y, w, h, alpha)
    drawSection(x, y, w, h, "Действия", alpha)
    local cols, gap, bh = 2, s(6), s(38)
    local bw = (w - s(32) - gap) / cols
    local startX, startY = x + s(16), y + s(56)

    local visibleActions = {}
    for _, action in ipairs(AdminActionDefs) do
        if AdminPanel.allowedActions[action.id] then
            visibleActions[#visibleActions + 1] = action
        end
    end

    for index, action in ipairs(visibleActions) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local box = { x = startX + col * (bw + gap), y = startY + row * (bh + gap), w = bw, h = bh, action = action.id }
        if box.y + box.h > y + h - s(14) then break end
        AdminPanel.hitboxes["action:" .. action.id] = box
        drawButton(box, action.title, action.label, alpha)
    end
end

local function renderDetails(player, x, y, w, h, alpha)
    drawSection(x, y, w, h, "Информация", alpha)
    local cx, cy, cw = x + s(16), y + s(54), w - s(32)
    dxDrawText(player and player.name or "Игрок не выбран", cx, cy, cx + cw, cy + s(34), tocolor(255,255,255,alpha), 1.15, "default-bold", "left", "center", true)
    if not player then return end

    local levelName = AdminPanel.levelNames[AdminPanel.level] or ("Уровень " .. tostring(AdminPanel.level))
    dxDrawText("Ваш доступ: " .. levelName, cx, cy + s(34), cx + cw, cy + s(58), color("primary", alpha), 0.92, "default-bold", "left", "center", true)

    local vehicleText = "-"
    if player.vehicleModel then
        vehicleText = tostring(player.vehicleModel)
        if player.vehicleId and tostring(player.vehicleId) ~= "" then
            vehicleText = vehicleText .. " (" .. tostring(player.vehicleId) .. ")"
        end
    end

    local info = {
        {"HP", tostring(player.health)},
        {"Броня", tostring(player.armor)},
        {"Уровень", tostring(player.level)},
        {"EXP", tostring(player.experience or 0)},
        {"Ping", tostring(player.ping)},
        {"ID", tostring(player.id)},
        {"Ник", tostring(player.name)},
        {"Скин", tostring(player.skin)},
        {"ID авто", vehicleText},
        {"Деньги", "$" .. tostring(player.money)},
        {"Мут", player.muted and "Да" or "Нет"},
        {"Фриз", player.frozen and "Да" or "Нет"}
    }

    local rowY, rowH = cy + s(74), s(34)
    local chatFont = ChatConfig and ChatConfig.layout.font or "default-bold"
    local chatScale = ChatConfig and ChatConfig.layout.fontScale or 1
    for i, item in ipairs(info) do
        local ry = rowY + (i - 1) * rowH
        if ry + rowH > y + h - s(14) then break end
        dxDrawText(item[1], cx, ry, cx + s(90), ry + rowH, color("muted", alpha), chatScale, chatFont, "left", "center", true)
        dxDrawText(item[2], cx + s(96), ry, cx + cw, ry + rowH, color("text", alpha), chatScale, chatFont, "right", "center", true)
    end
end

function AdminPanel.getModalLayout()
    local sw, sh = guiGetScreenSize()
    local modal = AdminPanel.modal
    local h = modal and modal.action == "ban" and s(330) or (modal and modal.action == "unban" and s(250) or (modal and modal.duration and s(250) or s(190)))
    local w = s(480)
    return (sw - w) / 2, (sh - h) / 2, w, h
end

local function unitLabel(unit)
    return RPBansConfig and RPBansConfig.unitLabels and RPBansConfig.unitLabels[unit] or tostring(unit)
end

function AdminPanel.nextBanUnit()
    if not AdminPanel.modal or AdminPanel.modal.action ~= "ban" then return end
    local current = AdminPanel.modal.unit or "days"
    local index = 3
    for i, unit in ipairs(banUnits) do
        if unit == current then index = i break end
    end
    AdminPanel.modal.unit = banUnits[index % #banUnits + 1]
end

local function renderModal(alpha)
    local modal = AdminPanel.modal
    if not modal then return end

    local sw, sh = guiGetScreenSize()
    local x, y, w, h = AdminPanel.getModalLayout()
    dxDrawRectangle(0, 0, sw, sh, tocolor(0, 0, 0, 120 * alpha / 255))
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230 * alpha / 255))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130 * alpha / 255))
    dxDrawText(modal.title, x + s(16), y + s(7), x + w - s(16), y + s(42), tocolor(245,245,245,alpha), 1, adminTitleFont or "default-bold", "left", "center", true)

    modal.input:draw(x + s(28), y + s(64), w - s(56), s(46), alpha, modal.action == "unban" and "ID" or "IN")
    if modal.action == "ban" then
        modal.durationInput:draw(x + s(28), y + s(120), s(190), s(46), alpha, "TM")
        AdminPanel.hitboxes.modalUnit = { x = x + s(228), y = y + s(120), w = w - s(256), h = s(46) }
        drawButton(AdminPanel.hitboxes.modalUnit, unitLabel(modal.unit), "Единица срока", alpha)
        dxDrawText("Для бессрочного бана число игнорируется.", x + s(28), y + s(174), x + w - s(28), y + s(198), color("muted", alpha), 0.88, "default", "left", "center", true)
    elseif modal.action == "unban" then
        modal.reasonInput:draw(x + s(28), y + s(120), w - s(56), s(46), alpha, "RS")
    elseif modal.duration then
        modal.durationInput:draw(x + s(28), y + s(120), w - s(56), s(46), alpha, "TM")
    end

    local by = y + h - s(58)
    AdminPanel.hitboxes.modalOk = { x = x + w - s(222), y = by, w = s(92), h = s(38) }
    AdminPanel.hitboxes.modalCancel = { x = x + w - s(120), y = by, w = s(92), h = s(38) }
    drawButton(AdminPanel.hitboxes.modalOk, "OK", "", alpha)
    drawButton(AdminPanel.hitboxes.modalCancel, "Отмена", "", alpha)
end

function AdminPanel.render()
    if not AdminPanel.visible then return end
    if getTickCount() - AdminPanel.lastRefresh > 1500 then
        AdminPanel.lastRefresh = getTickCount()
        triggerServerEvent("admin:refresh", localPlayer)
    end

    local sw, sh = guiGetScreenSize()
    local w, h = s(1080), s(650)
    local x, y = crisp((sw - w) / 2), crisp((sh - h) / 2)
    AdminPanel.hitboxes = {}

    local alpha = AdminPanel.targetAlpha
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230 * alpha / 255))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130 * alpha / 255))
    dxDrawText("АДМИН-ПАНЕЛЬ", x + s(28), y + s(10), x + w, y + s(58), tocolor(245,245,245,alpha), 1, adminTitleFont or "default-bold", "left", "center")
    dxDrawText("Уровень доступа: " .. tostring(AdminPanel.level), x, y + s(20), x + w - s(58), y + s(54), color("muted", alpha), 0.9, "default", "right", "center")

    local gap = s(18)
    local top = y + s(70)
    local contentH = h - s(98)
    local listW, actionW = s(300), s(360)
    local detailsW = w - s(56) - listW - actionW - gap * 2
    local listX = x + s(28)
    local actionX = listX + listW + gap
    local detailsX = actionX + actionW + gap

    renderPlayerList(listX, top, listW, contentH, alpha)
    renderActions(actionX, top, actionW, contentH, alpha)
    renderDetails(findSelected(), detailsX, top, detailsW, contentH, alpha)

    AdminPanel.hitboxes.close = { x = x + w - s(46), y = y + s(18), w = s(24), h = s(24) }
    dxDrawText("X", AdminPanel.hitboxes.close.x, AdminPanel.hitboxes.close.y, AdminPanel.hitboxes.close.x + AdminPanel.hitboxes.close.w, AdminPanel.hitboxes.close.y + AdminPanel.hitboxes.close.h, color("muted", alpha), 1, "default-bold", "center", "center")

    renderModal(alpha)
end

function AdminPanel.openModal(action)
    local def = AdminGetActionDef(action)
    if not def then return end

    local modal = {
        action = action,
        title = def.label,
        input = DXInput:new(def.placeholder or "Значение", false, action == "ban" and 96 or 64)
    }
    modal.input:setText(def.default or "")

    if def.mode == "vehicleValue" then
        local selected = findSelected()
        local currentHP = selected and selected.vehicleHealth
        local maxHP = selected and selected.vehicleMaxHealth or (AdminConfig and AdminConfig.vehicleMaxHealth) or 1000
        if currentHP then
            modal.input = DXInput:new(string.format("HP: %d - %d", currentHP, maxHP), false, 8)
            modal.input:setText(tostring(currentHP))
        end
    end

    if def.mode == "punish" then
        modal.duration = true
        modal.durationInput = DXInput:new("Длительность в секундах", false, 16)
        modal.durationInput:setText(def.duration or "3600")
    elseif def.mode == "ban" then
        modal.duration = true
        modal.unit = def.unit or "days"
        modal.durationInput = DXInput:new("Срок", false, 8)
        modal.durationInput:setText(def.duration or "1")
    elseif def.mode == "unban" then
        modal.reasonInput = DXInput:new("Причина разбана", false, 96)
    end

    AdminPanel.modal = modal
    modal.input:activate()
end

function AdminPanel.submitModal()
    local modal = AdminPanel.modal
    if not modal then return end
    local def = AdminGetActionDef(modal.action)
    local data = {}

    if def.mode == "value" or def.mode == "vehicleValue" then
        data.value = tonumber(modal.input:getText()) or 0
    elseif def.mode == "destination" then
        data.destinationId = tonumber(modal.input:getText()) or 0
    elseif def.mode == "reason" then
        data.reason = modal.input:getText()
    elseif def.mode == "punish" then
        data.reason = modal.input:getText()
        data.duration = tonumber(modal.durationInput:getText()) or 0
    elseif def.mode == "ban" then
        data.reason = modal.input:getText()
        data.duration = tonumber(modal.durationInput:getText()) or 1
        data.unit = modal.unit or "days"
    elseif def.mode == "unban" then
        data.identity = modal.input:getText()
        data.reason = modal.reasonInput:getText()
    end

    local targetId = modal.action == "unban" and nil or AdminPanel.selectedId
    triggerServerEvent("admin:action", localPlayer, modal.action, targetId, data)
    AdminPanel.modal = nil
    AdminPanel.search:blur()
end

function AdminPanel.runAction(action)
    if not AdminPanel.allowedActions[action] then return end
    local selected = findSelected()
    local def = AdminGetActionDef(action)
    if not def then return end
    if action ~= "unban" then
        if not selected then return end
        AdminPanel.selectedId = selected.id
    end
    if def.mode == "instant" then
        triggerServerEvent("admin:action", localPlayer, action, selected.id, {})
    else
        AdminPanel.openModal(action)
    end
end
