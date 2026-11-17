AdminReportsUI = {
    visible = false,
    reports = {},
    selectedId = nil,
    answerInput = nil,
    hitboxes = {},
    scroll = 0
}

local REPORTS_UI_NAME = "adminReports"

local function s(v) return DXUtils.s(v) end
local function color(name, alpha) return DXUtils.color(AuthConfig.colors[name], alpha or 255) end
local function crisp(v) return math.floor(v + 0.5) end
local function chatFont() return ChatConfig and ChatConfig.layout.font or "default-bold" end
local function chatScale(multiplier)
    return (ChatConfig and ChatConfig.layout.fontScale or 1) * (multiplier or 1)
end

local function inBox(x, y, box)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

local function formatTime(stamp)
    local rt = getRealTime(tonumber(stamp) or 0)
    return string.format("%02d:%02d", rt.hour, rt.minute)
end

local function findSelected()
    for _, report in ipairs(AdminReportsUI.reports) do
        if report.id == AdminReportsUI.selectedId then return report end
    end
    if AdminReportsUI.selectedId == nil then return AdminReportsUI.reports[1] end
    return nil
end

local function drawButton(box, title, alpha)
    local hover = DXUtils.inBox(box.x, box.y, box.w, box.h)
    local x, y, w, h = crisp(box.x), crisp(box.y), crisp(box.w), crisp(box.h)
    local bg = hover and 17 or 14
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, alpha))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(bg, bg, bg, alpha))
    dxDrawRectangle(x + s(3), y + 1, w - s(6), 1, tocolor(18, 18, 18, alpha))
    dxDrawRectangle(x + s(3), y + h - 2, w - s(6), 1, tocolor(5, 5, 5, alpha))
    dxDrawText(title, x + s(12), y, x + w - s(12), y + h, tocolor(255, 255, 255, alpha), chatScale(), chatFont(), "center", "center", true)
end

local function drawAnswerInput(input, x, y, w, h, alpha)
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    dxDrawRectangle(x, y, w, h, tocolor(8, 8, 8, alpha))

    local text = input:getText()
    local shown = text ~= "" and text or input.placeholder
    local textColor = text ~= "" and tocolor(205, 205, 205, alpha) or tocolor(95, 95, 95, alpha)
    local textX, textRight = x + s(8), x + w - s(8)
    local font, scale = chatFont(), chatScale()
    input.lastLayout = { textX = textX, textRight = textRight, scale = scale, font = font }
    dxDrawText(shown, textX, y, textRight, y + h, textColor, scale, font, "left", "center", true)

    if DXInput.active == input and (getTickCount() % 1000) < 520 then
        local cursorX = math.min(textX + dxGetTextWidth(text, scale, font), textRight)
        dxDrawRectangle(crisp(cursorX), y + s(7), 1, h - s(14), tocolor(220, 220, 220, alpha))
    end
end

function AdminReportsUI.open(reports)
    if RPUIManager and not RPUIManager.acquire(REPORTS_UI_NAME, { cursor = true, inputMode = "no_binds_when_editing" }) then return end
    local wasVisible = AdminReportsUI.visible
    AdminReportsUI.visible = true
    AdminReportsUI.reports = reports or {}
    AdminReportsUI.selectedId = AdminReportsUI.selectedId or (AdminReportsUI.reports[1] and AdminReportsUI.reports[1].id)
    if not findSelected() then
        AdminReportsUI.selectedId = AdminReportsUI.reports[1] and AdminReportsUI.reports[1].id
    end
    AdminReportsUI.answerInput = AdminReportsUI.answerInput or DXInput:new("Ответ игроку", false, 160)
    AdminReportsUI.answerInput:blur()
    if not wasVisible then addEventHandler("onClientRender", root, AdminReportsUI.render) end
end

