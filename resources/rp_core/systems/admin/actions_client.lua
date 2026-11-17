AdminActionDefs = {
    { id = "teleportTo", title = "К себе", label = "ТП к игроку", mode = "instant" },
    { id = "teleportHere", title = "Сюда", label = "ТП игрока", mode = "instant" },
    { id = "teleportPlayerToPlayer", title = "ТП к ID", label = "Игрок к игроку", mode = "destination" },
    { id = "spectate", title = "Наблюдать", label = "Spectate", mode = "instant" },
    { id = "spawn", title = "Спавн", label = "Заспавнить", mode = "instant" },
    { id = "kill", title = "Убить", label = "Kill", mode = "instant" },
    { id = "health", title = "HP", label = "Здоровье", mode = "value", placeholder = "Здоровье 1-100", default = "100" },
    { id = "armor", title = "Броня", label = "Броня", mode = "value", placeholder = "Броня 0-100", default = "100" },
    { id = "skin", title = "Скин", label = "Сменить скин", mode = "value", placeholder = "ID скина 0-312", default = "0" },
    { id = "money", title = "Деньги", label = "Установить", mode = "value", placeholder = "Сумма", default = "0" },
    { id = "level", title = "Уровень", label = "Изменить", mode = "value", placeholder = "Уровень", default = "1" },
    { id = "expHour", title = "EXP", label = "Выдать", mode = "value", placeholder = "Количество EXP", default = "1" },
    { id = "vehicle", title = "Машина", label = "Выдать по ID", mode = "value", placeholder = "ID машины 400-611", default = "411" },
    { id = "vehicleHealth", title = "Восстановить", label = "Восстановить", mode = "instant" },
    { id = "weapon", title = "Оружие", label = "Выдать по ID", mode = "value", placeholder = "ID оружия 0-46", default = "31" },
    { id = "mute", title = "Мут", label = "Замутить", mode = "punish", placeholder = "Причина мута", duration = "3600" },
    { id = "unmute", title = "Размут", label = "Снять мут", mode = "instant" },
    { id = "freeze", title = "Freeze", label = "Заморозить", mode = "instant" },
    { id = "unfreeze", title = "Unfreeze", label = "Разморозить", mode = "instant" },
    { id = "kick", title = "Кик", label = "Отключить", mode = "reason", placeholder = "Причина кика" },
    { id = "ban", title = "Бан", label = "Заблокировать", mode = "ban", placeholder = "Причина бана", duration = "1", unit = "days" },
    { id = "unban", title = "Разбан", label = "Ник или Serial", mode = "unban", placeholder = "RP-ник или Serial" }
}

function AdminGetActionDef(actionId)
    for _, action in ipairs(AdminActionDefs) do
        if action.id == actionId then return action end
    end
    return nil
end
