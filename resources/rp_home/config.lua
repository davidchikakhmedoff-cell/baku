HomeConfig = {
    DebugMode = false,
    database = { file = "homes.db" },
    maxHousesPerPlayer = 1,
    stateSellPercent = 50,
    salePrice = { min = 1, max = 50000000 },
    markerDistance = 3.0,
    enterDistance = 4.0,
    markerSize = 1.0,
    markerAlpha = 180,
    propertyLabel = {
        distance = 12,
        zOffset = 1.2,
        scale = 1.0,
        font = "default-bold",
        houseColor = {0, 190, 255, 255},
        hotelColor = {239, 83, 80, 255},
        outlineColor = {0, 0, 0, 220}
    },
    exitMarkerSize = 1.0,
    controlMarkerSize = 1.0,
    adminLevel = 3,
    dimensionBase = 60000,
    hotelDimensionBase = 30000,
    hotelRentSeconds = 86400,
    hotelMaxExtendDays = 14,
    hotelExpireCheckInterval = 60000,
    gpsBlipIcon = 31,
    parkingSetupKey = "h",
    colors = {
        panel = {20, 24, 30, 238},
        panel2 = {29, 35, 42, 242},
        primary = {79, 195, 247, 255},
        white = {245, 248, 252, 255},
        muted = {150, 160, 170, 255},
        red = {239, 83, 80, 255},
        green = {102, 187, 106, 255}
    },
    interiors = {
        {
            key = "cheap",
            name = "Дешёвый",
            class = "E",
            className = "Дешёвый",
            interior = 5,
            spawn = { x = 2233.75, y = -1113.15, z = 1050.88, rotation = 0 },
            exit = { x = 2233.83, y = -1115.18, z = 1050.88 },
            control = { x = 2233.7, y = -1114.55, z = 1050.88 }
        },
        {
            key = "low_mid",
            name = "Ниже среднего",
            class = "D",
            className = "Ниже среднего",
            interior = 2,
            spawn = { x = 2467, y = -1698.32, z = 1013.51, rotation = 90 },
            exit = { x = 2465.70, y = -1698.10, z = 1013.51 },
            control = { x = 2468.45, y = -1698.32, z = 1013.51 }
        },
        {
            key = "middle",
            name = "Средний",
            class = "C",
            className = "Средний",
            interior = 10,
            spawn = { x = 2261.5, y = -1135.85, z = 1050.63, rotation = 270 },
            exit = { x = 2260.76, y = -1137.73, z = 1050.63 },
            control = { x = 2260, y = -1135.85, z = 1050.63 }
        },
        {
            key = "upper_mid",
            name = "Выше среднего",
            class = "B",
            className = "Выше среднего",
            interior = 3,
            spawn = { x = 2496, y = -1694.38, z = 1014.74, rotation = 180 },
            exit = { x = 2495.52, y = -1695.22, z = 1014.74 },
            control = { x = 2496, y = -1692.82, z = 1014.74 }
        },
        {
            key = "expensive",
            name = "Дорогой",
            class = "A",
            className = "Дорогой",
            interior = 8,
            spawn = { x = 2365.25, y = -1133.80, z = 1050.88, rotation = 0 },
            exit = { x = 2365.42, y = -1133.61, z = 1050.88 },
            control = { x = 2365.25, y = -1134.95, z = 1050.88 }
        }
    }
}

function HomeConfig.getInterior(key)
    for _, item in ipairs(HomeConfig.interiors) do
        if item.key == key then return item end
    end
    return HomeConfig.interiors[1]
end