function AdminReportsUI.close()
    AdminReportsUI.visible = false
    if AdminReportsUI.answerInput and DXInput.active == AdminReportsUI.answerInput then AdminReportsUI.answerInput:blur() end
    if RPUIManager then RPUIManager.release(REPORTS_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
    removeEventHandler("onClientRender", root, AdminReportsUI.render)
end

function AdminReportsUI.render()
    if not AdminReportsUI.visible then return end
    local sw, sh = guiGetScreenSize()
    local w, h = s(980), s(620)
    local x, y = crisp((sw - w) / 2), crisp((sh - h) / 2)
    local alpha = 255
    AdminReportsUI.hitboxes = {}

    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawText("ОБРАЩЕНИЯ ИГРОКОВ", x + s(28), y + s(10), x + w - s(60), y + s(58), tocolor(245, 245, 245, alpha), chatScale(), chatFont(), "left", "center")
    AdminReportsUI.hitboxes.close = { x = x + w - s(46), y = y + s(18), w = s(24), h = s(24) }
    dxDrawText("X", AdminReportsUI.hitboxes.close.x, AdminReportsUI.hitboxes.close.y, AdminReportsUI.hitboxes.close.x + AdminReportsUI.hitboxes.close.w, AdminReportsUI.hitboxes.close.y + AdminReportsUI.hitboxes.close.h, color("muted", alpha), chatScale(), chatFont(), "center", "center")

    local function section(sx, sy, swidth, sheight, title)
        dxDrawRectangle(sx, sy, swidth, sheight, tocolor(0, 0, 0, 230))
        dxDrawRectangle(sx + 1, sy + 1, swidth - 2, sheight - 2, tocolor(0, 0, 0, 130))
        dxDrawText(title, sx + s(16), sy + s(7), sx + swidth - s(16), sy + s(35), tocolor(245, 245, 245, alpha), chatScale(), chatFont(), "left", "center", true)
        dxDrawRectangle(sx + s(16), sy + s(41), swidth - s(32), 1, color("primary", 55))
    end

    local listX, listY, listW, listH = x + s(28), y + s(70), s(360), h - s(98)
    section(listX, listY, listW, listH, "Список обращений")

    local tableX = listX + s(16)
    local tableW = listW - s(32)
    local headerY = listY + s(48)
    local rowH = s(27)
    local rowsTop = headerY + s(24)
    local visibleRows = math.max(1, math.floor((listY + listH - s(12) - rowsTop) / rowH))
    AdminReportsUI.scroll = math.max(0, math.min(AdminReportsUI.scroll, math.max(0, #AdminReportsUI.reports - visibleRows)))

    dxDrawText("ID", tableX + s(7), headerY, tableX + s(48), headerY + s(22), color("muted", alpha), chatScale(0.82), chatFont(), "left", "center")
    dxDrawText("Имя", tableX + s(55), headerY, tableX + s(224), headerY + s(22), color("muted", alpha), chatScale(0.82), chatFont(), "left", "center", true)
    dxDrawText("Статус", tableX + s(230), headerY, tableX + tableW - s(7), headerY + s(22), color("muted", alpha), chatScale(0.82), chatFont(), "left", "center", true)

    for i = 1, visibleRows do
        local report = AdminReportsUI.reports[AdminReportsUI.scroll + i]
        if not report then break end
        local ry = rowsTop + (i - 1) * rowH
        local selected = report.id == AdminReportsUI.selectedId
        if selected then
            dxDrawRectangle(tableX, ry, tableW, rowH, tocolor(47, 113, 151, alpha))
        end
        local scale = 1
        local textColor = tocolor(255, 255, 255, alpha)
        dxDrawText(tostring(report.id), tableX + s(7), ry, tableX + s(48), ry + rowH, textColor, scale, chatFont(), "left", "center")
        dxDrawText(tostring(report.playerName), tableX + s(55), ry, tableX + s(224), ry + rowH, textColor, scale, chatFont(), "left", "center", true)
        dxDrawText(tostring(report.status), tableX + s(230), ry, tableX + tableW - s(7), ry + rowH, textColor, scale, chatFont(), "left", "center", true)
        AdminReportsUI.hitboxes["report:" .. tostring(report.id)] = { x = tableX, y = ry, w = tableW, h = rowH, id = report.id }
    end

    local detailX, detailY, detailW, detailH = x + s(408), y + s(70), w - s(436), h - s(98)
    section(detailX, detailY, detailW, detailH, "Информация")
    local cx, cy, cw = detailX + s(16), detailY + s(54), detailW - s(32)
    local report = findSelected()
    if not report then
        dxDrawText("Активных обращений нет.", cx, cy, cx + cw, cy + s(40), color("muted", alpha), chatScale(), chatFont(), "left", "center")
        return
    end

    dxDrawText("Заявка #" .. tostring(report.id), cx, cy, cx + cw, cy + s(28), tocolor(255, 255, 255, alpha), chatScale(), chatFont(), "left", "center")
    dxDrawText("Игрок: " .. tostring(report.playerName) .. " (" .. tostring(report.playerId) .. ")", cx, cy + s(30), cx + cw, cy + s(54), color("primary", alpha), chatScale(0.94), chatFont(), "left", "center", true)
    local reportInfo = "Статус: " .. tostring(report.status) .. "\n" ..
        "Взял: " .. tostring(report.takenBy ~= "" and report.takenBy or "-") .. "\n" ..
        "Онлайн: " .. (report.online and "да" or "нет") .. "\n" ..
        "Время: " .. formatTime(report.createdAt)
    dxDrawText(reportInfo, cx, cy + s(62), cx + cw, cy + s(132), color("text", alpha), chatScale(0.94), chatFont(), "left", "top", true, true)
    dxDrawText(tostring(report.text), cx, cy + s(138), cx + cw, cy + s(218), color("text", alpha), chatScale(0.94), chatFont(), "left", "top", true, true)

    AdminReportsUI.hitboxes.answerInput = { x = cx, y = cy + s(225), w = cw, h = s(42) }
    drawAnswerInput(AdminReportsUI.answerInput, cx, cy + s(225), cw, s(42), alpha)

    local labels = {
        take = "Взять обращение",
        answer = "Ответить",
        close = "Закрыть",
        teleport = "Телепорт к игроку",
        spectate = "Наблюдать"
    }
    local order = {"take", "answer", "close", "teleport", "spectate"}
    local gap, bh = s(8), s(38)
    local bw = (cw - gap) / 2
    local by = cy + s(284)
    for index, id in ipairs(order) do
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local box = { x = cx + col * (bw + gap), y = by + row * (bh + gap), w = bw, h = bh, action = id }
        AdminReportsUI.hitboxes["action:" .. id] = box
        drawButton(box, labels[id], alpha)
    end
end

addEvent("adminReports:open", true)
addEventHandler("adminReports:open", resourceRoot, function(reports)
    AdminReportsUI.open(reports)
end)

addEvent("adminReports:sync", true)
addEventHandler("adminReports:sync", resourceRoot, function(reports)
    AdminReportsUI.reports = reports or {}
    if AdminReportsUI.visible and not findSelected() then
        AdminReportsUI.selectedId = AdminReportsUI.reports[1] and AdminReportsUI.reports[1].id
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if press and string.lower(button) == string.lower(AdminConfig.reportsKey or "F3") then
        cancelEvent()
        if AdminReportsUI.visible then AdminReportsUI.close() else triggerServerEvent("adminReports:request", localPlayer) end
        return
    end
    if not AdminReportsUI.visible then return end
    if press and button == "escape" then cancelEvent(); AdminReportsUI.close(); return end
    if press and button == "mouse_wheel_up" then
        AdminReportsUI.scroll = math.max(0, AdminReportsUI.scroll - 1)
        cancelEvent()
        return
    end
    if press and button == "mouse_wheel_down" then
        AdminReportsUI.scroll = AdminReportsUI.scroll + 1
        cancelEvent()
        return
    end
    if AdminReportsUI.answerInput and DXInput.active == AdminReportsUI.answerInput then
        local handled = AdminReportsUI.answerInput:key(button, press)
        if handled then cancelEvent() end
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if AdminReportsUI.visible and AdminReportsUI.answerInput and DXInput.active == AdminReportsUI.answerInput then
        AdminReportsUI.answerInput:char(char)
    end
end)

addEventHandler("onClientPaste", root, function(text)
    if AdminReportsUI.visible and AdminReportsUI.answerInput and DXInput.active == AdminReportsUI.answerInput then
        AdminReportsUI.answerInput:paste(text)
    end
end)

addEventHandler("onClientClick", root, function(button, state, x, y)
    if not AdminReportsUI.visible or button ~= "left" or state ~= "down" then return end
    if inBox(x, y, AdminReportsUI.hitboxes.close) then AdminReportsUI.close(); return end
    for key, box in pairs(AdminReportsUI.hitboxes) do
        if key:find("^report:") and inBox(x, y, box) then AdminReportsUI.selectedId = box.id; return end
    end
    local report = findSelected()
    if not report then return end
    if AdminReportsUI.hitboxes.answerInput and AdminReportsUI.answerInput:click(x, y, AdminReportsUI.hitboxes.answerInput.x, AdminReportsUI.hitboxes.answerInput.y, AdminReportsUI.hitboxes.answerInput.w, AdminReportsUI.hitboxes.answerInput.h) then
        return
    end
    for key, box in pairs(AdminReportsUI.hitboxes) do
        if key:find("^action:") and inBox(x, y, box) then
            triggerServerEvent("adminReports:action", localPlayer, box.action, report.id, AdminReportsUI.answerInput:getText())
            if box.action == "answer" then AdminReportsUI.answerInput:setText("") end
            return
        end
    end
end)
