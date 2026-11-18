local fractionResource={};local p={rank=2,duty=true};local v={};local outsider={rank=1,duty=true}
root={};sourceResource=fractionResource
function addEventHandler() end
function setTimer() end
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
assert(loadfile('resources/rp_car/faction_adapter.lua'))()
assert(registerFactionVehicle(v,'fraction:2:1',30),'own faction resource registers service car')
sourceResource={};assert(not registerFactionVehicle(v,'fraction:2:2',30),'foreign resource cannot register')
assert(FactionVehicleAdapter.handle(p,'engine') and v.engine,'ranked on-duty driver starts engine')
FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'engine switches off')
fuel=0;FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'empty fuel blocks start');fuel=30
FactionVehicleAdapter.handle(outsider,'engine');assert(not v.engine,'insufficient rank denied')
p.duty=false;FactionVehicleAdapter.handle(p,'engine');assert(not v.engine,'off-duty driver denied');p.duty=true
FactionVehicleAdapter.handle(p,'lights');assert(v.lights==2,'headlights use rp_car adapter')
FactionVehicleAdapter.handle(p,'brake');assert(v['car:handbrake'] and v.frozen,'custom handbrake integrates HUD')
FactionVehicleAdapter.handle(p,'lock',{v});assert(v.locked,'screen-selected service car locks')
sourceResource=fractionResource;assert(unregisterFactionVehicle(v),'service car deregisters')
print('Faction vehicle adapter: registration, rank/duty, engine, fuel, lights, brake and locks passed')
