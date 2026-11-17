HotelSystemConfig = {
    dimensionBase = HomeConfig.hotelDimensionBase,
    rentSeconds = HomeConfig.hotelRentSeconds,
    maxExtendDays = HomeConfig.hotelMaxExtendDays,
    expireCheckInterval = HomeConfig.hotelExpireCheckInterval,
    outsideMarker = {
        type = "arrow",
        zOffset = 0.7,
        size = 0.9,
        alpha = 205,
        color = {255, 220, 0}
    },
    interiorMarker = {
        type = "arrow",
        zOffset = 0.7,
        size = 0.9,
        alpha = 205,
        color = {255, 220, 0}
    },
    enterDistance = HomeConfig.enterDistance,
    markerDistance = HomeConfig.markerDistance,
    interior = {
        interior = 5,
        playerSpawn = { x = 2233.62, y = -1113.35, z = 1050.88, rotation = 0 },
        menuMarker = { x = 2233.82, y = -1115.02, z = 1050.88 },
        spawn = { x = 2233.62, y = -1113.35, z = 1050.88, rotation = 0 },
        control = { x = 2233.82, y = -1115.02, z = 1050.88 },
        exit = { x = 2233.82, y = -1115.18, z = 1050.88 }
    }
}

HomeConfig.hotelInterior = HotelSystemConfig.interior
