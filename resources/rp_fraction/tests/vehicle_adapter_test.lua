local fractionResource={};local p={rank=2,duty=true};local v={};local outsider={rank=1,duty=true}
root={};sourceResource=fractionResource
local handlers={}
function addEvent() end
function addEventHandler(name,element,fn) handlers[name]=fn end
local clock=0
function getTickCount() return clock end
function getElementSyncer() return p end
local settle,settleMs
local timers={}
function setTimer(fn,ms,count,...) settle=fn;settleMs=ms;timers[#timers+1]={fn=fn,ms=ms,args={...}} end
function setElementVelocity() end
function setElementAngularVelocity() end
function isElement(e) return e==p or e==v or e==outsider end
function getResourceFromName() return fractionResource end
function getResourceState() return 'running' end
function call(res,method,player,vehicle) return player.rank>=2 and player.duty end
function getPedOccupiedVehicle() return v end
function getPedOccupiedVehicleSeat() return 0 end
function getElementPosition() return 0,0,0 end
function getElementDimension() return 0 end
function getElementInterior() return 0 end
function getDistanceBetweenPoints3D() return 0 end
function getVehicleEngineState(e) return e.engine or false end
function setVehicleEngineState(e,value) e.engine=value end
function setElementFrozen(e,value) e.frozen=value end
function setElementData(e,key,value) e[key]=value end
function getElementData(e,key) return e[key] end
function setVehicleOverrideLights(e,value) e.lights=value end
function isVehicleLocked(e) return e.locked or false end
function setVehicleLocked(e,value) e.locked=value end
function getVehicleOccupant() return p end
function getVehicleType() return 'Automobile' end
function getVehicleModel() return 560 end
function getVehicleEngineState(e) return e.engine or false end
function getVehicleVelocity() return 0,0,0 end
function getElementVelocity() return 0,0,0 end
function isVehicleOnGround() return true end
local fuel=30
FuelSystem={attachExternal=function() end,detach=function() end,canStart=function() return fuel>0 end}
CarInteraction={ready=function() return true end}
CarConfig={lockServerDistance=25}
local file=assert(io.open('resources/rp_car/server.lua'));local code=file:read('*a');file:close()
local helper=assert(code:match('(local function flashVehicleLights.-)local function canControlVehicleEngine'))
assert(loadstring('local lightFlashTokens={}\nlocal lightFlashSequence=0\n'..helper))()
assert(loadfile('resources/rp_car/faction_adapter.lua'))()
assert(registerFactionVehicle(v,'fraction:2:1',30),'own faction resource registers service car')
local occupant=getVehicleOccupant;getVehicleOccupant=function() return nil end
assert(settleMs==1000);clock=1000;settle(v)
assert(not v.frozen and v['car:handbrake'] and v['car:parkingPending'],'handbrake after one second without freezing unloaded suspension')
source=v;client=outsider;handlers['car:parkingGrounded']();assert(not v.frozen,'non-syncer cannot finalize settling')
client=p;clock=999;handlers['car:parkingGrounded']();assert(not v.frozen,'settling cannot finalize before one second')
clock=1000;local ground=isVehicleOnGround;isVehicleOnGround=function() return false end
handlers['car:parkingGrounded']();assert(not v.frozen,'server rejects airborne grounding reports')
isVehicleOnGround=ground
v['car:parkingPending']=false;handlers.onElementDataChange('car:parkingPending');assert(v['car:parkingPending'],'client cannot disable server parking state')
handlers['car:parkingGrounded']();assert(v.frozen and not v['car:parkingPending'],'syncer ground acknowledgement finalizes parking')
getVehicleOccupant=occupant;FactionVehicleAdapter.vehicles[v].brake=false;v.frozen=false;v['car:handbrake']=false
sourceResource={};assert(not registerFactionVehicle(v,'fraction:2:2',30),'foreign resource cannot register')
assert(FactionVehicleAdapter.handle(p,'engine') and v.engine,'ranked on-duty driver starts engine')
FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'engine switches off')
fuel=0;FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'empty fuel blocks start');fuel=30
FactionVehicleAdapter.handle(outsider,'engine');assert(not v.engine,'insufficient rank denied')
p.duty=false;FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'off-duty driver denied');p.duty=true
FactionVehicleAdapter.handle(p,'lights');assert(v.lights==2,'headlights use rp_car adapter')
FactionVehicleAdapter.handle(p,'brake');assert(v['car:handbrake'] and v.frozen,'custom handbrake integrates HUD')
FactionVehicleAdapter.handle(p,'lock',{v});assert(v.locked,'screen-selected service car locks')
local flashTimers=timers;timers={}
for i=2,#flashTimers do flashTimers[i].fn(unpack(flashTimers[i].args));assert(v.lights==(i%2==0 and 2 or 1),'lock alternates headlights') end
assert(#timers==1);timers[1].fn(unpack(timers[1].args));assert(v.lights==2,'flash restores enabled headlights')
FactionVehicleAdapter.handle(p,'lock',{v});assert(not v.locked,'second N unlocks')
FactionVehicleAdapter.handle(p,'lights');assert(v.lights==1,'manual light toggle cancels lock flash')
for i=2,#timers do timers[i].fn(unpack(timers[i].args)) end
assert(v.lights==1,'cancelled timers do not override manual light choice')
sourceResource=fractionResource;assert(unregisterFactionVehicle(v),'service car deregisters')
print('Faction vehicle adapter: registration, rank/duty, engine, fuel, lights, brake and locks passed')
