AuthConfig = {
    resourceName = "rp_core",
    passwordSalt = "premium_dx_auth",
    colors = {
        window = {14, 18, 23},
        panel = {22, 27, 33},
        primary = {79, 195, 247},
        white = {255, 255, 255},
        text = {222, 228, 234},
        muted = {146, 156, 166},
        error = {218, 78, 82},
        success = {79, 195, 247},
        black = {0, 0, 0}
    },
    design = { width = 1920, height = 1080, panelWidth = 480, panelHeight = 520, radius = 14, overlayAlpha = 64 },
    input = { rpNameMax = 32, passwordMin = 6, passwordMax = 32 },
    rememberKey = "auth_remembered_rp_name",
    database = { file = "auth.db", table = "players" },
    spawn = { x = 367.9, y = -2038.8, z = 7.8, rotation = 180, skin = 0, interior = 0, dimension = 0 },
    skins = {
        male = {0, 1, 2, 7, 14, 15, 20, 21, 22, 23, 24, 25, 26, 28, 29, 35, 36, 37, 44, 46, 47, 48, 50, 57, 58, 59, 60, 66, 72, 73, 98, 101, 170, 180, 182, 184, 186, 187, 188, 200, 202, 206, 210, 212, 217, 223, 240, 250},
        female = {9, 10, 11, 12, 13, 31, 38, 39, 40, 41, 53, 54, 55, 56, 63, 64, 69, 75, 76, 77, 85, 87, 88, 89, 90, 91, 129, 130, 131, 138, 141, 148, 150, 151, 152, 157, 169, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 201}
    },
    hospital = { x = 1177.9, y = -1323.4, z = 14.1, rotation = 270, skin = 0, interior = 0, dimension = 0, health = 25 },
    camera = {
        position = {375.0, -2055.0, 28.0},
        lookAt = {365.0, -1935.0, 7.0}
    }
}
