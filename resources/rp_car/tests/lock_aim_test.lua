local file=assert(io.open('resources/rp_car/client.lua','rb'));local code=file:read('*a');file:close()
local selector=assert(code:match('function getLookedVehicle%(%)%s*.-\nend'))
localPlayer={};CarLockAccountId=7;CarConfig={lockAimDistance=25}
local centred={owner=7,x=9,sx=960,sy=540}
local near={owner=7,x=2,sx=1020,sy=540}
local foreign={owner=8,x=1,sx=960,sy=540}
local cars={near,centred}
function getCameraMatrix() return 0,0,1 end
function guiGetScreenSize() return 1920,1080 end
function getElementPosition(v) return v.x or 0,0,0 end
function getElementData(v,key) if key=='car:ownerAccountId' then return v.owner end end
function getElementInterior() return 0 end
function getElementDimension(v) return v.dimension or 0 end
function getElementsByType() return cars end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.abs(x-a) end
function getScreenFromWorldPosition(x) for _,v in ipairs(cars) do if v.x==x then return v.sx,v.sy end end end
function isLineOfSightClear(cx,cy,cz,x) return x~=centred.blockedX end
assert(loadstring(selector))()
assert(getLookedVehicle()==centred,'screen centre outranks physical distance')
centred.blockedX=9;assert(getLookedVehicle()==near,'occluded car ignored')
centred.blockedX=nil;centred.x=24;assert(getLookedVehicle()==centred,'centred car at 24 metres can be selected')
centred.x=26;assert(getLookedVehicle()==near,'car beyond 25 metres ignored')
near.sx=1500;assert(not getLookedVehicle(),'outside aim area does not select a neighbour')
near.sx=960;near.dimension=1;assert(not getLookedVehicle(),'different world ignored')
CarLockAccountId=nil;near.dimension=0;near.sx=960;assert(getLookedVehicle()==near,'missing client identity must not block the request')
foreign.sx=958;cars={near,foreign};local first,list=getLookedVehicle();assert(first==near and list[2]==foreign,'ordered target list is sent for authoritative ownership checks')
print('Lock aim: screen-centre ordering, visibility, 25m range and identity-independent selection passed')
-- Exercise the real N handler too; earlier tests stopped at selecting a target.
local handle=assert(code:match('local function handleVehicleControlKey%(.-\nend'))
local sent,feedback
CarConfig.events={toggleLock='car:toggleLock'}
CarInteraction={ready=function() return true end,canToggleLock=function() return true end}
function getCoreUIState() return false,false,nil end
local blocked=false
function isInputBlocked() return blocked end
function debugKey() end
function outputDebugString() end
function outputChatBox(message) feedback=message end
local ticks=0
function getTickCount() ticks=ticks+1000;return ticks end
function triggerServerEvent(event,element,targets) sent={event=event,targets=targets} end
local press=assert(loadstring('local keyDebounce={}\n'..handle..'\nreturn handleVehicleControlKey'))()
CarLockAccountId=nil
assert(press('n','test') and sent.event=='car:toggleLock' and #sent.targets==2,'N sends server request without client account identity or a house')
blocked=true;feedback=nil;sent=nil
assert(not press('n','test') and feedback and not sent,'UI block must give visible feedback')
blocked=false;cars={};feedback=nil
assert(not press('n','test') and feedback,'no aim target must give visible feedback')
print('N handler: actual request path without client identity plus visible failure messages passed')
