local remaining,received=0,0
addEvent('fraction:jailClock',true)
addEventHandler('fraction:jailClock',resourceRoot,function(seconds)
 remaining=math.max(0,tonumber(seconds) or 0);received=getTickCount()
end)
local function requestClock()
 triggerServerEvent('fraction:requestJailClock',resourceRoot)
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 requestClock()
 -- The startup request can precede login/server readiness. Recover lost sync.
 setTimer(function()
  if getElementData(localPlayer,'auth:loggedIn')==true
   and getElementInterior(localPlayer)==6 and getElementDimension(localPlayer)==FractionConfig.dimensionBase+100
   and (remaining<=0 or getTickCount()-received>10000) then requestClock() end
 end,5000,0)
end)
addEventHandler('onClientElementDataChange',localPlayer,function(key)
 if key=='auth:loggedIn' and getElementData(localPlayer,key)==true then requestClock() end
end)
addEventHandler('onClientRender',root,function()
 if remaining<=0 or getElementData(localPlayer,'auth:loggedIn')~=true then return end
 local seconds=math.max(0,math.ceil(remaining-math.max(0,getTickCount()-received)/1000))
 local sw,sh=guiGetScreenSize();local scale=math.min(sw/1920,sh/1080)
 local w,h=math.floor(240*scale),math.floor(42*scale)
 local x,y=math.floor((sw-w)/2),math.floor(sh-190*scale)
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230))
 dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(14,14,14,230))
 dxDrawText(string.format('КПЗ   %02d:%02d',math.floor(seconds/60),seconds%60),x,y,x+w,y+h,tocolor(245,245,245),1,'default-bold','center','center')
end)
