function setServerToner(player, veh, type, price)
    if getPlayerMoney(player) >= price then
        triggerClientEvent("setToner", getRootElement(), veh, type)
        setElementData(veh, "toner", type)
        exports.rp_core:sendCoreNotification(player, "Вы купили тонировку за " .. tostring(price) .. "$.", 102, 187, 106)
    else
        exports.rp_core:sendCoreNotification(player, "Недостаточно средств!", 239, 83, 80)
    end
end
addEvent("setServerToner", true)
addEventHandler("setServerToner", getRootElement(), setServerToner)


addEventHandler("onPlayerLogin", getRootElement(), function()
    for k, v in ipairs(getElementsByType("vehicle")) do
        if getElementData(v, "toner") then
            setTimer(triggerClientEvent, 1500, 1, source, "setToner", getRootElement(), v, getElementData(v, "toner"))
        end
    end
end)
