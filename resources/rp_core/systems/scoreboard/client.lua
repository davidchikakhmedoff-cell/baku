local board = {
    visible = false,
    players = {},
    lastRefresh = 0,
    scroll = 0,
    online = 0,
    radarWasVisible = true,
    searchBounds = nil,
    brandFont = nil,
    headerFont = nil
}
local sw, sh = guiGetScreenSize()
local visibleRows = 17
local SCOREBOARD_UI_NAME = "scoreboard"
local SCOREBOARD_SCALE = 1.05

local function s(value) return DXUtils.s(value * SCOREBOARD_SCALE) end
local function crisp(value) return math.floor(value + 0.5) end

local function addActor(list, element)
    local isPlayer = getElementType(element) == "player"
    local id = tostring(getElementData(element, "rp:id") or "?")
    local name = getElementData(element, "rp:name") or (isPlayer and getPlayerName(element) or "Unknown")

    list[#list + 1] = {
        element = element,
        id = id,
        name = name,
        level = getElementData(element, "rp:level") or 1,
        ping = isPlayer and getPlayerPing(element) or "BOT",
        factionColor = getElementData(element, "rp:factionColor"),
        bot = not isPlayer
    }
end

local function collectActors()
    local actors = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "auth:loggedIn") or getElementData(player, "rp:name") then
            addActor(actors, player)
        end
    end
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if getElementData(ped, "testbot:isBot") then
            addActor(actors, ped)
        end
    end
    return actors
end

