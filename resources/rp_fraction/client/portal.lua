local pending,timer
local function stop()
 if timer and isTimer(timer) then killTimer(timer) end
 pending,timer=nil,nil
end
addEvent('fraction:portalPrepare',true)
addEventHandler('fraction:portalPrepare',resourceRoot,function(token,pos)
 stop();pending={token=token,pos=pos}
 setCameraTarget(localPlayer)
 timer=setTimer(function()
  if not pending or isElementWaitingForGroundToLoad(localPlayer) then return end
  local p=pending.pos
  -- A short ray below the configured underground position cannot select the
  -- street above the garage, unlike getGroundPosition from a high altitude.
  local hit=processLineOfSight(p.x,p.y,p.z+0.3,p.x,p.y,p.z-2.5,true,false,false,true,false,false,false,false,localPlayer)
  if hit then local ready=pending.token;stop();triggerServerEvent('fraction:portalReady',resourceRoot,ready) end
 end,100,0)
end)
addEvent('fraction:portalFinished',true)
addEventHandler('fraction:portalFinished',resourceRoot,function(token)
 if pending and pending.token==token then stop() end
end)
addEventHandler('onClientResourceStop',resourceRoot,stop)
