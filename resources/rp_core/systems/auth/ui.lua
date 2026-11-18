-- DX authorization panel. The only account identifier is the player's RP name.
AuthUI = {
    visible = false,
    mode = "login",
    alpha = 0,
    targetAlpha = 0,
    remember = false,
    gender = "male",
    notices = {},
    helpVisible = false,
    helpAlpha = 0,
    helpTargetAlpha = 0,
    hitboxes = {}
}

local AUTH_UI_NAME = "auth"

local function validRPName(name)
    return type(name) == "string" and name:match("^[A-Z][a-z]+_[A-Z][a-z]+$") ~= nil
end

local function addBox(boxes, key, x, y, w, h)
    boxes[key] = { x = x, y = y, w = w, h = h }
    return y + h
end

function AuthUI.init()
    AuthUI.rpName = DXInput:new("Имя персонажа: John_Smith", false, AuthConfig.input.rpNameMax)
    AuthUI.password = DXInput:new("Пароль", true, AuthConfig.input.passwordMax)
    AuthUI.repeatPassword = DXInput:new("Повторите пароль", true, AuthConfig.input.passwordMax)
    AuthUI.submit = DXButton:new("Войти", AuthUI.submitForm)

    local saved = loadRememberedRPName()
    if saved then
        AuthUI.rpName:setText(saved)
        AuthUI.remember = true
    end
end

function loadRememberedRPName()
    if not fileExists("remember.xml") then return false end
    local file = xmlLoadFile("remember.xml")
    if not file then return false end
    local value = xmlNodeGetAttribute(file, "rpName") or xmlNodeGetAttribute(file, "login")
    xmlUnloadFile(file)
    return value and value:gsub(" ", "_")
end

function saveRememberedRPName(rpName)
    if fileExists("remember.xml") then fileDelete("remember.xml") end
    if not rpName then return end

    local file = xmlCreateFile("remember.xml", "auth")
    xmlNodeSetAttribute(file, "rpName", rpName)
    xmlSaveFile(file)
    xmlUnloadFile(file)
end

local function buildLayout()
    local screenW, screenH = guiGetScreenSize()
    local s = DXUtils.s
    local width = s(AuthConfig.design.panelWidth)
    local extra = AuthUI.mode == "register" and 198 or 0
    local height = s(AuthConfig.design.panelHeight + extra)
    local x, y = (screenW - width) / 2, (screenH - height) / 2
    local pad = s(44)
    local inputW, inputH = width - pad * 2, s(50)
    local gap = s(14)
    local cy = y + s(156)

    local boxes = {
        panel = { x = x, y = y, w = width, h = height, pad = pad }
    }

    cy = addBox(boxes, "rpName", x + pad, cy, inputW, inputH) + gap
    cy = addBox(boxes, "password", x + pad, cy, inputW, inputH) + gap

    if AuthUI.mode == "register" then
        cy = addBox(boxes, "repeatPassword", x + pad, cy, inputW, inputH) + gap
        cy = addBox(boxes, "rpHelp", x + pad, cy, inputW, s(28)) + gap
        local genderGap = s(12)
        local genderW = (inputW - genderGap) / 2
        boxes.genderMale = { x = x + pad, y = cy, w = genderW, h = s(42) }
        boxes.genderFemale = { x = x + pad + genderW + genderGap, y = cy, w = genderW, h = s(42) }
        cy = cy + s(42) + s(18)
    end

    boxes.remember = { x = x + pad, y = cy, w = s(230), h = s(24), box = s(17) }
    cy = cy + s(24) + s(20)
    cy = addBox(boxes, "submit", x + pad, cy, inputW, s(48))
    cy = cy + s(20)
    boxes.switchLine = { x = x + pad, y = cy - s(8), w = inputW, h = s(40) }
    boxes.switch = { x = x + pad, y = cy - s(8), w = 0, h = s(40) }

    return boxes
end

function AuthUI.show()
    if AuthUI.visible then return end
    if not AuthUI.rpName then AuthUI.init() end
    if RPUIManager and not RPUIManager.acquire(AUTH_UI_NAME, { cursor = true, inputMode = "no_binds_when_editing" }) then return end

    AuthUI.visible = true
    AuthUI.alpha = 0
    AuthUI.targetAlpha = 255
    showChat(false)
    DXUtils.setRadarVisible(false)
    toggleAllControls(false, true, false)

    addEventHandler("onClientRender", root, AuthUI.render)
    addEventHandler("onClientClick", root, AuthUI.click)
    addEventHandler("onClientKey", root, AuthUI.key)
    addEventHandler("onClientCharacter", root, AuthUI.char)
    addEventHandler("onClientPaste", root, AuthUI.paste)