local function refreshPlayers()
    board.players = {}
    local needle = board.search:getText():lower()
    local actors = collectActors()
    board.online = #getElementsByType("player")
    for _, actor in ipairs(actors) do
        local lower = actor.name:lower()
        if needle == "" or actor.id:find(needle, 1, true) or lower:find(needle, 1, true) then
            board.players[#board.players + 1] = actor
        end
    end
    table.sort(board.players, function(a, b)
        local aid, bid = tonumber(a.id), tonumber(b.id)
        if aid and bid then return aid < bid end
        return a.name < b.name
    end)
    board.scroll = math.max(0, math.min(board.scroll, math.max(0, #board.players - visibleRows)))
end

local function drawSearch(x, y, w, h)
    x, y, w, h = crisp(x), crisp(y), crisp(w), crisp(h)
    dxDrawRectangle(x, y, w, h, tocolor(8, 8, 8, 255))

    local text = board.search:getText()
    local shown = text ~= "" and text or board.search.placeholder
    local textColor = text ~= "" and tocolor(190, 190, 190, 255) or tocolor(105, 105, 105, 255)
    local textX, textRight = x + s(4), x + w - s(4)
    local fontScale = ChatConfig and ChatConfig.layout.fontScale or 1
    local font = ChatConfig and ChatConfig.layout.font or "default-bold"
    board.search.lastLayout = { textX = textX, textRight = textRight, scale = fontScale, font = font }
    dxDrawText(shown, textX, y, textRight, y + h, textColor, fontScale, font, "left", "center", true)

    if DXInput.active == board.search and (getTickCount() % 1000) < 520 then
        local cursorX = math.min(textX + dxGetTextWidth(text, fontScale, font), textRight)
        dxDrawRectangle(crisp(cursorX), y + s(5), 1, h - s(10), tocolor(220, 220, 220, 255))
    end
end

local function drawScoreboard()
    if getTickCount() - board.lastRefresh > 500 then board.lastRefresh = getTickCount(); refreshPlayers() end
    local w, h = s(640), s(480)
    local x, y = crisp((sw - w) / 2), crisp((sh - h) / 2)
    local border = s(5)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 230))
    dxDrawRectangle(x + 1, y + 1, w - 2, h - 2, tocolor(0, 0, 0, 130))
    dxDrawRectangle(x + border, y + s(35), w - border * 2, h - s(40), tocolor(0, 0, 0, 255))

    local topY, topH = y, s(35)
    dxDrawText("BAKU ROLE PLAY", x + s(11), topY, x + s(125), topY + topH, tocolor(35, 177, 245, 255), 1, board.brandFont or "default-bold", "left", "center", true)
    dxDrawText("BAKU-RP.COM", x + s(134), topY, x + s(260), topY + topH, tocolor(255, 255, 255, 255), 1, board.headerFont or "default-bold", "left", "center", true)

    local searchX, searchY, searchW, searchH = x + s(350), y + s(6), s(175), s(23)
    board.searchBounds = { x = searchX, y = searchY, w = searchW, h = searchH }
    drawSearch(searchX, searchY, searchW, searchH)

    local maxPlayers = tonumber(getElementData(resourceRoot, "rp:scoreboardMaxPlayers")) or board.online
    dxDrawText("ОНЛАЙН", x + s(544), topY, x + s(592), topY + topH, tocolor(35, 177, 245, 255), 1, board.headerFont or "default-bold", "left", "center", true)
    dxDrawText(tostring(board.online) .. "/" .. tostring(maxPlayers), x + s(588), topY, x + w - s(10), topY + topH, tocolor(255, 255, 255, 255), 1, board.headerFont or "default-bold", "right", "center", true)

    local headY, headH = y + s(36), s(21)
    local headerColor = tocolor(195, 195, 195, 255)
    local tableFont = ChatConfig and ChatConfig.layout.font or "default-bold"
    local chatScale = 1
    local headerScale = chatScale * 0.86
    dxDrawText("ID", x + s(14), headY, x + s(62), headY + headH, headerColor, headerScale, tableFont, "left", "center")
    dxDrawText("Имя", x + s(78), headY, x + s(345), headY + headH, headerColor, headerScale, tableFont, "left", "center")
    dxDrawText("Уровень", x + s(365), headY, x + s(468), headY + headH, headerColor, headerScale, tableFont, "left", "center")
    dxDrawText("Пинг", x + s(565), headY, x + w - s(21), headY + headH, headerColor, headerScale, tableFont, "left", "center")

    local rowY = headY + headH
    local rowH = s(23)
    for i = 1, visibleRows do
        local row = board.players[board.scroll + i]
        if not row then break end
        local ry = rowY + (i - 1) * rowH
        local selected = row.element == localPlayer
        if selected then
            dxDrawRectangle(x + s(7), ry, w - s(20), rowH, tocolor(47, 113, 151, 255))
        end
        local textColor = tocolor(255, 255, 255, 255)
        local factionColor = type(row.factionColor) == "table" and row.factionColor or nil
        local nameColor = textColor
        if factionColor then
            nameColor = tocolor(factionColor[1] or 255, factionColor[2] or 255, factionColor[3] or 255, 255)
        end
        local rowScale = chatScale
        dxDrawText(row.id, x + s(14), ry, x + s(62), ry + rowH, textColor, rowScale, tableFont, "left", "center")
        dxDrawText(row.name, x + s(78), ry, x + s(345), ry + rowH, nameColor, rowScale, tableFont, "left", "center", true)
        dxDrawText(tostring(row.level), x + s(365), ry, x + s(468), ry + rowH, textColor, rowScale, tableFont, "left", "center")
        dxDrawText(tostring(row.ping), x + s(565), ry, x + w - s(21), ry + rowH, textColor, rowScale, tableFont, "left", "center")
    end

    local trackX, trackY, trackH = x + w - s(12), headY, h - s(43)
    dxDrawRectangle(trackX, trackY, s(6), trackH, tocolor(69, 74, 76, 255))

    local maxScroll = math.max(0, #board.players - visibleRows)
    if maxScroll > 0 then
        local thumbH = math.max(s(36), trackH * visibleRows / #board.players)
        local thumbY = trackY + (trackH - thumbH) * (board.scroll / maxScroll)
        dxDrawRectangle(trackX, thumbY, s(6), thumbH, tocolor(255, 255, 255, 255))
    end
end

local function setScoreboardVisible(state)
    if board.visible == state then return end
    if state and RPUIManager and not RPUIManager.acquire(SCOREBOARD_UI_NAME, { cursor = true, inputMode = "no_binds_when_editing" }) then return end
    board.visible = state
    if state then
        refreshPlayers()
        board.search:blur()
        board.radarWasVisible = type(isPlayerHudComponentVisible) ~= "function" or isPlayerHudComponentVisible("radar")
        setPlayerHudComponentVisible("radar", false)
        triggerEvent("rp:hud:setScoreboardSuppressed", root, true)
        addEventHandler("onClientRender", root, drawScoreboard)
    else
        if DXInput.active == board.search then board.search:blur() end
        setPlayerHudComponentVisible("radar", board.radarWasVisible)
        triggerEvent("rp:hud:setScoreboardSuppressed", root, false)
        if RPUIManager then RPUIManager.release(SCOREBOARD_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
        removeEventHandler("onClientRender", root, drawScoreboard)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    board.search = DXInput:new("Начни вводить ник...", false, 32)
    board.brandFont = dxCreateFont("CompactC.ttf", s(13), false, "cleartype")
    board.headerFont = dxCreateFont("CompactC.ttf", s(13), false, "cleartype")
end)

addEventHandler("onClientKey", root, function(button, press)
    if button == "tab" and press then
        cancelEvent()
        if AuthUI and AuthUI.visible then return end
        if RPUIManager and not RPUIManager.canOpen(SCOREBOARD_UI_NAME) then return end
        setScoreboardVisible(not board.visible)
        return
    end

    if not board.visible then return end

    if DXInput.active == board.search and board.search:isSystemShortcutKey(button) then return end

    if press and button == "mouse_wheel_up" then
        cancelEvent()
        board.scroll = math.max(0, board.scroll - 1)
        return
    elseif press and button == "mouse_wheel_down" then
        cancelEvent()
        board.scroll = math.min(math.max(0, #board.players - visibleRows), board.scroll + 1)
        return
    elseif press and button == "escape" then
        cancelEvent()
        setScoreboardVisible(false)
        return
    end

    if board.search:key(button, press) then
        cancelEvent()
        board.scroll = 0
        refreshPlayers()
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if not board.visible then return end
    if board.search:char(char) then
        board.scroll = 0
        refreshPlayers()
    end
end)

addEventHandler("onClientPaste", root, function(text)
    if not board.visible then return end
    if board.search:paste(text) then
        board.scroll = 0
        refreshPlayers()
    end
end)

addEventHandler("onClientClick", root, function(button, state, absoluteX, absoluteY)
    if not board.visible or button ~= "left" or state ~= "down" then return end
    local bounds = board.searchBounds
    if not bounds then return end

    if board.search:click(absoluteX, absoluteY, bounds.x, bounds.y, bounds.w, bounds.h) then
        cancelEvent()
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if board.visible then
        setPlayerHudComponentVisible("radar", board.radarWasVisible)
        triggerEvent("rp:hud:setScoreboardSuppressed", root, false)
        if RPUIManager then RPUIManager.release(SCOREBOARD_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
    end
end)
