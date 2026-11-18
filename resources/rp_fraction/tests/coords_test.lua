local commands={}
function registerChatCommand(name,fn) commands[name]=fn end
dofile('resources/rp_core/systems/chat/commands.lua')
local player={};local payload
ChatConfig={colors={system={255,255,255}}}
RPChat={send=function(p,data) assert(p==player);payload=data end}
function getElementPosition() return 123.45678,-98.76543,1004.1797 end
function getElementRotation() return 0,0,270 end
function getElementInterior() return 3 end
function getElementDimension() return 20001 end
commands.coords(player)
assert(payload.text:find('x=123.4568',1,true) and payload.text:find('rotation=270.00',1,true))
assert(payload.text:find('interior=3, dimension=20001',1,true))
print('Coordinates: position, rotation, interior and dimension sent to requesting player')
