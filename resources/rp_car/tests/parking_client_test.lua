root,resourceRoot={},{}
local v={pending=true,streamed=true,syncer=true,waiting=true,ground=false,vz=-0.1}
local handlers,poll,sent={},nil,0
function getElementType() return 'vehicle' end
function getElementData(e) return e.pending end
function getElementsByType() return {v} end
function addEventHandler(name,_,fn) handlers[name]=fn end
function setTimer(fn) poll=fn end
function isElement() return true end
function isElementStreamedIn(e) return e.streamed end
function isElementSyncer(e) return e.syncer end
function isElementWaitingForGroundToLoad(e) return e.waiting end
function isVehicleOnGround(e) return e.ground end
function getElementVelocity(e) return 0,0,e.vz end
function triggerServerEvent(name,e) assert(name=='car:parkingGrounded' and e==v);sent=sent+1 end
dofile('resources/rp_car/parking_client.lua')
handlers.onClientResourceStart();poll();assert(sent==0,'no settling before map collision loads')
v.waiting=false;poll();assert(sent==0,'airborne suspension stays free')
v.ground=true;poll();assert(sent==0,'falling car stays free')
v.vz=0;v.syncer=false;poll();assert(sent==0,'non-syncer cannot report ground')
v.syncer=true;poll();assert(sent==1,'settled syncer reports to authoritative server')
source=v;v.pending=false;handlers.onClientElementDataChange('car:parkingPending');poll();assert(sent==1,'completed parking no longer polled')
print('Parking client: streaming, collision, wheels, vertical velocity, syncer and cleanup passed')
