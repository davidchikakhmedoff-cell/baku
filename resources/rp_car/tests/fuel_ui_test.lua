-- Run from repository root with Lua 5.1; exercise the actual dxDraw UI handlers.
local handlers, commands, texts={}, {}, {}
local car={};local player={}
root,resourceRoot,localPlayer={}, {}, player
local sw,sh=1920,1080
local x,y,z=0,0,0
local acquired=false
local core={}
function getResourceFromName() return core end
function getResourceState() return 'running' end
function isElement(v) return type(v)=='table' end
function isChatBoxInputActive() return false end
isConsoleActive,isMainMenuActive,isMTAWindowActive=isChatBoxInputActive,isChatBoxInputActive,isChatBoxInputActive
function getPedOccupiedVehicle() return car end
function getPedOccupiedVehicleSeat() return 0 end
function isPedDead() return false end
function getVehicleEngineState() return false end
function getElementVelocity() return 0,0,0 end
function getElementPosition() return x,y,z end
function getElementInterior() return 0 end
function getElementDimension() return 0 end
function getDistanceBetweenPoints3D(a,b,c,d,e,f) return math.sqrt((a-d)^2+(b-e)^2+(c-f)^2) end
function guiGetScreenSize() return sw,sh end
function getCursorPosition() return 0,0 end
function dxCreateFont() return {} end
function destroyElement() end
function dxDrawRectangle() end
function dxDrawText(value,l,t,r,b) texts[#texts+1]={value=value,l=l,t=t,r=r,b=b} end
function tocolor() return 1 end
function addEvent() end
function addEventHandler(name,el,fn) handlers[name]=fn end
function removeEventHandler() end
local bound
function bindKey(key,state,fn) bound=fn end
function unbindKey() end
function cancelEvent() end
function triggerServerEvent(name,el,value) commands[#commands+1]={name=name,value=value} end
exports={rp_core={openUI=function() acquired=true;return true end,closeUI=function() acquired=false end,isAnyBlockingUIOpen=function() return acquired end}}
assert(loadfile('resources/rp_car/fuel_client.lua'))()
handlers.onClientResourceStart()
bound();assert(commands[#commands].name=='car:fuelOpen')
handlers['car:fuelMenu'](car,{fuel=30,capacity=60,price=5,name='Station',station={x=0,y=0,z=0,radius=17}})
assert(acquired)
for _,size in ipairs({{1920,1080},{1600,900},{1366,768},{1280,720}}) do
 sw,sh=size[1],size[2];texts={};handlers.onClientRender()
 for _,v in ipairs(texts) do assert(v.l>=0 and v.t>=0 and v.r<=sw and v.b<=sh,'UI within screen') end
end
sw,sh=1920,1080;handlers.onClientRender()
local left,top=(sw-420)/2,(sh-365)/2
handlers.onClientClick('left','down',left+250,top+275) -- Full tank selects, does not charge.
handlers.onClientClick('left','down',left+50,top+275)
assert(commands[#commands].name=='car:fuelBuy' and commands[#commands].value==30)
handlers['car:fuelProgress'](2,30,32);texts={};handlers.onClientRender()
local progress=false
for _,v in ipairs(texts) do if v.value:find('2.0 / 30.0') then progress=true end end
assert(progress,'server progress rendered')
x=100;handlers.onClientRender()
assert(not acquired and commands[#commands].name=='car:fuelCancel','exit area closes UI and cancels')
print('Fuel UI: open, four resolutions, full tank, purchase, progress, area exit passed')
