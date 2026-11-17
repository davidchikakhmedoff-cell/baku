local spectating = false
local spectateTarget = nil
local ADMIN_UI_NAME = "admin"
local frozenByAdmin = false
local blockedSpectateControls = {
    "forwards", "backwards", "left", "right",
    "jump", "sprint", "crouch", "walk",
    "enter_exit", "enter_passenger",
    "fire", "aim_weapon", "next_weapon", "previous_weapon",
    "vehicle_fire", "vehicle_secondary_fire",
    "accelerate", "brake_reverse", "vehicle_left", "vehicle_right",
    "steer_forward", "steer_back", "handbrake"
}
local blockedFreezeControls = {
    "forwards", "backwards", "left", "right",
    "jump", "sprint", "walk", "crouch",
    "fire", "aim_weapon", "next_weapon", "previous_weapon",
    "enter_exit", "enter_passenger",
    "vehicle_fire", "vehicle_secondary_fire",
    "accelerate", "brake_reverse", "vehicle_left", "vehicle_right",
    "steer_forward", "steer_back", "handbrake",
    "vehicle_look_left", "vehicle_look_right", "horn"
}

local function s(value) return DXUtils.s(value) end

local function inBox(x, y, box)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

local function activeModalInput()
    if not AdminPanel.modal then return nil end
    if DXInput.active == AdminPanel.modal.input then return AdminPanel.modal.input end
    if AdminPanel.modal.durationInput and DXInput.active == AdminPanel.modal.durationInput then return AdminPanel.modal.durationInput end
    if AdminPanel.modal.reasonInput and DXInput.active == AdminPanel.modal.reasonInput then return AdminPanel.modal.reasonInput end
    return nil
end

local function setFreezeControls(state)
    frozenByAdmin = state == true
    for _, control in ipairs(blockedFreezeControls) do
        toggleControl(control, not frozenByAdmin)
        setPedControlState(localPlayer, control, false)
    end
end

local function requestPanel()
    if AuthUI and AuthUI.visible then return end
    if AdminPanel.visible then
        AdminPanel.close()
    else
        if RPUIManager and not RPUIManager.canOpen(ADMIN_UI_NAME) then return end
        triggerServerEvent("admin:requestPanel", localPlayer)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    AdminPanel.search = DXInput:new("Поиск игрока по ID или нику...", false, 32)
    if getElementData(localPlayer, "admin:frozen") then setFreezeControls(true) end
end)

addEvent("admin:openPanel", true)
addEventHandler("admin:openPanel", resourceRoot, function(level, players, levelNames, allowedActions, adminTypeName)
    AdminPanel.open(level, players, levelNames, allowedActions, adminTypeName)
end)

addEvent("admin:players", true)
addEventHandler("admin:players", resourceRoot, function(players)
    AdminPanel.updatePlayers(players)
end)

addEvent("admin:accessDenied", true)
addEventHandler("admin:accessDenied", resourceRoot, function(message)
    showCoreNotification(message or "Недостаточно прав.", 239, 83, 80)
end)

addEvent("admin:freezeControls", true)
addEventHandler("admin:freezeControls", resourceRoot, function(state)
    setFreezeControls(state == true)
end)

addEvent("admin:spectate", true)
addEventHandler("admin:spectate", resourceRoot, function(target)
    if not isElement(target) then return end
    spectating = true
    spectateTarget = target
    setCameraTarget(target)
    for _, control in ipairs(blockedSpectateControls) do
        toggleControl(control, false)
        setPedControlState(localPlayer, control, false)
    end
    triggerServerEvent("admin:spectateHudTarget", localPlayer, target)
end)

local function stopSpectate()
    if not spectating then return end
    spectating = false
    spectateTarget = nil
    setCameraTarget(localPlayer)
    for _, control in ipairs(blockedSpectateControls) do
        setPedControlState(localPlayer, control, false)
        toggleControl(control, true)
    end
    triggerServerEvent("admin:spectateHudTarget", localPlayer, false)
end

