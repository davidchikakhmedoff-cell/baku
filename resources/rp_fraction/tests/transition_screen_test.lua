root,resourceRoot,localPlayer={},{},{}
local handlers,now,x,pending,waiting,floor,frames={},0,0,false,true,false,{}
function addEventHandler(name,element,fn) handlers[name]=fn end
local poll
function setTimer(fn) poll=fn end
function getTickCount() return now end
function getElementPosition() return x,0,5.9 end
function getElementVelocity() return 0,0,0 end
function getElementData() return pending end
function isElementWaitingForGroundToLoad() return waiting end
function processLineOfSight() return floor end
function fadeCamera(visible,duration) frames[#frames+1]={visible=visible,duration=duration} end
dofile('resources/rp_core/systems/visual/transitions.lua')
poll();now=100;x=1;poll();assert(#frames==0,'ordinary movement does not fade screen')
now=200;x=100;poll();assert(#frames==1 and not frames[1].visible,'position teleport darkens screen')
now=500;poll();assert(#frames==1,'screen stays dark while scene loads')
waiting=false;floor=true;now=600;poll();assert(frames[2].visible,'loaded destination fades in')
pending=true;source=localPlayer;handlers.onClientElementDimensionChange();now=700;x=200;poll()
assert(#frames==2,'generic observer does not override server-managed faction transition')
pending=false;handlers.onClientElementInteriorChange();assert(not frames[#frames].visible,'interior change darkens screen')
now=1000;poll();assert(frames[#frames].visible,'interior scene opens after loading')
print('Screen transitions: normal movement, teleport, loading, interior and faction ownership passed')
