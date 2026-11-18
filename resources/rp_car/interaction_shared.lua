-- Seat readiness follows MTA's completed-entry event, not GTA task names that
-- can remain stale after warps, canceled animations or a resource restart.
CarInteraction = {}
local entering = setmetatable({}, {__mode="k"})
function CarInteraction.ready(player)
    if not isElement(player) or isPedDead(player) then return false end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle then return true end
    if entering[player] == vehicle then return false end
    local seat = getPedOccupiedVehicleSeat(player)
    return isPedInVehicle(player) and seat ~= false and seat ~= nil
        and getVehicleOccupant(vehicle, seat) == player
end
function CarInteraction.canToggleLock(player)
    if not isElement(player) or isPedDead(player) then return false end
    if not getPedOccupiedVehicle(player) and not isPedInVehicle(player) then return true end
    return CarInteraction.ready(player)
end
local prefix = localPlayer and "onClientVehicle" or "onVehicle"
addEventHandler(prefix.."StartEnter", root, function(player)
    entering[player] = source
end)
addEventHandler(prefix.."Enter", root, function(player)
    entering[player] = nil
end)
addEventHandler(prefix.."Exit", root, function(player)
    entering[player] = nil
end)
addEventHandler(localPlayer and "onClientPlayerWasted" or "onPlayerWasted", root, function()
    entering[source] = nil
end)