end

local function removeInputHandlers()
    removeEventHandler("onClientClick", root, AuthUI.click)
    removeEventHandler("onClientKey", root, AuthUI.key)
    removeEventHandler("onClientCharacter", root, AuthUI.char)
    removeEventHandler("onClientPaste", root, AuthUI.paste)
end

function AuthUI.hide(immediate, keepControlsDisabled)
    -- Enter submits without a mouse click outside the password field. Hidden
    -- auth input must not continue blocking every other resource's hotkeys.
    if DXInput and DXInput.active and (DXInput.active == AuthUI.rpName
        or DXInput.active == AuthUI.password or DXInput.active == AuthUI.repeatPassword) then
        DXInput.active:blur()
    end
    AuthUI.targetAlpha = 0
    AuthUI.helpTargetAlpha = 0
    AuthUI.submit.enabled = false
    if RPUIManager then RPUIManager.release(AUTH_UI_NAME) else showCursor(false); guiSetInputMode("allow_binds") end
    showChat(false)
    if not keepControlsDisabled then
        toggleAllControls(true)
    end
    removeInputHandlers()

    if immediate then
        AuthUI.alpha = 0
        AuthUI.visible = false
        AuthUI.helpVisible = false
        AuthUI.helpAlpha = 0
        AuthUI.hitboxes = {}
        removeEventHandler("onClientRender", root, AuthUI.render)
    end
end

function AuthUI.setNotice(text, good)
    if not text then
        AuthUI.notices = {}
        return
    end

    AuthUI.notices[#AuthUI.notices + 1] = {
        text = text,
        good = good,
        tick = getTickCount(),
        alpha = 0
    }
end

function AuthUI.switchMode(mode)
    AuthUI.mode = mode
    AuthUI.submit.text = mode == "login" and "Войти" or "Создать аккаунт"
    AuthUI.setNotice(nil)
end

local function drawGenderButton(box, gender, title, alpha)
    local s = DXUtils.s
    local selected = AuthUI.gender == gender
    local hovered = DXUtils.inBox(box.x, box.y, box.w, box.h)
    local bg = AuthConfig.colors.panel
    local primary = AuthConfig.colors.primary
    local lift = hovered and 10 or 0

    DXUtils.roundedRect(box.x, box.y, box.w, box.h, s(8), tocolor(bg[1] + lift, bg[2] + lift, bg[3] + lift, (selected and 164 or 112) * alpha / 255))
    dxDrawRectangle(box.x + s(12), box.y + box.h - s(2), box.w - s(24), s(1), tocolor(primary[1], primary[2], primary[3], (selected and 210 or 44) * alpha / 255))
    dxDrawText(selected and "●" or "○", box.x + s(12), box.y, box.x + s(36), box.y + box.h, tocolor(primary[1], primary[2], primary[3], alpha), 0.92, "default-bold", "center", "center")
    dxDrawText(title, box.x + s(40), box.y, box.x + box.w - s(12), box.y + box.h, tocolor(235, 240, 245, alpha), 0.94, "default-bold", "left", "center", true)
end

