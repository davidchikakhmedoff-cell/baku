-- Per-model suspension height tuning.
-- More negative suspensionLowerLimit lowers the vehicle body in MTA handling.
-- Level 0 restores the model base value from VehicleHandling; values below are explicit targets.

VehicleSuspensionLevels = {
    [560] = {
        [1] = -0.22,
        [2] = -0.17,
        [3] = -0.12
    },
    [579] = {
        [1] = -0.15,
        [2] = -0.18,
        [3] = -0.21
    },
    [529] = {
        [1] = -0.15,
        [2] = -0.18,
        [3] = -0.21
    },
    [547] = {
        [1] = -0.16,
        [2] = -0.19,
        [3] = -0.22
    },
    [411] = {
        [1] = -0.14,
        [2] = -0.17,
        [3] = -0.20
    }
}

SuspensionLevelPrices = {
    [0] = 0,
    [1] = 2500,
    [2] = 4500,
    [3] = 7500
}
