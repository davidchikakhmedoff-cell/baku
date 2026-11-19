-- Canonical names shared by dealership UI, personal cars and faction keys.
-- These entries name models; they do not add offers/prices to the dealership.
VehicleModelNames = {
    [421] = "LEXUX LS 400 XF10",
    [404] = "TOYOTA SEQUOIA",
    [546] = "FORD CROWN VICTORIA",
    [479] = "HUMMER H2"
}

Dealerships = {
    {
        id = 1,
        name = "Автосалон Лос-Сантос",
        blipIcon = 55,
        blipSize = 2,
        blipColor = {79, 195, 247, 255},
        blipVisibleDistance = 250,
        playerSpawn = { x = 562.2, y = -1292.8, z = 17.2, rotation = 0, interior = 0, dimension = 0 },
        purchasedVehicleSpawn = { x = 562.12, y = -1246.21, z = 16.77, rotation = 300, interior = 0, dimension = 0 },
        cancelExitPosition = { x = 562.2, y = -1292.8, z = 17.2, rotation = 0, interior = 0, dimension = 0 },
        vehicles = {
            {
                id = 1,
                model = 560,
                customName = "BMW M5 F90",
                price = 540000,
                maxSpeed = 270,
                position = { x = 562.5, y = -1291.2, z = 17.1, rotation = 360, interior = 0, dimension = 0 }
            },
            {
                id = 2,
                model = 579,
                customName = "BMW X5M E70",
                price = 500000,
                maxSpeed = 220,
                position = { x = 558.5, y = -1290.7, z = 17.09, rotation = 360, interior = 0, dimension = 0 }
            },
            {
                id = 3,
                model = 529,
                customName = "BMW M5 F10",
                price = 430000,
                maxSpeed = 250,
                position = { x = 554.5, y = -1291, z = 17.12, rotation = 360, interior = 0, dimension = 0 }
            },
            {
                id = 4,
                model = 547,
                customName = "BMW M3 E46",
                price = 160000,
                maxSpeed = 190,
                position = { x = 550.5, y = -1291, z = 17.1, rotation = 360, interior = 0, dimension = 0 }
            },
            {
                id = 5,
                model = 411,
                customName = "AUDI R8",
                price = 670000,
                maxSpeed = 300,
                position = { x = 566, y = -1281, z = 16.85, rotation = 102, interior = 0, dimension = 0 }
            }
        }
    }
}

function getDealershipById(id)
    id = tonumber(id)
    for _, dealership in ipairs(Dealerships or {}) do
        if tonumber(dealership.id) == id then return dealership end
    end
    return false
end

function getDealershipVehicle(dealershipId, vehicleId)
    local dealership = getDealershipById(dealershipId)
    if not dealership then return false end
    vehicleId = tonumber(vehicleId)
    for _, vehicle in ipairs(dealership.vehicles or {}) do
        if tonumber(vehicle.id) == vehicleId then return vehicle, dealership end
    end
    return false
end
