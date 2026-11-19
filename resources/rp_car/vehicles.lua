VehicleStatuses = {
    active = "active",
    parked = "parked",
    sale = "sale",
    stored = "stored",
    noParking = "no_parking",
    destroyed = "destroyed"
}

function getVehicleDisplayName(model, fallback)
    local configured = VehicleModelNames and VehicleModelNames[tonumber(model)]
    if configured then return configured end
    if fallback and fallback ~= "" then return tostring(fallback) end
    return getVehicleNameFromModel(tonumber(model) or 400) or ("Model " .. tostring(model))
end

-- One model-name source for dealerships and faction key menus.
function getConfiguredVehicleName(model)
    model=tonumber(model)
    for _,dealership in ipairs(Dealerships or {}) do
        for _,vehicle in ipairs(dealership.vehicles or {}) do
            if tonumber(vehicle.model)==model and type(vehicle.customName)=="string" and vehicle.customName:find("%S") then
                return getVehicleDisplayName(model, vehicle.customName)
            end
        end
    end
    return getVehicleDisplayName(model)
end
