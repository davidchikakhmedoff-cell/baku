local F=Fraction
local pending={}
local serial=0
local function atTarget(p,state)
 if not isElement(p) or isPedDead(p) then return false end
 if getElementInterior(p)~=state.interior or getElementDimension(p)~=state.dimension then return false end
 local x,y,z=getElementPosition(p);local pos=state.pos
 return (x-pos.x)^2+(y-pos.y)^2+(z-pos.z)^2<1
end
local function finish(p,success)
 local state=pending[p];if not state then return end
 pending[p]=nil
 if isTimer(state.timer) then killTimer(state.timer) end
 if not isElement(p) then return end
 if atTarget(p,state) then
  local pos=success and state.pos or state.fallback
  if not success then
   setElementInterior(p,state.oldInterior);setElementDimension(p,state.oldDimension)
   F.notify(p,'Место перехода не загрузилось. Вы возвращены обратно; проверьте координаты появления')
  end
  setElementPosition(p,pos.x,pos.y,pos.z);setPedRotation(p,pos.rotation or 0)
  setElementVelocity(p,0,0,0)
 end
 setElementFrozen(p,state.frozen)
 setElementData(p,'rp:transitionPending',false,true);fadeCamera(p,true,0.35)
 triggerClientEvent(p,'fraction:portalFinished',resourceRoot,state.token)
end
function F.safeTeleport(p,pos,interior,dimension,fallback)
 if pending[p] or isPedInVehicle(p) or isPedDead(p) then return false end
 local x,y,z=getElementPosition(p);fallback=fallback or {x=x,y=y,z=z}
 serial=serial+1
 local state={pos=pos,interior=interior,dimension=dimension,oldInterior=getElementInterior(p),oldDimension=getElementDimension(p),fallback=fallback,token=serial,frozen=isElementFrozen(p)}
 pending[p]=state
 setElementFrozen(p,true);setElementVelocity(p,0,0,0)
 setElementData(p,'rp:transitionPending',true,true);fadeCamera(p,false,0.2)
 state.timer=setTimer(function()
  if not isElement(p) or pending[p]~=state then return end
  setElementInterior(p,interior);setElementDimension(p,dimension);setElementPosition(p,pos.x,pos.y,pos.z)
  setPedRotation(p,pos.rotation or 0);setCameraTarget(p,p)
  state.timer=setTimer(function() finish(p,false) end,8000,1)
  triggerClientEvent(p,'fraction:portalPrepare',resourceRoot,state.token,{x=pos.x,y=pos.y,z=pos.z})
 end,200,1)
 return true
end
F.safeGarageTeleport=F.safeTeleport
addEvent('fraction:portalReady',true)
addEventHandler('fraction:portalReady',resourceRoot,function(token)
 if source~=resourceRoot or not client then return end
 local state=pending[client]
 if state and token==state.token then finish(client,true) end
end)
addEventHandler('onPlayerQuit',root,function()
 local state=pending[source];if state and isTimer(state.timer) then killTimer(state.timer) end
 pending[source]=nil
end)
addEventHandler('onResourceStop',resourceRoot,function()
 for p in pairs(pending) do finish(p,false) end
end)
