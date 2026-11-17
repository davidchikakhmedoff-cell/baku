local font = "default-bold"
local actorsCache = {}
local actorState = {}
local lastActorsRefresh = 0

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do setPlayerNametagShowing(player, false) end
end)

addEventHandler("onClientPlayerJoin", root, function() setPlayerNametagShowing(source, false) end)
addEventHandler("onClientElementDestroy", root, function() actorState[source] = nil end)
addEventHandler("onClientPlayerQuit", root, function() actorState[source] = nil end)

local function refreshActors()
    actorsCache = {}
    for _, player in ipairs(getElementsByType("player", root, true)) do
        actorsCache[#actorsCache + 1] = player
    end
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if getElementData(ped, "testbot:isBot") then
            actorsCache[#actorsCache + 1] = ped
        end
    end
end

local function getActorText(actor)
    local state = actorState[actor]
    if not state then
        state = {}
        actorState[actor] = state
    end

    local isPlayer = getElementType(actor) == "player"
    local name = getElementData(actor, "rp:name") or (isPlayer and getPlayerName(actor) or "Unknown")
    local id = getElementData(actor, "rp:id") or "?"
    if state.name ~= name or state.id ~= id then
        state.name = name
        state.id = id
        state.text = string.format("%s (%s)", name, id)
    end
    return state.text
end

local function drawOutlinedText(text, x, y, color, alpha, scale)
    local outline = RPNicknameConfig.outlineColor
    local outlineAlpha = math.min(230, alpha)
    local offsets = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    }

    for _, offset in ipairs(offsets) do
        dxDrawText(text, x + offset[1], y + offset[2], x + offset[1], y + offset[2], tocolor(outline[1], outline[2], outline[3], outlineAlpha), scale, font, "center", "center")
    end
    dxDrawText(text, x, y, x, y, tocolor(color[1], color[2], color[3], alpha), scale, font, "center", "center")
end

local function drawBar(x, y, w, h, progress, fillColor, alpha)
    progress = math.max(0, math.min(1, progress or 0))
    local bg = RPNicknameConfig.barBackground
    dxDrawRectangle(x - 1, y - 1, w + 2, h + 2, tocolor(0, 0, 0, 210 * alpha / 255))
    dxDrawRectangle(x, y, w, h, tocolor(bg[1], bg[2], bg[3], 220 * alpha / 255))
    if progress > 0 then
        dxDrawRectangle(x, y, math.floor(w * progress), h, tocolor(fillColor[1], fillColor[2], fillColor[3], alpha))
    end
end

addEventHandler("onClientRender", root, function()
    local tick = getTickCount()
    if tick - lastActorsRefresh > 750 then
        lastActorsRefresh = tick
        refreshActors()
    end

    local cx, cy, cz = getCameraMatrix()
    local localDim = getElementDimension(localPlayer)
    local localInt = getElementInterior(localPlayer)

    for _, actor in ipairs(actorsCache) do
        if actor ~= localPlayer and isElement(actor) and isElementOnScreen(actor) and getElementDimension(actor) == localDim and getElementInterior(actor) == localInt then
            local px, py, pz = getPedBonePosition(actor, 8)
            local distance = getDistanceBetweenPoints3D(cx, cy, cz, px, py, pz)
            if distance <= RPNicknameConfig.maxDistance and isLineOfSightClear(cx, cy, cz, px, py, pz, true, false, false, true, false, false, false, actor) then
                local sx, sy = getScreenFromWorldPosition(px, py, pz + 0.35, 0.06)
                if sx and sy then
                    local fadeStart = RPNicknameConfig.visibleDistance
                    local fade = distance <= fadeStart and 1 or math.max(0, math.min(1, (RPNicknameConfig.maxDistance - distance) / (RPNicknameConfig.maxDistance - fadeStart)))
                    local scale = math.max(0.62, RPNicknameConfig.baseScale - distance * 0.012)
                    local alpha = math.floor(255 * fade)
                    local text = getActorText(actor)
                    local color = getElementData(actor, "rp:nametagColor") or RPNicknameConfig.defaultColor

                    drawOutlinedText(text, sx, sy, color, alpha, scale)

                    local textW = dxGetTextWidth(text, scale, font)
                    local barW = math.max(RPNicknameConfig.barWidthMin * scale, textW + RPNicknameConfig.barWidthPadding * scale)
                    local barH = math.max(3, RPNicknameConfig.barHeight * scale)
                    local gap = math.max(2, RPNicknameConfig.barGap * scale)
                    local barX = sx - barW / 2
                    local barY = sy + 12 * scale
                    local health = math.max(0, math.min(100, getElementHealth(actor))) / 100
                    local armor = math.max(0, math.min(100, getPedArmor(actor))) / 100

                    drawBar(barX, barY, barW, barH, health, RPNicknameConfig.hpColor, alpha)
                    if armor > 0 then
                        drawBar(barX, barY + barH + gap, barW, barH, armor, RPNicknameConfig.armorColor, alpha)
                    end
                end
            end
        end
    end
end)
