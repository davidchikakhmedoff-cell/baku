local testBot

local function createTestBot()
    if not TestBotConfig.enabled or isElement(testBot) then return end

    local p = TestBotConfig.position
    testBot = createPed(TestBotConfig.skin, p.x, p.y, p.z, p.rotation)
    if not testBot then
        outputDebugString("[TestBot] Failed to create test bot.", 1)
        return
    end

    setElementParent(testBot, resourceRoot)
    setElementInterior(testBot, p.interior)
    setElementDimension(testBot, p.dimension)
    setElementFrozen(testBot, true)
    setElementData(testBot, "testbot:isBot", true, true)
    setElementData(testBot, "rp:name", TestBotConfig.name, true)
    setElementData(testBot, "rp:level", TestBotConfig.level, true)
    setElementData(testBot, "rp:experience", 0, true)
    setElementData(testBot, "rp:nametagColor", TestBotConfig.color, true)

    setElementData(testBot, "rp:id", TestBotConfig.id, true)
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(createTestBot, 1000, 1)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(testBot) then
        destroyElement(testBot)
    end
end)
