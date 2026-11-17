ChatConfig = {
    localChatDistance = 20,
    whisperDistance = 4,
    shoutDistanceMultiplier = 2,
    payDistance = 5,
    maxChatMessages = 100,
    adminChatMinLevel = 1,
    maxMessageLength = 128,
    maxInputLength = 80,
    inputKey = "t",
    toggleKey = "F7",
    scrollSpeed = 3,
    resizeStep = 1,
    minVisibleLines = 6,
    maxVisibleLines = 18,
    minChatWidth = 360,
    maxChatWidth = 760,

    colors = {
        normal = {255, 255, 255},
        whisper = {205, 214, 222},
        shout = {255, 224, 150},
        me = {190, 105, 235},
        do_action = {190, 105, 235},
        admin = {255, 178, 66},
        system = {180, 180, 180},
        welcome = {120, 210, 255},
        error = {239, 83, 80},
        success = {102, 187, 106},
        pay = {102, 187, 106}
    },

    layout = {
        x = 20,
        y = 32,
        width = 620,
        lineHeight = 19,
        visibleLines = 10,
        inputHeight = 30,
        font = "default-bold",
        fontScale = 1.0,
        messageFontScale = 1.0,
        outlineSize = 1,
        outlineColor = {0, 0, 0},
        outlineAlpha = 255
    },

    settings = {
        visible = true,
        scale = 1.0,
        width = 620,
        visibleLines = 10
    },

    autoCommands = {
        [")"] = "/me улыбается",
        ["))"] = "/me смеётся",
        ["("] = "/me недоволен",
        ["(("] = "/me грустит"
    }
}
