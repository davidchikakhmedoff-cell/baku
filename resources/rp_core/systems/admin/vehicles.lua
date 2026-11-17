AdminVehicles = {
    byVehicle = {},
    byPlayer = {}
}

local function isTemporaryAdminVehicle(vehicle)
    return isElement(vehicle) and getElementData(vehicle, "temporaryAdminVehicle") == true
end

function AdminVehicles.destroy(vehicle)
    if not isElement(vehicle) then return end

    local owner = AdminVehicles.byVehicle[vehicle]
    AdminVehicles.byVehicle[vehicle] = nil

    if owner and AdminVehicles.byPlayer[owner] == vehicle then
        AdminVehicles.byPlayer[owner] = nil
    end

    if isElement(vehicle) then
        destroyElement(vehicle)
    end
end

function AdminVehicles.destroyForPlayer(player)
    if not isElement(player) then return end

    local vehicle = AdminVehicles.byPlayer[player]
    if vehicle then
        AdminVehicles.destroy(vehicle)
    end
end

function AdminVehicles.register(vehicle, owner)
    if not isElement(vehicle) or not isElement(owner) then return false end

    AdminVehicles.destroyForPlayer(owner)

    setElementData(vehicle, "temporaryAdminVehicle", true, false)
    AdminVehicles.byVehicle[vehicle] = owner
    AdminVehicles.byPlayer[owner] = vehicle
    return true
end

function AdminVehicles.markExisting(vehicle, owner)
    if not isElement(vehicle) or not isElement(owner) then return false end
    if not isTemporaryAdminVehicle(vehicle) then return false end

    AdminVehicles.byVehicle[vehicle] = owner
    AdminVehicles.byPlayer[owner] = vehicle
    return true
end

addEventHandler("onVehicleExit", root, function(player)
    if not isTemporaryAdminVehicle(source) then return end
    if AdminVehicles.byVehicle[source] ~= player then return end
    AdminVehicles.destroy(source)
end)

addEventHandler("onVehicleExplode", root, function()
    if not isTemporaryAdminVehicle(source) then return end
    setTimer(function(vehicle)
        if isElement(vehicle) then
            AdminVehicles.destroy(vehicle)
        end
    end, 1000, 1, source)
end)

addEventHandler("onPlayerQuit", root, function()
    AdminVehicles.destroyForPlayer(source)
end)

addEventHandler("onElementDestroy", root, function()
    if getElementType(source) ~= "vehicle" then return end
    if not AdminVehicles.byVehicle[source] then return end

    local owner = AdminVehicles.byVehicle[source]
    AdminVehicles.byVehicle[source] = nil
    if owner and AdminVehicles.byPlayer[owner] == source then
        AdminVehicles.byPlayer[owner] = nil
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for vehicle in pairs(AdminVehicles.byVehicle) do
        if isElement(vehicle) then
            destroyElement(vehicle)
        end
    end
    AdminVehicles.byVehicle = {}
    AdminVehicles.byPlayer = {}
end)
