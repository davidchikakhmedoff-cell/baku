VehicleStatuses = {
    active = "active",
    parked = "parked",
    sale = "sale",
    stored = "stored",
    noParking = "no_parking",
    destroyed = "destroyed"
}

function getVehicleDisplayName(model, fallback)
    if fallback and fallback ~= "" then return tostring(fallback) end
    return getVehicleNameFromModel(tonumber(model) or 400) or ("Model " .. tostring(model))
end
