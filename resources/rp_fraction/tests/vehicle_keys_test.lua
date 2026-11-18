dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local f=Fractions[1];f.vehicles={f.vehicles[1],f.vehicles[3]}
local marker,otherMarker={},{}
local p={id=101,rank=6,faction=1,logged=true,working=true,marker=marker,name='First_Player'}
local q={id=102,rank=6,faction=1,logged=true,working=true,marker=marker,name='Second_Player'}
local low={id=103,rank=1,faction=1,logged=true,working=true,marker=marker,name='Low_Rank'}
local outsider={id=104,rank=10,faction=2,logged=true,working=true,marker=marker,name='Other_Faction'}
Fraction={vehicles={},markers={['keys:1']=marker,['keys:2']=otherMarker},cuffs={}}
local F=Fraction
F.account=function(player) return player and player.logged and player.id end
F.member=function(player) return player and {faction_id=player.faction,rank=player.rank} end
F.active=function(player,fid,rank) return F.account(player) and player.working and not player.dead and player.faction==fid and player.rank>=(rank or 1) end
F.near=function(player,m) return player.marker==m end
F.jailed=function() return false end
F.name=function(player) return player.name end
F.notify=function() end
FractionDependencies={ready=function() return true end}
FractionDB={one=function() return {fuel=23.4} end}
local handlers,vehicles,menus={}, {}, {}
function addEventHandler(name,element,fn) handlers[name]=handlers[name] or {};table.insert(handlers[name],fn) end
function isElement(e) return type(e)=='table' and not e.destroyed end
local respawnTimer
function setTimer(fn,ms,count,...) respawnTimer={fn=fn,ms=ms,args={...}} end
local clock=10000
function getTickCount() return clock end
function getElementsByType(kind)
 local result={};if kind=='vehicle' then for _,v in ipairs(vehicles) do if not v.destroyed then result[#result+1]=v end end end
 return result
end
function createVehicle(model,x,y,z) local v={model=model,x=x,y=y,z=z,occupants={}};vehicles[#vehicles+1]=v;return v end
function destroyElement(v)
 v.destroyed=true;local old=source;source=v
 for _,fn in ipairs(handlers.onElementDestroy or {}) do fn() end;source=old
end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementInterior() return 0 end
function getElementDimension() return 0 end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function setElementPosition(e,x,y,z) e.x,e.y,e.z=x,y,z end
function setElementInterior() end
function setElementDimension() end
function setElementData() end
function setVehicleColor() end
function setVehicleEngineState(v,b) v.engine=b end
function setVehicleLocked(v,b) v.locked=b end
function setElementFrozen(v,b) v.frozen=b end
function getVehicleOccupants(v) return v.occupants end
function getPedOccupiedVehicle(player) return player.vehicle end
function getPedOccupiedVehicleSeat() return 0 end
function removePedFromVehicle(player)
 if player.vehicle then for seat,occupant in pairs(player.vehicle.occupants) do if occupant==player then player.vehicle.occupants[seat]=nil end end end
 player.vehicle=nil
end
function isPedInVehicle(player) return player.vehicle~=nil end
function isPedDead(player) return player.dead or false end
function getVehicleNameFromModel(id) return id==487 and 'Maverick' or 'Ambulance' end
function triggerClientEvent(player,event,element,kind,data) if event=='fraction:menu' then menus[player]=data end end
local saved,registered=0,{}
exports={rp_car={registerFactionVehicle=function(self,v,key,fuel) registered[key]=v;v.fuel=fuel;return true end,
 unregisterFactionVehicle=function(self,v) saved=saved+1 end}}
dofile('resources/rp_fraction/server/world.lua');dofile('resources/rp_fraction/server/vehicle_keys.lua')
-- Only this faction has a fleet in this fixture.
for id,definition in pairs(Fractions) do if id~=1 then definition.vehicles={} end end
F.spawnFleet()
local carKey,heliKey='fraction:1:1','fraction:1:3'
local first=F.vehicleByKey[carKey]
assert(first.locked and not canDriveFactionVehicle(p,first),'unassigned service car is locked and no member can drive without keys')
F.keysMenu(q);F.takeVehicleKeys(p,1)
assert(F.hasVehicleKey(p,carKey) and not F.hasVehicleKey(q,carKey),'one server-side holder per vehicle')
assert(canDriveFactionVehicle(p,first) and not canDriveFactionVehicle(q,first),'even same-rank coworkers cannot control holder vehicle')
assert(menus[q].rows[1].holder=='First_Player','other open menus see holder nickname immediately')
F.takeVehicleKeys(q,1);assert(not F.playerKeys[q],'second player cannot claim same keys')
F.takeVehicleKeys(p,3);assert(F.playerKeys[p]==carKey and not F.keyHolders[heliKey],'one vehicle per player')
F.takeVehicleKeys(low,3);assert(not F.playerKeys[low],'helicopter rank requirement enforced')
F.takeVehicleKeys(outsider,1);assert(not F.playerKeys[outsider],'foreign-faction desk access rejected')
q.working=false;F.takeVehicleKeys(q,3);assert(not F.playerKeys[q],'off-duty requests rejected');q.working=true
p.marker=nil;assert(not F.returnVehicleKeys(p,false) and F.hasVehicleKey(p,carKey),'remote manual return rejected')
p.marker=marker;F.returnVehicleKeys(p,false)
assert(not F.playerKeys[p] and not F.keyHolders[carKey] and first.destroyed and F.vehicleByKey[carKey]~=first,'return destroys old car and respawns its configured parking slot')
assert(saved==1 and F.vehicleByKey[carKey].fuel==23.4,'return persists fuel through existing car adapter')

-- A returned car is replaced immediately, even with passengers.
F.takeVehicleKeys(q,1)
local occupied=F.vehicleByKey[carKey];local passenger={id=200};occupied.occupants[1]=passenger;passenger.vehicle=occupied;passenger.x,passenger.y,passenger.z=900,800,20;passenger.interior,passenger.dimension=4,55
F.returnVehicleKeys(q,false)
assert(occupied.destroyed and not passenger.vehicle and not F.returningVehicles[carKey],'passengers cannot delay return')
assert(passenger.x==900 and passenger.y==800 and passenger.z==20 and passenger.interior==4 and passenger.dimension==55,'passenger remains at original position, interior and dimension')
local replacement=F.vehicleByKey[carKey];F.vehicleKeysTick();assert(F.vehicleByKey[carKey]==replacement,'no repeated respawn after successful return')

F.takeVehicleKeys(p,1);p.logged=false;F.returnVehicleKeys(p,true)
assert(not F.playerKeys[p] and not F.keyHolders[carKey],'logout returns keys even after auth fields are cleared');p.logged=true
F.takeVehicleKeys(p,1);p.working=false;F.vehicleKeysTick()
assert(not F.playerKeys[p],'loss of active duty automatically returns keys');p.working=true

-- Parking blocked by another car: no overlap, no lost return, retry once free.
F.takeVehicleKeys(p,1)
local parking=f.vehicles[1].p;local blocker=createVehicle(400,parking.x,parking.y,parking.z)
F.returnVehicleKeys(p,false)
assert(F.returningVehicles[carKey] and not F.vehicleByKey[carKey],'blocked parking defers respawn without vehicle overlap')
blocker.x=blocker.x+100;F.vehicleKeysTick()
assert(F.vehicleByKey[carKey] and not F.returningVehicles[carKey],'parking retry completes when slot becomes free')

F.takeVehicleKeys(p,3);local helicopter=F.vehicleByKey[heliKey];source=helicopter
for _,fn in ipairs(handlers.onVehicleExplode) do fn() end
assert(not F.playerKeys[p] and not F.keyHolders[heliKey] and F.missing[heliKey].at>getTickCount(),'destruction frees keys while preserving configured respawn delay')
F.takeVehicleKeys(q,3);assert(not F.playerKeys[q],'destroyed helicopter cannot be checked out')
-- Wrecks respawn even if a dead passenger remains in the seat.
helicopter.occupants[1]=q;q.vehicle=helicopter;q.dead=true
assert(FractionConfig.vehicleRespawnMs==5000 and respawnTimer.ms==5000,'explosion schedules five-second respawn')
clock=clock+4999;F.fleetTick()
assert(not helicopter.destroyed and F.vehicleByKey[heliKey]==helicopter,'no early respawn')
clock=clock+1;respawnTimer.fn(unpack(respawnTimer.args))
assert(helicopter.destroyed and F.vehicleByKey[heliKey]~=helicopter and not q.vehicle,'exploded fleet vehicle returns without waiting for stale occupants')
assert(F.vehicleByKey[heliKey].locked and not F.keyHolders[heliKey],'replacement is locked and has no issued keys')
q.dead=false
F.takeVehicleKeys(p,1);F.stopping=true;local before=saved;F.returnVehicleKeys(p,true)
assert(not F.playerKeys[p] and saved==before,'resource stop clears keys without creating cars during shutdown')

-- Run the real rp_car interaction adapter against the real key permission
-- function, rather than replacing its access check with a rank-only stub.
F.stopping=false;F.takeVehicleKeys(p,1)
local controlled=F.vehicleByKey[carKey];p.vehicle=controlled;q.vehicle=controlled
p.x,p.y,p.z=controlled.x,controlled.y,controlled.z;q.x,q.y,q.z=p.x,p.y,p.z
controlled.occupants[0]=p
local fractionResource={};sourceResource=fractionResource
function getResourceFromName() return fractionResource end
function getResourceState() return 'running' end
function call(resource,method,player,vehicle) assert(method=='canDriveFactionVehicle');return canDriveFactionVehicle(player,vehicle) end
function setTimer() end
function addEvent() end
function setElementAngularVelocity() end
function getVehicleEngineState(v) return v.engine or false end
function getVehicleOccupant(v,seat) return v.occupants[seat or 0] end
function setVehicleOverrideLights(v,value) v.lights=value end
function getElementVelocity() return 0,0,0 end
function isVehicleOnGround() return true end
function isVehicleLocked(v) return v.locked end
function getElementData() return false end
exports.rp_core={getAuthPlayerId=function(self,player) return player.id end}
FuelSystem={attachExternal=function() end,canStart=function() return true end}
CarLockFeedback={flash=function() end,cancel=function() end}
CarInteraction={ready=function() return true end};CarConfig={lockServerDistance=25,events={playLockSound='car:playLockSound'}}
dofile('resources/rp_car/faction_adapter.lua')
assert(registerFactionVehicle(controlled,carKey,23.4),'service car registered with actual adapter')
FactionVehicleAdapter.handle(p,'engine');assert(controlled.engine,'key holder can start engine')
FactionVehicleAdapter.handle(p,'lights');assert(controlled.lights==2,'key holder can switch lights')
FactionVehicleAdapter.handle(p,'brake');assert(controlled.frozen,'key holder can use handbrake')
FactionVehicleAdapter.handle(p,'lock',{controlled});local lock=controlled.locked
for _,kind in ipairs({'engine','lights','brake','lock'}) do FactionVehicleAdapter.handle(q,kind,{controlled}) end
assert(controlled.engine and controlled.lights==2 and controlled.frozen and controlled.locked==lock,'coworker without key cannot change engine/lights/handbrake/locks')
print('Vehicle keys: exclusivity, one-per-player, faction/rank/duty, live menus, return/fuel, passenger/parking waits, logout, loss and shutdown passed')
