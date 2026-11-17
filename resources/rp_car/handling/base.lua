VehicleHandling = {
    [560] = {
        name = "BMW M5 F90",
        maxVelocity = 250,
        engineAcceleration = 9,
        mass = 1800,
        tractionMultiplier = 1.05,
        tractionLoss = 0.86,
        brakeDeceleration = 9.2,
        brakeBias = 0.54,
        suspensionForceLevel = 1.5,
        suspensionDamping = 0.5,
        suspensionHighSpeedDamping = 0,
        suspensionUpperLimit = 0.15,
        suspensionLowerLimit = -0.17,
        suspensionFrontRearBias = 0.50,
        suspensionAntiDiveMultiplier = 1,
        driveType = "awd"
    },
    [579] = {
        name = "BMW X5M E70",
        maxVelocity = 220,
        engineAcceleration = 18,
        mass = 2300,
        tractionMultiplier = 0.98,
        tractionLoss = 0.80,
        brakeDeceleration = 8.0,
        brakeBias = 0.55,
        suspensionForceLevel = 0.95,
        suspensionDamping = 0.12,
        suspensionHighSpeedDamping = 0,
        suspensionUpperLimit = 0.34,
        suspensionLowerLimit = -0.12,
        suspensionFrontRearBias = 0.52,
        suspensionAntiDiveMultiplier = 0.25,
        driveType = "awd"
    },
    [529] = {
        name = "BMW M5 F10",
        maxVelocity = 250,
        engineAcceleration = 22,
        mass = 1850,
        tractionMultiplier = 1.02,
        tractionLoss = 0.84,
        brakeDeceleration = 8.8,
        brakeBias = 0.54,
        suspensionForceLevel = 1.08,
        suspensionDamping = 0.13,
        suspensionHighSpeedDamping = 0,
        suspensionUpperLimit = 0.29,
        suspensionLowerLimit = -0.12,
        suspensionFrontRearBias = 0.50,
        suspensionAntiDiveMultiplier = 0.32,
        driveType = "rwd"
    },
    [547] = {
        name = "BMW M3 E46",
        maxVelocity = 190,
        engineAcceleration = 16,
        mass = 1500,
        tractionMultiplier = 1.00,
        tractionLoss = 0.82,
        brakeDeceleration = 8.5,
        brakeBias = 0.53,
        suspensionForceLevel = 1.05,
        suspensionDamping = 0.13,
        suspensionHighSpeedDamping = 0,
        suspensionUpperLimit = 0.28,
        suspensionLowerLimit = -0.13,
        suspensionFrontRearBias = 0.50,
        suspensionAntiDiveMultiplier = 0.30,
        driveType = "rwd"
    },
    [411] = {
        name = "AUDI R8",
        maxVelocity = 300,
        engineAcceleration = 28,
        mass = 1650,
        tractionMultiplier = 1.08,
        tractionLoss = 0.88,
        brakeDeceleration = 9.8,
        brakeBias = 0.53,
        suspensionForceLevel = 1.5,
        suspensionDamping = 0.5,
        suspensionHighSpeedDamping = 0,
        suspensionUpperLimit = 0.25,
        suspensionLowerLimit = -0.11,
        suspensionFrontRearBias = 0.49,
        suspensionAntiDiveMultiplier = 1.9,
        driveType = "awd"
    }
}

TunableVehicles = {
    [560] = {
        suspensionMultiplier = 1,
        accelerationMultiplier = 1,
        maxSpeedMultiplier = 1.5,
        prices = {
            suspension = {35000, 45000, 55000},
            acceleration = {50000, 65000, 80000},
            max_speed = {65000, 80000, 95000}
        },
        maxLevel = 3
    },
    [579] = {
        suspensionMultiplier = 0.85,
        accelerationMultiplier = 0.75,
        maxSpeedMultiplier = 0.75,
        prices = {
            suspension = {30000, 40000, 55000},
            acceleration = {42000, 55000, 72000},
            max_speed = {55000, 70000, 90000}
        },
        maxLevel = 3
    },
    [529] = {
        suspensionMultiplier = 1.0,
        accelerationMultiplier = 0.9,
        maxSpeedMultiplier = 0.9,
        prices = {
            suspension = {32000, 42000, 58000},
            acceleration = {46000, 60000, 78000},
            max_speed = {60000, 76000, 98000}
        },
        maxLevel = 3
    },
    [547] = {
        suspensionMultiplier = 1.0,
        accelerationMultiplier = 1.0,
        maxSpeedMultiplier = 1.0,
        prices = {
            suspension = {22000, 30000, 42000},
            acceleration = {32000, 42000, 56000},
            max_speed = {40000, 52000, 70000}
        },
        maxLevel = 3
    },
    [411] = {
        suspensionMultiplier = 0.9,
        accelerationMultiplier = 0.85,
        maxSpeedMultiplier = 0.85,
        prices = {
            suspension = {45000, 60000, 80000},
            acceleration = {65000, 85000, 115000},
            max_speed = {85000, 110000, 145000}
        },
        maxLevel = 3
    }
}
