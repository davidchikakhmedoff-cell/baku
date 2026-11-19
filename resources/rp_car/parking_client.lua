-- Wait for local physics, not just time elapsed since the server created a car.
local pending={}
local function track(vehicle)
 if getElementType(vehicle)=='vehicle' and getElementData(vehicle,'car:parkingPending')==true and not pending[vehicle] then
  pending[vehicle]={streamedAt=getTickCount()}
 end
end
addEventHandler('onClientElementStreamIn',root,function() track(source) end)
addEventHandler('onClientElementDataChange',root,function(key)
 if key~='car:parkingPending' then return end
 if getElementData(source,key)==true then track(source) else pending[source]=nil end
end)
addEventHandler('onClientElementStreamOut',root,function() pending[source]=nil end)
addEventHandler('onClientElementDestroy',root,function() pending[source]=nil end)
addEventHandler('onClientResourceStart',resourceRoot,function()
 for _,vehicle in ipairs(getElementsByType('vehicle',root,true)) do track(vehicle) end
end)
setTimer(function()
 local now=getTickCount()
 for vehicle,state in pairs(pending) do
  if not isElement(vehicle) or not isElementStreamedIn(vehicle) then pending[vehicle]=nil
  elseif isElementSyncer(vehicle) and not isElementWaitingForGroundToLoad(vehicle) and isVehicleOnGround(vehicle) then
   local x,y,z=getElementPosition(vehicle)
   local vx,vy,vz=getElementVelocity(vehicle)
   local stable=vx*vx+vy*vy+vz*vz<0.000025 and state.z and math.abs(z-state.z)<0.005
   state.z=z
   if stable then state.stableSince=state.stableSince or now else state.stableSince=nil end
   if now-state.streamedAt>=1000 and state.stableSince and now-state.stableSince>=750 then
    triggerServerEvent('car:parkingGrounded',vehicle)
   end
  else state.stableSince=nil;state.z=nil end
 end
end,250,0)
