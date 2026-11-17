-- Auth data in rp_core is intentionally server-only. Return only this player's status.
local function sendSession(player)
    triggerClientEvent(player, "car:lockIdentity", resourceRoot,
        getElementData(player, "auth:loggedIn") == true and tonumber(getElementData(player, "auth:playerId")) or false)
    triggerClientEvent(player, "car:speedometerSession", resourceRoot,
        getElementData(player, "auth:loggedIn") == true, tonumber(getElementData(player, "auth:playerId")))
end

addEvent("car:requestSpeedometerSession", true)
addEventHandler("car:requestSpeedometerSession", resourceRoot, function()
    if client then sendSession(client) end
end)

addEventHandler("onElementDataChange", root, function(key)
    if (key == "auth:loggedIn" or key == "auth:playerId") and getElementType(source) == "player" then
        sendSession(source)
    end
end)
