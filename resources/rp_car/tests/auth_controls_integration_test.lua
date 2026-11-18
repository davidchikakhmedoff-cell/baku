-- Load actual rp_core auth focus/UI code and the entire rp_car client, not
-- extracted key functions with isInputBlocked replaced by a passing stub.
local handlers,binds,sent={}, {}, {}
root,resourceRoot,localPlayer={}, {}, {}
local car={}
local cursor=false
function guiGetScreenSize() return 1920,1080 end
function addEvent() end
function addEventHandler(name,element,fn) handlers[name]=handlers[name] or {};handlers[name][#handlers[name]+1]=fn end
function removeEventHandler() end
function addCommandHandler() end
function bindKey(key,kind,fn) binds[key]=fn end
function guiSetInputMode() end
function showCursor(value) cursor=value end
function isCursorShowing() return cursor end
function showChat() end
function toggleAllControls() end
function getResourceFromName() return {} end
function getResourceState() return 'running' end
function isChatBoxInputActive() return false end
isConsoleActive,isMainMenuActive,isMTAWindowActive=isChatBoxInputActive,isChatBoxInputActive,isChatBoxInputActive
function isElement(value) return type(value)=='table' end
function isPedDead() return false end
function getPedOccupiedVehicle() return car end
function getPedOccupiedVehicleSeat() return 0 end
function isPedInVehicle() return true end
function getVehicleOccupant() return localPlayer end
function dxCreateFont() return {} end
function outputDebugString() end
function outputChatBox() end
local ticks=0
function getTickCount() ticks=ticks+1000;return ticks end
function triggerServerEvent(name,element,target) sent[#sent+1]=name end
function getCameraMatrix() return 0,0,1,10,0,1 end
function getElementPosition(el) return el==car and 5 or 0,0,0 end
function getElementInterior() return 0 end
function getElementDimension() return 0 end
function getElementsByType() return {car} end
function getElementData() return false end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.abs(a-x) end
function getScreenFromWorldPosition() return 960,540 end
function isLineOfSightClear() return true end
assert(loadfile('resources/rp_core/systems/auth/config.lua'))()
assert(loadfile('resources/rp_core/systems/auth/utils.lua'))()
assert(loadfile('resources/rp_core/systems/auth/dx_input.lua'))()
assert(loadfile('resources/rp_core/systems/auth/ui.lua'))()
-- Simulate logging in with Enter while the password field still has focus.
AuthUI.rpName=DXInput:new('name',false,32)
AuthUI.password=DXInput:new('password',true,32)
AuthUI.repeatPassword=DXInput:new('repeat',true,32)
AuthUI.submit={enabled=true}
AuthUI.visible=true
RPUIManager.acquire('auth',{cursor=true,inputMode='no_binds_when_editing'})
AuthUI.password:activate()
assert(isTextInputActive(),'visible password field must block car hotkeys')
AuthUI.hide(true,true)
exports={rp_core={isTextInputActive=function() return isTextInputActive() end,
 isAnyBlockingUIOpen=function() return isAnyBlockingUIOpen() end,getActiveUIName=function() return getActiveUIName() end}}
assert(loadfile('resources/rp_car/config.lua'))()
assert(loadfile('resources/rp_car/interaction_shared.lua'))()
assert(loadfile('resources/rp_car/client.lua'))()
for _,fn in ipairs(handlers.onClientResourceStart or {}) do fn() end
for _,key in ipairs({'n','l','b','2'}) do assert(binds[key],'binding exists');binds[key]() end
assert(#sent==4,'hidden auth password focus must not block all four vehicle keys; sent='..#sent)
assert(not DXInput.active,'closing auth must release its password focus')
print('Full auth-to-car integration: Enter login releases focus; N/L/B/2 reach the server')
local other=DXInput:new('another UI',false,32)
other:activate();AuthUI.hide(true,true)
assert(DXInput.active==other,'closing auth must not blur another system input')
other:blur()
AuthUI.show();AuthUI.password:activate()
local previous=#sent
for _,key in ipairs({'n','l','b','2'}) do binds[key]() end
assert(#sent==previous,'a real visible login form still blocks vehicle actions')
AuthUI.hide(true,true)
print('Auth focus: other inputs preserved; visible login form still blocks hotkeys')
local stale=DXInput:new('closed window',false,32)
RPUIManager.acquire('fraction',{cursor=true,inputMode='no_binds_when_editing'});stale:activate()
closeUI('fraction')
assert(not DXInput.active and not isTextInputActive(),'closing active window releases hidden text focus blocking vehicle keys')
