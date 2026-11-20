CarConfig = {
    DebugMode = false,

    mapBlips = {
        { x = 2489.6475, y = -1954.1689, z = 13.4189, icon = 47, size = 2, visibleDistance = 250 }
    },

    database = {
        file = "rp_car.db"
    },

    colors = {
        window = {14, 17, 21, 232},
        panel = {24, 29, 35, 228},
        button = {31, 37, 44, 235},
        buttonHover = {42, 52, 61, 245},
        primary = {79, 195, 247, 255},
        text = {245, 248, 250, 255},
        muted = {165, 174, 183, 255},
        green = {102, 187, 106},
        red = {239, 83, 80}
    },

    events = {
        openDealership = "car:openDealership",
        closeDealership = "car:closeDealership",
        buyVehicle = "car:buyVehicle",
        buyVehicleRequest = "car:buyVehicleRequest",
        cancelDealership = "car:cancelDealership",
        openUsedMarket = "car:openUsedMarket",
        usedMarketAction = "car:usedMarketAction",
        sellStateVehicle = "car:sellStateVehicle",
        offerVehicle = "car:offerVehicle",
        receiveOffer = "car:receiveOffer",
        answerOffer = "car:answerOffer",
        resetCamera = "car:resetCamera",
        setControlsEnabled = "car:setControlsEnabled",
        beginAnimatedExit = "car:beginAnimatedExit",
        animatedExitComplete = "car:animatedExitComplete",
        forceExitVehicle = "car:forceExitVehicle",
        toggleEngine = "car:toggleEngine",
        toggleLock = "car:toggleLock",
        toggleLights = "car:toggleLights",
        toggleHandbrake = "car:toggleHandbrake",
        playLockSound = "car:playLockSound",
        openTuning = "car:openTuning",
        tuningAction = "car:tuningAction",
        previewTuning = "car:previewTuning",
        tuningSection = "car:tuningSection",
        previewToner = "car:previewToner",
        tonerAction = "car:tonerAction",
        applyTonerPreview = "car:applyTonerPreview",
        exitTuning = "car:exitTuning",
        setTuningCamera = "car:setTuningCamera"
    },

    stateVehicleSellPercent = 50,
    sellOfferTimeout = 30000,
    purchaseCooldown = 2500,
    animatedExitFallbackDelay = 3500,
    sellDistance = 5,
    deliveryClearRadius = 4,
    VehicleRespawnAfterExplosion = 5000,
    personalVehicleRespawnDelay = 5000,
    personalVehicleRespawnRetryDelay = 5000,
    personalVehicleRespawnMaxAttempts = 6,
    parkingSpawnZOffset = 0,
    parkingSettleDelay = 1000,
    lockAimDistance = 25,
    lockServerDistance = 25,
    headlightFlashInterval = 140,
    headlightFlashCount = 2,
    tonerPrice = 2500,

    TuningPreview = {
        interior = 0,
        dimensionBase = 10000,
        settleDelay = 900,
        teleportZOffset = 0.18,
        vehiclePosition = { x = 404.30, y = 2536.40, z = 16.55, rx = 0, ry = 0, rz = 90 },
        returnPositions = {
            [1] = { x = 1041.42, y = -1035.10, z = 31.75, rotation = 180, interior = 0, dimension = 0 },
            [2] = { x = -1944.15, y = 245.03, z = 34.32, rotation = 270, interior = 0, dimension = 0 },
            [3] = { x = 2386.66, y = 1035.90, z = 10.67, rotation = 180, interior = 0, dimension = 0 }
        },
        vehicle = { x = 404.30, y = 2536.40, z = 16.55, rotation = 90 },
        camera = { x = 398.80, y = 2532.20, z = 18.95, lookX = 404.30, lookY = 2536.40, lookZ = 17.45 }
    },

    TuningZone = {
        interior = 0,
        dimensionBase = 10000,
        settleDelay = 900,
        teleportZOffset = 0.18,
        vehiclePosition = { x = 404.30, y = 2536.40, z = 16.55, rx = 0, ry = 0, rz = 90 },
        returnPositions = {
            [1] = { x = 1041.42, y = -1035.10, z = 31.75, rotation = 180, interior = 0, dimension = 0 },
            [2] = { x = -1944.15, y = 245.03, z = 34.32, rotation = 270, interior = 0, dimension = 0 },
            [3] = { x = 2386.66, y = 1035.90, z = 10.67, rotation = 180, interior = 0, dimension = 0 }
        },
        vehicle = { x = 404.30, y = 2536.40, z = 16.55, rotation = 90 },
        camera = { x = 398.80, y = 2532.20, z = 18.95, lookX = 404.30, lookY = 2536.40, lookZ = 17.45 }
    },

    TuningCamera = {
        positionOffset = { x = -4.2, y = -5.0, z = 2.1 },
        targetOffset = { x = 0, y = 0, z = 0.85 },
        defaultDistance = 6.2,
        minDistance = 3.35,
        maxDistance = 11.5,
        minPitch = -0.12,
        maxPitch = 1.18,
        rotateSpeed = 0.011,
        verticalSpeed = 0.009,
        zoomStep = 0.55,
        smoothing = 12,
        collisionPadding = 0.3,
        groundClearance = 0.35
    },

    tuningInterior = {
        interior = 0,
        dimensionBase = 10000,
        settleDelay = 900,
        teleportZOffset = 0.18,
        vehiclePosition = { x = 404.30, y = 2536.40, z = 16.55, rx = 0, ry = 0, rz = 90 },
        cameraPosition = { x = 398.80, y = 2532.20, z = 18.95 },
        cameraTarget = { x = 404.30, y = 2536.40, z = 17.45 },
        vehicle = { x = 404.30, y = 2536.40, z = 16.55, rotation = 90 },
        camera = { x = 398.80, y = 2532.20, z = 18.95, lookX = 404.30, lookY = 2536.40, lookZ = 17.45 }
    },

    usedMarket = {
        name = "Базар подержанных автомобилей",
        blipIcon = 55,
        blipSize = 2,
        blipColor = {79, 195, 247, 255},
        blipVisibleDistance = 250,
        marker = {
            x = -2116.36,
            y = -808.45,
            z = 32.02,
            size = 4,
            interior = 0,
            dimension = 0
        }
    },

    ui = {
        width = 380,
        buttonHeight = 36,
        radius = 7,
        padding = 22,
        gap = 8
    }
}

function CarConfig.formatMoney(value)
    local amount = math.max(0, math.floor(tonumber(value) or 0))
    local left, num, right = tostring(amount):match("^([^%d]*%d)(%d*)(.-)$")
    return "$" .. (left and left .. num:reverse():gsub("(%d%d%d)", "%1 "):reverse() .. right or tostring(amount))
end