local function drawHelpWindow(screenW, screenH, baseAlpha)
    AuthUI.helpAlpha = DXUtils.lerp(AuthUI.helpAlpha, AuthUI.helpTargetAlpha, 0.12)
    local alpha = math.min(baseAlpha, AuthUI.helpAlpha)
    if alpha < 1 and AuthUI.helpTargetAlpha == 0 then
        AuthUI.helpVisible = false
        return
    end

    local s = DXUtils.s
    local hw, hh = s(720), s(430)
    local hx, hy = (screenW - hw) / 2, (screenH - hh) / 2
    local primary = AuthConfig.colors.primary

    dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 90 * (alpha / 255)))
    DXUtils.shadow(hx, hy, hw, hh, s(18), 105 * alpha / 255)
    DXUtils.roundedRect(hx, hy, hw, hh, s(18), DXUtils.color(AuthConfig.colors.window, alpha))
    dxDrawRectangle(hx + s(34), hy + s(76), hw - s(68), 1, tocolor(primary[1], primary[2], primary[3], 115 * alpha / 255))

    dxDrawText("Правила RP ника", hx, hy + s(24), hx + hw, hy + s(58), tocolor(255, 255, 255, alpha), 1.35, "default-bold", "center", "center")
    dxDrawText("Имя персонажа состоит из имени и фамилии на латинице, разделенных одним символом _. Первая буква каждого слова заглавная, остальные строчные.", hx + s(48), hy + s(88), hx + hw - s(48), hy + s(132), DXUtils.color(AuthConfig.colors.text, alpha), 1, "default", "center", "top", true, true)

    local colW = (hw - s(120)) / 2
    local leftX, rightX = hx + s(46), hx + s(74) + colW
    local topY = hy + s(154)
    DXUtils.roundedRect(leftX, topY, colW, s(180), s(12), tocolor(39, 56, 44, 210 * alpha / 255))
    DXUtils.roundedRect(rightX, topY, colW, s(180), s(12), tocolor(61, 39, 39, 210 * alpha / 255))
    dxDrawText("Правильно", leftX + s(20), topY + s(16), leftX + colW, topY + s(44), tocolor(120, 230, 150, alpha), 1.05, "default-bold", "left", "center")
    dxDrawText("Неправильно", rightX + s(20), topY + s(16), rightX + colW, topY + s(44), tocolor(255, 120, 120, alpha), 1.05, "default-bold", "left", "center")
    dxDrawText("John_Smith\nDavid_Johnson\nMichael_Brown", leftX + s(20), topY + s(58), leftX + colW - s(20), topY + s(160), tocolor(235, 240, 235, alpha), 1, "default-bold", "left", "top", true)
    dxDrawText("John Smith\njohn_smith\nJOHN_SMITH\nJohnSmith\nJohn__Smith", rightX + s(20), topY + s(58), rightX + colW - s(20), topY + s(166), tocolor(240, 225, 225, alpha), 1, "default-bold", "left", "top", true)

    AuthUI.hitboxes.helpClose = { x = hx + (hw - s(170)) / 2, y = hy + hh - s(64), w = s(170), h = s(42) }
    DXUtils.roundedRect(AuthUI.hitboxes.helpClose.x, AuthUI.hitboxes.helpClose.y, AuthUI.hitboxes.helpClose.w, AuthUI.hitboxes.helpClose.h, s(12), DXUtils.color(AuthConfig.colors.primary, alpha))
    dxDrawText("Понятно", AuthUI.hitboxes.helpClose.x, AuthUI.hitboxes.helpClose.y, AuthUI.hitboxes.helpClose.x + AuthUI.hitboxes.helpClose.w, AuthUI.hitboxes.helpClose.y + AuthUI.hitboxes.helpClose.h, tocolor(255,255,255,alpha), 1, "default-bold", "center", "center")
end

local function drawNotices(panel, baseAlpha)
    local s = DXUtils.s
    local nowTick = getTickCount()
    local nextY = panel.y + panel.h + s(14)
    local i = 1

    while i <= #AuthUI.notices do
        local notice = AuthUI.notices[i]
        local age = nowTick - notice.tick
        local target = age <= 5000 and 255 or 0
        notice.alpha = DXUtils.lerp(notice.alpha, target, 0.12)

        if age > 5000 and notice.alpha < 2 then
            table.remove(AuthUI.notices, i)
        else
            local alpha = math.min(baseAlpha, notice.alpha)
            local accent = notice.good and AuthConfig.colors.success or AuthConfig.colors.error
            
            -- Calculate box dimensions
            local padding = s(15)
            local boxX = panel.x + panel.pad
            local boxW = panel.w - panel.pad * 2
            local textX = boxX + padding + s(8)
            local textMaxWidth = boxW - padding * 2 - s(8)
            local textY = nextY + padding
            
            -- Estimate line count by calculating text width
            local lineHeight = s(19)
            local estimatedLineCount = 1
            local textWidth = dxGetTextWidth(notice.text, 0.98, "default-bold")
            if textWidth > textMaxWidth then
                estimatedLineCount = math.ceil(textWidth / textMaxWidth)
            end
            
            local h = math.max(s(48), (lineHeight * estimatedLineCount) + padding * 2)
            h = math.min(h, s(112))
            
            DXUtils.roundedRect(boxX, nextY, boxW, h, s(9), tocolor(18, 22, 27, 232 * alpha / 255))
            dxDrawRectangle(boxX, nextY + s(10), s(2), h - s(20), tocolor(accent[1], accent[2], accent[3], 220 * alpha / 255))
            dxDrawText(notice.text, textX, textY, textX + textMaxWidth, nextY + h, tocolor(248, 250, 252, alpha), 0.98, "default-bold", "left", "top", false, true)
            
            nextY = nextY + h + s(10)
            i = i + 1
        end
    end
