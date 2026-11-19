-- Real custom chat -> bridge -> real membership/duty/position checks -> jail.
-- Only MTA primitives, account exports and SQLite I/O are represented here.
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local core,fraction={},{}
local p={id=87,dynamic=15,['auth:loggedIn']=true,['rp:name']='Self_Test'}
local row,replies,clock={}, {},10000
function isElement(e) return e==p end
function getElementType() return 'player' end
function getElementData(e,key) return e[key] end
function setElementData(e,key,value) e[key]=value end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function setElementPosition(e,x,y,z) e.x,e.y,e.z=x,y,z end
function setElementInterior(e,n) e.interior=n end
function setElementDimension(e,n) e.dimension=n end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function getPlayerWantedLevel(e) return e.stars end
function setPlayerWantedLevel(e,n) e.stars=n end
function isPedDead(e) return e.dead or false end
function isPedInVehicle() return false end
function getPedOccupiedVehicle() return nil end
function getElementModel(e) return e.model end
function setElementModel(e,n) e.model=n end
function setPedRotation(e,n) e.rotation=n end
function getPlayerName() return 'Self_Test' end
function setCameraTarget() end
function takeAllWeapons() end
function fromJSON() return {} end
function getTickCount() return clock end
function getRealTime() return {timestamp=1000,hour=12,minute=0} end
function getElementsByType() return {p} end
function addEvent() end
function addEventHandler() end
function addCommandHandler() end
function triggerClientEvent() end
function getResourceFromName(name) return name=='rp_core' and core or fraction end
function getResourceState() return 'running' end
function getResourceExportedFunctions() return {'executeFractionCommand'} end
function call(res,name,...)
 local old=sourceResource;sourceResource=core
 local result=executeFractionCommand(...);sourceResource=old;return result
end
function executeCommandHandler() error('arrest must reach its own handler directly, even when native dispatch fails') end
exports={rp_core={
 getAuthPlayerId=function(_,e) return e.id end,
 getPlayerDynamicID=function(_,e) return e.dynamic end,
 getPlayerByDynamicID=function() return nil end, -- emulate stale native ID lookup
 sendCoreNotification=function(_,e,text) replies[#replies+1]=text end,
 sendCoreChatMessage=function(_,e,text) replies[#replies+1]=text end
}}
FractionDB={available=function() return true end,
 one=function(sql)
  if sql:find('fraction_state',1,true) then
   return {account_id=87,wanted=row.wanted,jail_remaining=row.remaining,jail_reason=''}
  end
 end,
 exec=function(sql,a,b,c,d)
  if sql:find('SET jail_remaining=?,jail_reason',1,true) then row.remaining=a
  elseif sql:find('SET wanted=?',1,true) then row.wanted=a end
  return true
 end
}
dofile('resources/rp_fraction/server/main.lua')
dofile('resources/rp_fraction/server/members.lua')
dofile('resources/rp_fraction/server/police.lua')
dofile('resources/rp_core/systems/chat/config.lua')
dofile('resources/rp_core/systems/chat/server.lua')
local F=Fraction
F.ready=true;F.revokeDriver=function() end
local function prepare(dimension,dx,z,working,stars)
 clock=clock+6000;replies={};row={wanted=stars or 1,remaining=0}
 p.x,p.y,p.z=264.28+(dx or 0),80.64,z or 1001.03
 p.interior,p.dimension,p.model,p.stars=6,dimension,280,0
 F.sessions[p]={account=87,duty=working~=false};F.justice={};F.cooldowns={}
 F.members[87]={account_id=87,faction_id=2,rank=10,duty=1,civilian_skin=7,civilian_weapons='[]',gear_issued=0}
end
for _,dimension in ipairs({0,Fractions[2].dimension,FractionConfig.dimensionBase+100}) do
 prepare(dimension,4)
 RPChat.processMessage(p,'/arrest 15')
 assert(p.dimension==FractionConfig.dimensionBase+100 and row.remaining==300,'self arrest works four metres from actual prison in each supported world')
 assert(p.x==264.28 and p.y==80.64 and p.z==1001.03 and p.rotation==180,'exact requested prison appearance position and heading')
 assert(row.wanted==0 and p.stars==0,'arrest clears persistent and native wanted')
 assert(replies[#replies]:find('помещён',1,true),'successful command always replies in visible chat')
end
for _,test in ipairs({
 {Fractions[2].dimension,5.1,1001.03,true,1},
 {Fractions[2].dimension,0,1003.6,true,1},
 {20003,0,1001.03,true,1},
 {Fractions[2].dimension,0,1001.03,false,1},
 {Fractions[2].dimension,0,1001.03,true,0}
}) do
 prepare(unpack(test));RPChat.processMessage(p,'/arrest 15')
 assert(row.remaining==0 and #replies>0,'out of zone, wrong floor/world, off duty and zero wanted always give a reason')
end
prepare(Fractions[2].dimension);RPChat.processMessage(p,'/arrest 87')
assert(row.remaining==0 and replies[#replies]:find('не найден',1,true),'account ID cannot be confused with dynamic ID')
prepare(Fractions[2].dimension);RPChat.processMessage(p,'/arrest')
assert(row.remaining==0 and replies[#replies]:find('/arrest ID',1,true),'missing ID gets usage')
print('Arrest integration: real chat/permissions/geometry, direct dispatch, self ID, exact spawn and all refusal messages passed')
