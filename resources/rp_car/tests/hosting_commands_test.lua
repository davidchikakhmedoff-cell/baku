local file=assert(io.open('resources/rp_car/server.lua'));local code=file:read('*a');file:close()
local prefix=assert(code:match('^(.-)\nlocal recoverPlayerVehicleParking'))
local core,car={},{}
local player={logged=true};local calls=0
function getResourceFromName(name) return name=='rp_core' and core or car end
function isElement(p) return type(p)=='table' end
function getElementData(p,key) return key=='auth:loggedIn' and p.logged end
local native={}
function addCommandHandler(name,fn) native[name]=fn;return true end
function executeCommandHandler() error('host ACL denies this') end
local register=assert(loadstring(prefix..'\nreturn addCommandHandler'))()
for _,name in ipairs({'carinfo','carsave','cardel','eject'}) do
 register(name,function(p,command,id) assert(p==player and command==name and id=='42');calls=calls+1 end)
 sourceResource=core;assert(executeCarCommand(player,name,'42'))
end
assert(calls==4 and native.cardel,'console and custom chat share one registered handler')
sourceResource=car;assert(not executeCarCommand(player,'cardel','42'))
sourceResource=core;player.logged=false;assert(not executeCarCommand(player,'cardel','42'))
player.logged=true;assert(not executeCarCommand(player,'shutdown',''))
print('Hosting car commands: direct dispatch, shared console handlers, source/auth/allowlist checks passed')