end

function AuthUI.validate()
    local rpName = AuthUI.rpName:getText()
    local password = AuthUI.password:getText()
    local repeatPassword = AuthUI.repeatPassword:getText()

    if not validRPName(rpName) then
        return false, "Имя персонажа должно быть в формате Name_Surname."
    end
    if #password < AuthConfig.input.passwordMin or #password > AuthConfig.input.passwordMax then
        return false, "Пароль должен быть от 6 до 32 символов."
    end
    if AuthUI.mode == "register" and password ~= repeatPassword then
        return false, "Пароли не совпадают."
    end
    return true
end

function AuthUI.submitForm()
    local ok, err = AuthUI.validate()
    if not ok then
        AuthUI.setNotice(err, false)
        return
    end

    AuthUI.submit.enabled = false
    if AuthUI.mode == "login" then
        triggerServerEvent("auth:login", localPlayer, AuthUI.rpName:getText(), AuthUI.password:getText(), AuthUI.remember)
    else
        triggerServerEvent("auth:register", localPlayer, AuthUI.rpName:getText(), AuthUI.password:getText(), AuthUI.repeatPassword:getText(), AuthUI.remember, AuthUI.gender)
    end
end

function AuthUI.render()
    AuthUI.alpha = DXUtils.lerp(AuthUI.alpha, AuthUI.targetAlpha, 0.08)
    local alpha = AuthUI.alpha

    if alpha < 1 and AuthUI.targetAlpha == 0 then
        AuthUI.visible = false
        removeEventHandler("onClientRender", root, AuthUI.render)
        return
    end

    local screenW, screenH = guiGetScreenSize()
    local s = DXUtils.s
    AuthUI.hitboxes = buildLayout()
    local boxes = AuthUI.hitboxes
    local panel = boxes.panel

    dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, AuthConfig.design.overlayAlpha * (alpha / 255)))
    DXUtils.shadow(panel.x, panel.y, panel.w, panel.h, s(18), 85 * alpha / 255)
    DXUtils.roundedRect(panel.x, panel.y, panel.w, panel.h, s(18), DXUtils.color(AuthConfig.colors.window, alpha))

    local cy = panel.y + s(34)
    dxDrawText(AuthUI.mode == "login" and "Добро пожаловать" or "Создание персонажа", panel.x, cy, panel.x + panel.w, cy + s(34), tocolor(255, 255, 255, alpha), 1.35, "default-bold", "center", "center")
    cy = cy + s(36)
    dxDrawText(AuthUI.mode == "login" and "Войдите по имени персонажа" or "Заполните данные персонажа", panel.x, cy, panel.x + panel.w, cy + s(24), DXUtils.color(AuthConfig.colors.text, alpha), 1, "default", "center", "center")

    AuthUI.rpName:draw(boxes.rpName.x, boxes.rpName.y, boxes.rpName.w, boxes.rpName.h, alpha, "RP")
    AuthUI.password:draw(boxes.password.x, boxes.password.y, boxes.password.w, boxes.password.h, alpha, "PW")
    if AuthUI.mode == "register" then
        AuthUI.repeatPassword:draw(boxes.repeatPassword.x, boxes.repeatPassword.y, boxes.repeatPassword.w, boxes.repeatPassword.h, alpha, "OK")
        local helpColor = DXUtils.inBox(boxes.rpHelp.x, boxes.rpHelp.y, boxes.rpHelp.w, boxes.rpHelp.h) and tocolor(120, 215, 255, alpha) or DXUtils.color(AuthConfig.colors.primary, alpha)
        dxDrawText("Каким должен быть RP-ник?", boxes.rpHelp.x, boxes.rpHelp.y, boxes.rpHelp.x + boxes.rpHelp.w, boxes.rpHelp.y + boxes.rpHelp.h, helpColor, 1, "default-bold", "center", "center")
        drawGenderButton(boxes.genderMale, "male", "Мужской", alpha)
        drawGenderButton(boxes.genderFemale, "female", "Женский", alpha)
    end

    local remember = boxes.remember
    DXUtils.roundedRect(remember.x, remember.y, remember.box, remember.box, s(4), AuthUI.remember and DXUtils.color(AuthConfig.colors.primary, alpha) or DXUtils.color(AuthConfig.colors.panel, alpha))
    if AuthUI.remember then
        dxDrawText("✓", remember.x, remember.y - 1, remember.x + remember.box, remember.y + remember.box, tocolor(255, 255, 255, alpha), 1, "default-bold", "center", "center")
    end
    dxDrawText("Запомнить меня", remember.x + s(28), remember.y - s(2), panel.x + panel.w, remember.y + remember.box, DXUtils.color(AuthConfig.colors.text, alpha), 1, "default", "left", "center")

    AuthUI.submit:draw(boxes.submit.x, boxes.submit.y, boxes.submit.w, boxes.submit.h, alpha)

    local lead = AuthUI.mode == "login" and "Нет аккаунта?" or "Уже есть аккаунт?"
    local link = AuthUI.mode == "login" and "Регистрация" or "Войти"
    local gap = s(8)
    local leadWidth = dxGetTextWidth(lead, 1, "default")
    local linkWidth = dxGetTextWidth(link, 1, "default-bold")
    local totalWidth = leadWidth + gap + linkWidth
    local lineX = panel.x + (panel.w - totalWidth) / 2
    local lineY = boxes.switchLine.y + s(8)
    boxes.switch = { x = lineX + leadWidth + gap, y = boxes.switchLine.y, w = linkWidth, h = boxes.switchLine.h }
    local hoveredLink = DXUtils.inBox(boxes.switch.x, boxes.switch.y, boxes.switch.w, boxes.switch.h)
    local linkColor = hoveredLink and tocolor(120, 215, 255, alpha) or DXUtils.color(AuthConfig.colors.primary, alpha)
    dxDrawText(lead, lineX, lineY, lineX + leadWidth, lineY + s(24), DXUtils.color(AuthConfig.colors.muted, alpha), 1, "default", "left", "center")
    dxDrawText(link, boxes.switch.x, lineY, boxes.switch.x + linkWidth, lineY + s(24), linkColor, 1, "default-bold", "left", "center")

    drawNotices(panel, alpha)

    if AuthUI.helpVisible or AuthUI.helpAlpha > 1 then
        drawHelpWindow(screenW, screenH, alpha)
    end
