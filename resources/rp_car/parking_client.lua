-- Server-created cars have no physics until a nearby client streams them in.
-- Let that client settle the suspension before the server freezes the brake.
local pending={}
local function track(vehicle)
 if getElementType(vehicle)=='vehicle' and getElementData(vehicle,'car:parkingPending')==true then pending[vehicle]=true end
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
 for vehicle in pairs(pending) do
  if not isElement(vehicle) or not isElementStreamedIn(vehicle) then pending[vehicle]=nil
  elseif isElementSyncer(vehicle) and not isElementWaitingForGroundToLoad(vehicle) and isVehicleOnGround(vehicle) then
   local _,_,vz=getElementVelocity(vehicle)
   if math.abs(vz)<0.01 then triggerServerEvent('car:parkingGrounded',vehicle) end
  end
 end
end,250,0)
