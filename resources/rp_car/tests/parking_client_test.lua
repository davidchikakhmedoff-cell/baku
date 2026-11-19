root,resourceRoot={},{}
local v={pending=true,streamed=true,syncer=true,waiting=true,ground=false,vz=-0.1,z=15}
local handlers,poll,sent,clock={},nil,0,0
function getElementType() return 'vehicle' end
function getElementData(e) return e.pending end
function getElementsByType() return {v} end
function addEventHandler(name,_,fn) handlers[name]=fn end
function setTimer(fn) poll=fn end
function getTickCount() return clock end
function getElementPosition(e) return 0,0,e.z end
function isElement() return true end
function isElementStreamedIn(e) return e.streamed end
function isElementSyncer(e) return e.syncer end
function isElementWaitingForGroundToLoad(e) return e.waiting end
function isVehicleOnGround(e) return e.ground end
function getElementVelocity(e) return 0,0,e.vz end
function triggerServerEvent(name,e) assert(name=='car:parkingGrounded' and e==v);sent=sent+1 end
local function tick(now) clock=now;poll() end
dofile('resources/rp_car/parking_client.lua')
handlers.onClientResourceStart();tick(0);assert(sent==0,'wait for streamed map collision')
v.waiting=false;tick(250);assert(sent==0,'airborne suspension stays free')
v.ground=true;tick(500);assert(sent==0,'falling car stays free')
v.vz=0;v.syncer=false;tick(750);assert(sent==0,'non-syncer cannot report ground')
v.syncer=true;tick(1000);tick(1250);tick(1500);assert(sent==0,'one ground flag is insufficient; suspension must stabilize')
v.z=14.6;tick(1750);assert(sent==0,'vertical position change resets settling even with zero reported velocity')
tick(2000);tick(2250);tick(2500);assert(sent==0)
tick(2750);assert(sent==1,'stable streamed syncer reports only after 750ms of settled height')
source=v;v.pending=false;handlers.onClientElementDataChange('car:parkingPending');tick(3000);assert(sent==1,'completed parking no longer polled')
handlers.onClientElementStreamOut();v.pending=true;handlers.onClientElementStreamIn();tick(3250);tick(3500);tick(3750);assert(sent==1,'re-streamed suspension gets a fresh minimum settling interval')
tick(4000);tick(4250);assert(sent>1,'physics settles again after streaming')
print('Parking client: collision, syncer, one-second stream delay, stable height/velocity interval, re-stream and cleanup passed')
