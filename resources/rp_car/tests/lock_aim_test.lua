local file=assert(io.open('resources/rp_car/client.lua','rb'));local code=file:read('*a');file:close()
local selector=assert(code:match('function getLookedVehicle%(%)%s*.-\nend'))
localPlayer={};CarLockAccountId=7;CarConfig={lockAimDistance=25}
local centred={owner=7,x=9,sx=960,sy=540}
local near={owner=7,x=2,sx=1020,sy=540}
local foreign={owner=8,x=1,sx=960,sy=540}
local cars={near,centred}
function getPedOccupiedVehicle() return nil end
function getCameraMatrix() return 0,0,1 end
function guiGetScreenSize() return 1920,1080 end
function getElementPosition(v) return v.x or 0,0,0 end
function getElementData(v,key) if key=='car:ownerAccountId' then return v.owner end end
function getElementInterior() return 0 end
function getElementDimension(v) return v.dimension or 0 end
function getElementsByType() return cars end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.abs(x-a) end
function getScreenFromWorldPosition(x) for _,v in ipairs(cars) do if v.x==x then return v.sx,v.sy end end end
function isLineOfSightClear(cx,cy,cz,x,y,z,buildings,checkVehicles) assert(checkVehicles==true,'visibility must detect the target vehicle collision');return x~=centred.blockedX end
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
cars={centred};centred.x=9;centred.blockedX=9
local decoration={}
function processLineOfSight() return true,0,0,0,decoration end
function getElementAttachedTo() return centred end
assert(getLookedVehicle()==centred,'attached decoration cannot occlude its own vehicle lock target')
getElementAttachedTo=function() return nil end
assert(not getLookedVehicle(),'unrelated map objects still occlude targets')
getPedOccupiedVehicle=function() return centred end
assert(getLookedVehicle()==centred,'inside vehicle lock targets current vehicle even when camera points away')
getPedOccupiedVehicle=function() return nil end;processLineOfSight=nil
cars={near,foreign}
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
controlFeedback=outputChatBox
local ticks=0
function getTickCount() ticks=ticks+1000;return ticks end
function triggerServerEvent(event,element,targets) sent={event=event,targets=targets} end
local press=assert(loadstring('local keyDebounce={}\n'..handle..'\nreturn handleVehicleControlKey'))()
CarLockAccountId=nil
assert(press('n','test') and sent.event=='car:toggleLock' and #sent.targets==2,'N sends server request without client account identity or a house')
blocked=true;feedback=nil;sent=nil
assert(not press('n','test') and not feedback and not sent,'chat/UI block must be silent and send no lock request')
blocked=false;cars={};feedback=nil
assert(not press('n','test') and not feedback,'no aim target must be silent')
print('N handler: actual request path without client identity plus silent chat and missing-target handling passed')
-- All main key actions must reach their server events, not just N.
function getPedOccupiedVehicle() return near end
CarConfig.events.toggleEngine='car:toggleEngine'
CarConfig.events.toggleLights='car:toggleLights'
CarConfig.events.toggleHandbrake='car:toggleHandbrake'
for key,event in pairs({['2']='car:toggleEngine',l='car:toggleLights',b='car:toggleHandbrake'}) do
 feedback=nil;sent=nil
 assert(press(key,'test') and sent.event==event,'key '..key..' must reach '..event)
end
print('Vehicle keys: engine 2, lights L and handbrake B request paths passed')

-- The separate menu branch previously retained one notification after dispatch was silenced.
local menuCallback=assert(code:match('addEventHandler%("onClientKey", root, function%(key, press%).-\nend%)'))
local menuKey
function addEventHandler(_,_,fn) menuKey=fn end
assert(loadstring('local UI={mode="tuning"}\n'..menuCallback))()
feedback=nil;sent=nil;menuKey('n',true)
assert(not feedback and not sent,'N inside vehicle menu/chat is silent in the raw key handler as well')
print('N raw menu handler: no remaining close-window notification passed')

local blockedHelper=assert(code:match('(local function isInputBlocked%(.-\nend)'))
function coreClientRunning() return true end
exports={rp_core={isTextInputActive=function() return true end,isAnyBlockingUIOpen=function() return true end}}
local cursor=false
function isCursorShowing() return cursor end
local inputCheck=assert(loadstring('local UI={}\n'..blockedHelper..'\nreturn isInputBlocked'))()
assert(not inputCheck(),'stale hidden input state after closing key menu must not block vehicle keys')
cursor=true;assert(inputCheck(),'visible editing window still blocks keys')
cursor=false;function isChatBoxInputActive() return true end
assert(inputCheck(),'open chat always blocks lock requests without feedback')
print('Vehicle input: hidden stale editor no longer blocks, real UI/chat still protected')
