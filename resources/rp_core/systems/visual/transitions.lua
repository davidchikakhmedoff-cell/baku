-- Cover teleports from resources which do not have their own loading screen.
local last,active,started=nil,false,0
local function begin()
 if getElementData(localPlayer,'rp:transitionPending') then return end
 active=true;started=getTickCount();fadeCamera(false,0)
end
for _,event in ipairs({'onClientElementInteriorChange','onClientElementDimensionChange','onClientPlayerSpawn'}) do
 addEventHandler(event,root,function() if source==localPlayer then begin() end end)
end
setTimer(function()
 local x,y,z=getElementPosition(localPlayer)
 if last then
  local vx,vy,vz=getElementVelocity(localPlayer)
  local elapsed=math.max(0,getTickCount()-last.tick)/1000
  local expected=math.sqrt(vx*vx+vy*vy+vz*vz)*50*elapsed
  if (x-last.x)^2+(y-last.y)^2+(z-last.z)^2>math.max(10,expected*3+3)^2 then begin() end
 end
 last={x=x,y=y,z=z,tick=getTickCount()}
 if getElementData(localPlayer,'rp:transitionPending') then active=false;return end
 if active then
  local elapsed=getTickCount()-started
  if elapsed>=200 and ((not isElementWaitingForGroundToLoad(localPlayer) and processLineOfSight(x,y,z+0.3,x,y,z-3,true,false,false,true,false,false,false,false,localPlayer)) or elapsed>=3000) then
   active=false;fadeCamera(true,0.35)
  end
 end
end,100,0)
addEventHandler('onClientResourceStop',resourceRoot,function()
 if active and not getElementData(localPlayer,'rp:transitionPending') then fadeCamera(true,0) end
end)
