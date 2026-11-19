local function protected(vehicle)
 return getElementType(vehicle)=='vehicle' and getElementData(vehicle,'fraction:vehicle')
  and getElementData(vehicle,'fraction:issued')~=true
end
addEventHandler('onClientVehicleDamage',root,function()
 if protected(source) then
  cancelEvent()
  fixVehicle(source)
 end
end,true,'high+20')
addEventHandler('onClientElementStreamIn',root,function()
 if protected(source) then fixVehicle(source) end
end)
