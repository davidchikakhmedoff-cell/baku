-- Separate registry: service cars are never inserted into personal_vehicles.
FactionVehicleAdapter={vehicles={}}
local A=FactionVehicleAdapter
local function permission(p,v)
 local r=getResourceFromName('rp_fraction')
 return A.vehicles[v] and r and getResourceState(r)=='running' and call(r,'canDriveFactionVehicle',p,v)==true
end
A.canAccess = permission
function registerFactionVehicle(vehicle,key,fuel)
 if sourceResource~=getResourceFromName('rp_fraction') or not isElement(vehicle) or type(key)~='string' or not key:match('^fraction:%d+:%d+$') then return false end
 A.vehicles[vehicle]={key=key,engine=false,lights=false,brake=false}
 FuelSystem.attachExternal(vehicle,key,fuel)
 setTimer(function(v)
  local state=A.vehicles[v]
  if isElement(v) and state and not getVehicleEngineState(v) then
   setElementVelocity(v,0,0,0);setElementAngularVelocity(v,0,0,0)
   state.brake=true;setElementFrozen(v,true);setElementData(v,'car:handbrake',true,true)
  end
 end,tonumber(CarConfig.parkingSettleDelay) or 1000,1,vehicle)
 return true
end
function unregisterFactionVehicle(vehicle)
 if sourceResource~=getResourceFromName('rp_fraction') or not A.vehicles[vehicle] then return false end
 FuelSystem.detach(vehicle);A.vehicles[vehicle]=nil;return true
end
function A.handle(p,kind,target)
 local vehicle=getPedOccupiedVehicle(p)
 if kind=='lock' then
  local candidates=type(target)=='table' and target or {target}
  for i=1,math.min(64,#candidates) do
   local v=candidates[i]
   if A.vehicles[v] and permission(p,v) then vehicle=v;break end
   if isElement(v) and tonumber(getElementData(v,'car:ownerAccountId'))==tonumber(exports.rp_core:getAuthPlayerId(p)) then return false end
  end
 end
 local state=vehicle and A.vehicles[vehicle];if not state then return false end
 if not CarInteraction.ready(p) or not permission(p,vehicle) then return true end
 local px,py,pz=getElementPosition(p);local x,y,z=getElementPosition(vehicle)
 if getElementDimension(p)~=getElementDimension(vehicle) or getElementInterior(p)~=getElementInterior(vehicle) or getDistanceBetweenPoints3D(px,py,pz,x,y,z)>CarConfig.lockServerDistance then return true end
 if kind~='lock' and (getPedOccupiedVehicle(p)~=vehicle or getPedOccupiedVehicleSeat(p)~=0) then return true end
 if kind=='engine' then
  if not getVehicleEngineState(vehicle) and not FuelSystem.canStart(vehicle) then return true end
  state.engine=not getVehicleEngineState(vehicle);setVehicleEngineState(vehicle,state.engine)
  if state.engine and not state.brake then setElementFrozen(vehicle,false) end
  setElementData(vehicle,'car:engineOn',state.engine,true)
 elseif kind=='lights' then state.lights=not state.lights;setVehicleOverrideLights(vehicle,state.lights and 2 or 1)
 elseif kind=='brake' then
  local vx,vy,vz=getElementVelocity(vehicle)
  if not state.brake and (not isVehicleOnGround(vehicle) or vx*vx+vy*vy+vz*vz>0.0001) then return true end
  state.brake=not state.brake;setElementFrozen(vehicle,state.brake);setElementData(vehicle,'car:handbrake',state.brake,true)
 elseif kind=='lock' then setVehicleLocked(vehicle,not isVehicleLocked(vehicle)) end
 return true
end
addEventHandler('onElementDestroy',root,function() A.vehicles[source]=nil end)
addEventHandler('onVehicleEnter',root,function(player,seat)
 local state=A.vehicles[source]
 if not state or seat~=0 then return end
 -- GTA's automatic engine start must not bypass the resource's 2 key or fuel.
 local running=getVehicleOccupant(source,0)==player and permission(player,source) and state.engine and FuelSystem.canStart(source) or false
 setVehicleEngineState(source,running)
end)
