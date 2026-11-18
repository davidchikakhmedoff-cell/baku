-- GTA's street occlusion volumes can cull vehicles in the underground LSPD
-- garage. Disable them only while the player is actually in that garage.
local previous
local function restore()
 if previous~=nil then setOcclusionsEnabled(previous);previous=nil end
end
local function update()
 local garage=Fractions[2] and Fractions[2].garage
 local x,y,z=getElementPosition(localPlayer)
 local point=garage and garage.outside
 local inside=point and getElementInterior(localPlayer)==0 and getElementDimension(localPlayer)==0
  and z<point.z+4 and z>point.z-5 and (x-point.x)^2+(y-point.y)^2<(garage.visibilityRadius or 90)^2
 if inside and previous==nil then previous=getOcclusionsEnabled();setOcclusionsEnabled(false)
 elseif not inside then restore() end
end
local timer=setTimer(update,250,0)
addEventHandler('onClientResourceStop',resourceRoot,function()
 if isTimer(timer) then killTimer(timer) end
 restore()
end)
