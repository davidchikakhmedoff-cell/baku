AdminConfig = {
    openKey = "F2",
    reportsKey = "F3",
    command = "apanel",
    defaultBanSeconds = 86400,
    vehicleMaxHealth = 1000,
    levels = {
        [1] = "Помощник",
        [3] = "Администратор",
        [5] = "Старший администратор",
        [10] = "Owner"
    },
    typeNames = {
        owner = "Owner",
        senior = "Старший администратор",
        admin = "Администратор",
        helper = "Хелпер"
    },
    typeByLevel = {
        { min = 10, type = "owner" },
        { min = 5, type = "senior" },
        { min = 3, type = "admin" },
        { min = 1, type = "helper" }
    },
    permissions = {
        owner = { all = true },
        senior = {
            openPanel = true, openReports = true, answerReports = true, manageReports = true, adminChat = true,
            teleportTo = true, teleportHere = true, teleportPlayerToPlayer = true, spectate = true,
            spawn = true, kill = true, health = true, armor = true, skin = true,
            vehicle = true, vehicleHealth = true, weapon = true,
            mute = true, unmute = true, freeze = true, unfreeze = true, kick = true, ban = true, unban = true
        },
        admin = {
            openPanel = true, openReports = true, answerReports = true, manageReports = true, adminChat = true,
            teleportTo = true, teleportHere = true, teleportPlayerToPlayer = true, spectate = true,
            spawn = true, kill = true, health = true, armor = true,
            vehicle = true, vehicleHealth = true,
            mute = true, unmute = true, freeze = true, unfreeze = true, kick = true
        },
        helper = {
            openPanel = true, openReports = true, answerReports = true, manageReports = true, adminChat = true,
            teleportTo = true, spectate = true, health = true, armor = true,
            vehicle = true, vehicleHealth = true
        }
    }
}

Admins = {
      ["David_Akhmedov"] = 10,

    -- ["John_Smith"] = 10,
    -- ["David_Johnson"] = 5
}
