-- Auth data in rp_core is intentionally server-only. Return only this player's status.
local function sendSession(player)
    triggerClientEvent(player, "car:speedometerSession", resourceRoot,
        getElementData(player, "auth:loggedIn") == true)
end

addEvent("car:requestSpeedometerSession", true)
addEventHandler("car:requestSpeedometerSession", resourceRoot, function()
    if client then sendSession(client) end
end)

addEventHandler("onElementDataChange", root, function(key)
    if key == "auth:loggedIn" and getElementType(source) == "player" then
        sendSession(source)
    end
end)
