FuelConfig = {
    tank = 60, initial = 30,
    modelTanks = {}, -- [model ID] = litres
    price = 5, litresPerSecond = 2,
    tickMs = 500, saveMs = 30000,
    movementThreshold = 0.1, teleportSlack = 4, maxSampleMs = 2000,
    consumption = {{40, 8}, {80, 10}, {120, 12}, {math.huge, 15}},
    stations = {} -- Populated below from documented stock GTA SA forecourts.
}
function FuelConfig.capacity(model)
    return math.max(1, tonumber(FuelConfig.modelTanks[model]) or FuelConfig.tank)
end
function FuelConfig.clamp(value, capacity)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = FuelConfig.initial end
    return math.max(0, math.min(capacity, value))
end
function FuelConfig.used(distance, speed, dt, oldSpeed)
    -- Reject jumps, dimension/interior changes (caller), loading and stalled samples.
    if dt <= 0 or dt > FuelConfig.maxSampleMs or speed < FuelConfig.movementThreshold then return 0 end
    local limit = math.max(speed, oldSpeed or speed) / 3.6 * dt / 1000 * 1.5 + FuelConfig.teleportSlack
    if distance > limit then return 0 end
    for _, band in ipairs(FuelConfig.consumption) do
        if speed <= band[1] then return distance / 1000 * band[2] / 100 end
    end
    return 0
end
-- Stock forecourts (world coordinates, interior/dimension 0).
FuelConfig.stations = {
    {name="Idlewood, Los Santos", x=1941.6, y=-1774.3, z=13.4, radius=17},
    {name="Temple, Los Santos", x=1004.0, y=-939.3, z=42.2, radius=16},
    {name="Easter Basin, San Fierro", x=-1676.0, y=414.2, z=7.2, radius=17},
    {name="Juniper Hollow, San Fierro", x=-2410.0, y=976.0, z=45.3, radius=17},
    {name="Xoomer, Las Venturas", x=1596.4, y=2199.0, z=10.8, radius=17},
    {name="Spinybed, Las Venturas", x=2147.0, y=2747.0, z=10.8, radius=17},
    {name="Flint County", x=-90.0, y=-1169.0, z=2.4, radius=16},
    {name="Dillimore", x=655.7, y=-565.0, z=16.3, radius=14},
    {name="Angel Pine", x=-1605.0, y=-2714.0, z=48.5, radius=16},
    {name="Tierra Robada", x=-1471.0, y=1863.0, z=32.6, radius=17},
    {name="El Quebrados", x=-1327.0, y=2677.0, z=50.1, radius=16},
    {name="Bone County", x=611.0, y=1696.0, z=7.0, radius=17}
}
