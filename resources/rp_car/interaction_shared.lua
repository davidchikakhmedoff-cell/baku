-- Reject controls during entry/exit tasks, even if an occupied vehicle is already reported.
CarInteraction = {}
local completedEntries = setmetatable({}, {__mode="k"})
function CarInteraction.ready(player)
    if not isElement(player) or isPedDead(player) then return false end
    local occupied = getPedOccupiedVehicle(player)
    local occupiedSeat = occupied and getPedOccupiedVehicleSeat(player)
    if occupied and completedEntries[player] == occupied and isPedInVehicle(player)
        and occupiedSeat ~= nil and occupiedSeat ~= false and getVehicleOccupant(occupied, occupiedSeat) == player then
        return true
    end
    -- Task inspection is client-only on MTA versions without a server API.
    if type(getPedTask) == "function" then
    for _,taskType in ipairs({"primary", "secondary"}) do
        for level = 0, 4 do
            local task = getPedTask(player, taskType, level)
            if task and (task:find("ENTER_CAR",1,true) or task:find("LEAVE_CAR",1,true)
                or task:find("CAR_GET_IN",1,true) or task:find("CAR_GET_OUT",1,true)
                or task:find("CAR_OPEN_DOOR",1,true) or task:find("CAR_CLOSE_DOOR",1,true)) then
                return false
            end
        end
    end
    end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle then return true end -- Preserve on-foot locking of one's own car.
    local seat = getPedOccupiedVehicleSeat(player)
    return isPedInVehicle(player) and seat ~= false and seat ~= nil
        and getVehicleOccupant(vehicle, seat) == player
end

function CarInteraction.canToggleLock(player)
    if not isElement(player) or isPedDead(player) then return false end
    -- The remote lock remains usable outside, including while approaching a door.
    if not getPedOccupiedVehicle(player) and not isPedInVehicle(player) then return true end
    return CarInteraction.ready(player)
end

-- A completed entry event is authoritative even when a dealership warp leaves
-- an old GTA entry task visible for a while. Start-exit removes this exception.
if localPlayer then
    addEventHandler("onClientVehicleEnter", root, function(player)
        if player == localPlayer then completedEntries[player] = source end
    end)
    addEventHandler("onClientVehicleStartEnter", root, function(player)
        if player == localPlayer then completedEntries[player] = nil end
    end)
    addEventHandler("onClientVehicleStartExit", root, function(player)
        if player == localPlayer then completedEntries[player] = nil end
    end)
    addEventHandler("onClientVehicleExit", root, function(player)
        if player == localPlayer then completedEntries[player] = nil end
    end)
end
