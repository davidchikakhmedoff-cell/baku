addEventHandler("onClientResourceStart", resourceRoot, function()
    fadeCamera(true, 0)
    setElementFrozen(localPlayer, true)
    AuthCamera.start()
    AuthUI.show()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    showCursor(false)
    showChat(true)
    DXUtils.setRadarVisible(true)
    toggleAllControls(true)
    setCameraTarget(localPlayer)
    setElementFrozen(localPlayer, false)
end)

addEvent("auth:response", true)
addEventHandler("auth:response", resourceRoot, function(success, message, rememberedRPName)
    AuthUI.setNotice(message, success)

    if not success then
        AuthUI.submit.enabled = true
        return
    end

    -- Hide the authorization UI immediately, then let the server spawn the player.
    saveRememberedRPName(rememberedRPName)
    AuthCamera.active = false
    AuthUI.hide(true, true)
    triggerServerEvent("auth:spawnReady", localPlayer)
end)

addEvent("auth:spawned", true)
addEventHandler("auth:spawned", resourceRoot, function()
    fadeCamera(true, 0)
    DXUtils.setRadarVisible(true)
    setCameraTarget(localPlayer)
    setElementFrozen(localPlayer, false)
end)

addEvent("auth:applySpawnCamera", true)
addEventHandler("auth:applySpawnCamera", resourceRoot, function(camera)
    if type(camera) ~= "table" or not camera.x or not camera.y or not camera.z or not camera.lx or not camera.ly or not camera.lz then return end
    setCameraMatrix(camera.x, camera.y, camera.z, camera.lx, camera.ly, camera.lz)
    setTimer(function()
        if isElement(localPlayer) then setCameraTarget(localPlayer) end
    end, 120, 1)
end)
