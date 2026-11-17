-- Reject controls during entry/exit tasks, even if an occupied vehicle is already reported.
CarInteraction = {}
function CarInteraction.ready(player)
    if not isElement(player) or isPedDead(player) then return false end
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
