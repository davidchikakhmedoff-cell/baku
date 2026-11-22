root,resourceRoot={},{}
local core,outsider={},{}
local p={id=1}
local registered,handlers={},{}
function addCommandHandler(name,fn) registered[name]=fn;return true end
function addEvent() end
function addEventHandler(event,element,fn) handlers[event]=fn end
function getResourceFromName(name) return name=='rp_core' and core or nil end
function executeCommandHandler() error('hosting ACL denies native dispatch') end
function getTickCount() return 1000 end
dofile('resources/rp_fraction/server/commands.lua')
Fraction={cooldowns={}}
local F=Fraction
FractionConfig={cooldown={}}
F.account=function(player) return player==p and 1 end
F.notify=function(player,msg) player.notice=msg end
F.keysMenu=function() p.refreshed=true end
F.takeVehicleKeys=function(player,slot) assert(slot==7);player.issued=(player.issued or 0)+1 end
local file=assert(io.open('resources/rp_fraction/server/main.lua'));local code=file:read('*a');file:close()
local throttle=assert(code:match('(function F.throttle.-\nend)'))
assert(loadstring('local F=Fraction; '..throttle))()
dofile('resources/rp_fraction/server/members.lua')
local callback=handlers['fraction:action'];client,source=p,resourceRoot
callback('keysRefresh',{})
callback('keysTake',{slot=7})
assert(p.refreshed and p.issued==1,'refresh and take in same network burst do not discard key request')
callback('keysTake',{slot=7})
assert(p.issued==1 and p.notice,'duplicate request is limited with feedback')
for i=1,100 do callback('unknown'..i,{}) end
local cooldowns=0;for _ in pairs(F.cooldowns[p]) do cooldowns=cooldowns+1 end
assert(cooldowns==2,'unknown actions cannot allocate unlimited cooldown entries')
local calls=0
for command in pairs(FractionCommands.handlers) do
 FractionCommands.handlers[command]=function(actor,name,...) assert(actor==p and name==command);calls=calls+1 end
 sourceResource=core;assert(executeFractionCommand(p,command,'15 2 sample text'))
end
assert(calls==8,'all membership commands route directly despite denied executeCommandHandler')
sourceResource=outsider;assert(not executeFractionCommand(p,'members',''))
sourceResource=core;assert(not executeFractionCommand(p,'shutdown',''))
print('Hosting: same-burst key actions, explicit cooldown feedback, direct command dispatch and trusted-route restrictions passed')
