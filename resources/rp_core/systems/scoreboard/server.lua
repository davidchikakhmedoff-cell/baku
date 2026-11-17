local MAX_PLAYERS_DATA = "rp:scoreboardMaxPlayers"

local function syncMaxPlayers()
    local maxPlayers = type(getMaxPlayers) == "function" and tonumber(getMaxPlayers()) or 0
    setElementData(resourceRoot, MAX_PLAYERS_DATA, math.max(0, maxPlayers), true)
end

addEventHandler("onResourceStart", resourceRoot, function()
    syncMaxPlayers()
    setTimer(syncMaxPlayers, 5000, 0)
end)
