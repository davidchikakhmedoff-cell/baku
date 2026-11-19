local modes,cooldowns={},{}
local function supported(v)
 local spec=isElement(v) and FractionCarConfig.models[getElementModel(v)]
 return spec and spec.sirens~=nil
end
local function setMode(v,mode)
 modes[v]=mode
 setVehicleSirensOn(v,mode==2)
 setElementData(v,'fraction:sirenMode',mode,true)
end
local function initialize(v)
 if supported(v) and modes[v]==nil then setMode(v,getVehicleSirensOn(v) and 2 or 0) end
end
addEvent('fraction:cycleSirens',true)
addEventHandler('fraction:cycleSirens',resourceRoot,function()
 local p=client
 if source~=resourceRoot or not Fraction.account(p) or isPedDead(p) or Fraction.cuffs[p] or Fraction.jailed(p) then return end
 local v=getPedOccupiedVehicle(p)
 if not supported(v) or not isPedInVehicle(p) or getPedOccupiedVehicleSeat(p)~=0 or getVehicleOccupant(v,0)~=p or isVehicleBlown(v) then return end
 local now=getTickCount()
 if cooldowns[p] and now-cooldowns[p]<200 then return end
 cooldowns[p]=now;initialize(v);setMode(v,(modes[v]+1)%3)
end)
addEventHandler('onResourceStart',resourceRoot,function()
 for _,v in ipairs(getElementsByType('vehicle')) do initialize(v) end
end)
addEventHandler('onVehicleEnter',root,function() initialize(source) end)
addEventHandler('onVehicleExplode',root,function() if supported(source) then setMode(source,0) end end)
addEventHandler('onElementDataChange',root,function(key)
 if client and key=='fraction:sirenMode' and supported(source) then
  initialize(source);setElementData(source,key,modes[source],true)
 end
end)
addEventHandler('onElementDestroy',root,function() modes[source]=nil end)
addEventHandler('onPlayerQuit',root,function() cooldowns[source]=nil end)
addEventHandler('onResourceStop',resourceRoot,function()
 for v in pairs(modes) do if isElement(v) then setVehicleSirensOn(v,false);removeElementData(v,'fraction:sirenMode') end end
end)
