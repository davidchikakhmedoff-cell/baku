FractionCommands = { handlers = {} }
local nativeAddCommandHandler = addCommandHandler
function FractionCommands.add(name, handler)
    local ok = nativeAddCommandHandler(name, handler)
    if ok == false then return false end
    FractionCommands.handlers[name:lower()] = handler
    return true
end
function FractionCommands.execute(player, command, args)
    local handler = FractionCommands.handlers[command]
    if not handler then return false end
    local words = {}
    for word in tostring(args or ''):gmatch('%S+') do words[#words + 1] = word end
    handler(player, command, unpack(words))
    return true
end