end

local function inBox(x, y, box)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

function AuthUI.click(button, state, x, y)
    if button ~= "left" then return end
    local boxes = AuthUI.hitboxes
    if not boxes.panel then return end

    if AuthUI.helpVisible then
        if state == "up" and inBox(x, y, boxes.helpClose) then
            AuthUI.helpTargetAlpha = 0
        end
        return
    end

    if state == "down" then
        AuthUI.rpName:click(x, y, boxes.rpName.x, boxes.rpName.y, boxes.rpName.w, boxes.rpName.h)
        AuthUI.password:click(x, y, boxes.password.x, boxes.password.y, boxes.password.w, boxes.password.h)
        if AuthUI.mode == "register" then
            AuthUI.repeatPassword:click(x, y, boxes.repeatPassword.x, boxes.repeatPassword.y, boxes.repeatPassword.w, boxes.repeatPassword.h)
            if inBox(x, y, boxes.rpHelp) then
                AuthUI.helpVisible = true
                AuthUI.helpTargetAlpha = 255
            elseif inBox(x, y, boxes.genderMale) then
                AuthUI.gender = "male"
            elseif inBox(x, y, boxes.genderFemale) then
                AuthUI.gender = "female"
            end
        end
        if inBox(x, y, boxes.remember) then
            AuthUI.remember = not AuthUI.remember
        end
    end

    AuthUI.submit:mouse(button, state, x, y, boxes.submit.x, boxes.submit.y, boxes.submit.w, boxes.submit.h)
    if state == "up" and inBox(x, y, boxes.switch) then
        AuthUI.switchMode(AuthUI.mode == "login" and "register" or "login")
    end
end

function AuthUI.key(button, press)
    if AuthUI.helpVisible then return end
    if DXInput.active and DXInput.active:isSystemShortcutKey(button) then return end
    if press and (button == "enter" or button == "num_enter") and DXInput.active and AuthUI.submit.enabled then
        cancelEvent()
        AuthUI.submitForm()
        return
    end
    if DXInput.active then
        local handled = DXInput.active:key(button, press)
        if handled then cancelEvent() end
    end
end

function AuthUI.char(char)
    if AuthUI.helpVisible then return end
    if DXInput.active then DXInput.active:char(char) end
end

function AuthUI.paste(text)
    if AuthUI.helpVisible or not DXInput.active or not text then return end
    DXInput.active:paste(text)
end