addEventHandler("onClientKey", root, function(button, press)
    if frozenByAdmin then
        for _, control in ipairs(blockedFreezeControls) do
            setPedControlState(localPlayer, control, false)
        end
    end

    if press and string.lower(button) == string.lower(AdminConfig.openKey) then
        cancelEvent()
        requestPanel()
        return
    end

    if spectating and press and button == "backspace" then
        cancelEvent()
        stopSpectate()
        return
    end

    if not AdminPanel.visible then return end
    if DXInput.active and DXInput.active:isSystemShortcutKey(button) then return end

    if press and button == "escape" then
        cancelEvent()
        if AdminPanel.modal then
            AdminPanel.modal = nil
            AdminPanel.search:blur()
        else
            AdminPanel.close()
        end
        return
    end

    if press and button == "enter" and AdminPanel.modal then
        cancelEvent()
        AdminPanel.submitModal()
        return
    end

    if press and button == "mouse_wheel_up" then
        cancelEvent()
        AdminPanel.scroll = math.max(0, AdminPanel.scroll - 1)
        return
    elseif press and button == "mouse_wheel_down" then
        cancelEvent()
        AdminPanel.scroll = AdminPanel.scroll + 1
        return
    end

    local input = activeModalInput() or (DXInput.active == AdminPanel.search and AdminPanel.search)
    if input then
        local handled = input:key(button, press)
        if handled then cancelEvent() end
    end
end)

addEventHandler("onClientRender", root, function()
    if not frozenByAdmin then return end
    for _, control in ipairs(blockedFreezeControls) do
        setPedControlState(localPlayer, control, false)
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if not AdminPanel.visible then return end
    local input = activeModalInput() or (DXInput.active == AdminPanel.search and AdminPanel.search)
    if input then input:char(char) end
end)

addEventHandler("onClientPaste", root, function(text)
    if not AdminPanel.visible then return end
    local input = activeModalInput() or (DXInput.active == AdminPanel.search and AdminPanel.search)
    if input then input:paste(text) end
end)

addEventHandler("onClientClick", root, function(button, state, x, y)
    if not AdminPanel.visible or button ~= "left" or state ~= "down" then return end

    local boxes = AdminPanel.hitboxes
    if AdminPanel.modal then
        local mx, my, w = AdminPanel.getModalLayout()
        AdminPanel.modal.input:click(x, y, mx + s(28), my + s(64), w - s(56), s(46))
        if AdminPanel.modal.durationInput then
            local durationW = AdminPanel.modal.action == "ban" and s(190) or w - s(56)
            AdminPanel.modal.durationInput:click(x, y, mx + s(28), my + s(120), durationW, s(46))
        end
        if AdminPanel.modal.reasonInput then
            AdminPanel.modal.reasonInput:click(x, y, mx + s(28), my + s(120), w - s(56), s(46))
        end
        if inBox(x, y, boxes.modalUnit) then AdminPanel.nextBanUnit(); return end
        if inBox(x, y, boxes.modalOk) then AdminPanel.submitModal() end
        if inBox(x, y, boxes.modalCancel) then AdminPanel.modal = nil; AdminPanel.search:blur() end
        return
    end

    if inBox(x, y, boxes.close) then AdminPanel.close(); return end

    local sw, sh = guiGetScreenSize()
    local w, h = s(1080), s(650)
    local px, py = math.floor((sw - w) / 2 + 0.5), math.floor((sh - h) / 2 + 0.5)
    AdminPanel.search:click(x, y, px + s(44), py + s(124), s(268), s(23))

    for key, box in pairs(boxes) do
        if key:find("^player:") and inBox(x, y, box) then
            AdminPanel.selectedId = box.id
            return
        end
        if key:find("^action:") and inBox(x, y, box) then
            AdminPanel.runAction(box.action)
            return
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if AdminPanel.visible then
        if RPUIManager then RPUIManager.release(ADMIN_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
    end
    if spectating then stopSpectate() end
    if frozenByAdmin then setFreezeControls(false) end
end)

addEventHandler("onClientElementDestroy", root, function()
    if source == spectateTarget then stopSpectate() end
end)

addEventHandler("onClientPlayerQuit", root, function()
    if source == spectateTarget then stopSpectate() end
end)
