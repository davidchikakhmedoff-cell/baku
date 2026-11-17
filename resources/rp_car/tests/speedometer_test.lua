-- Run from the repository root with Lua 5.1. Uses mocks, not an MTA client.
local handlers, draws, lines = {}, {}, {}
local state = {vehicle={}, seat=0, vx=0, time=0, hour=12, doors={}, broken={}, lights=1, brake=false, control=false, dead=false}
root, resourceRoot, localPlayer = {}, {}, {}
function addEvent() end
function addEventHandler(name, element, callback) handlers[name]=callback end
function removeEventHandler() end
function guiGetScreenSize() return state.w or 1920, state.h or 1080 end
function tocolor(r,g,b,a) return table.concat({r,g,b,a or 255}, ',') end
function isElement(v) return type(v)=='table' end
function destroyElement() end
function dxCreateFont() return {} end
function dxDrawText(value,x,y,r,b,color) draws[#draws+1]={value=value,x=x,y=y,r=r,b=b,color=color} end
function dxDrawLine(x,y,r,b,color) lines[#lines+1]={color=color} end
function triggerServerEvent() end
function getPedOccupiedVehicle() return state.vehicle end
function getPedOccupiedVehicleSeat() return state.seat end
function isPedDead() return state.dead end
function getVehicleType() return 'Automobile' end
function getElementVelocity() return state.vx,0,0 end
function getTickCount() return state.time end
function getElementData() return state.brake end
function getPedControlState() return state.control end
function isVehicleLocked() return state.locked ~= false end
function getVehicleDoorState(v,id) return state.missing==id and 4 or 0 end
function getVehicleDoorOpenRatio(v,id) return state.doors[id] or 0 end
function getVehicleOverrideLights() return state.lights end
function getVehicleLightState(v,id) return state.broken[id] or 0 end
function getVehicleEngineState() return state.engine~=false end
function getTime() return state.hour,0 end
assert(loadfile('resources/rp_car/speedometer_client.lua'))()
handlers.onClientResourceStart()
local tests=0
local function check(ok, message) tests=tests+1; assert(ok,message) end
local function render() draws={};lines={}; handlers.onClientRender() end
local function digit() for _,d in ipairs(draws) do if d.value:match('^%d+$') then return tonumber(d.value) end end end
local function labelColor(label, color) for _,d in ipairs(draws) do if d.value==label and d.color==color then return true end end return false end
local function hasColor(color) for _,l in ipairs(lines) do if l.color==color then return true end end return false end
render(); check(#draws==0,'hidden before login')
handlers['car:speedometerSession'](true)
state.vx=0.5;render();check(digit()==90,'MTA velocity conversion to km/h')
state.time=16;state.vx=1;render();check(digit()>90 and digit()<180,'smooth changes')
state.vehicle={};render();check(digit()==180,'vehicle change resets smoothing')
state.seat=1;render();check(#draws==0,'hidden for passenger')
state.seat=0;state.dead=true;render();check(#draws==0,'hidden on death')
state.dead=false;state.vehicle=false;render();check(#draws==0,'hidden on exit')
state.vehicle={};state.vx=-0.5;render();check(digit()==90,'speed never negative')
state.brake=true;render();check(hasColor(tocolor(239,83,80)),'custom handbrake')
state.brake=false;state.control=true;render();check(not hasColor(tocolor(239,83,80)),'standard handbrake does not light B indicator')
state.control=false;state.locked=false;state.doors[3]=0.5;render();check(not hasColor(tocolor(242,166,74)),'open unlocked door stays muted')
state.doors={};state.locked=true;render();check(hasColor(tocolor(242,166,74)),'N lock lights indicator')
state.doors[2]=0.5;render();check(hasColor(tocolor(242,166,74)),'door angle does not override lock indicator')
state.locked=false;render();check(not hasColor(tocolor(242,166,74)),'unlock clears indicator')
state.doors={}
state.lights=2;render();check(labelColor("LIGHT",tocolor(103,196,216)),'forced headlights on')
state.lights=1;render();check(not labelColor("LIGHT",tocolor(103,196,216)),'forced headlights off')
state.lights=0;state.hour=23;render();check(labelColor("LIGHT",tocolor(103,196,216)),'automatic night headlights')
state.hour=12;render();check(not labelColor("LIGHT",tocolor(103,196,216)),'automatic daytime headlights')
state.engine=true;render();check(labelColor("ENG",tocolor(103,196,216)),'engine running indicator')
state.engine=false;render();check(not labelColor("ENG",tocolor(103,196,216)),'engine off indicator')
for _,size in ipairs({{1920,1080},{1600,900},{1366,768},{1280,720}}) do
 state.w,state.h=size[1],size[2];render()
 local inside=true
 for _,d in ipairs(draws) do inside=inside and d.x>=0 and d.y>=0 and d.r<=state.w and d.b<=state.h end
 check(inside,'HUD fits '..state.w..'x'..state.h)
end
handlers['car:speedometerSession'](false);render();check(#draws==0,'hidden after logout')
handlers.onClientResourceStop()
print('Client HUD: '..tests..' checks passed')
-- Server session handshake and logout propagation, without exposing other player data.
handlers={}; local sent
function triggerClientEvent(player,event,element,loggedIn) sent={player,loggedIn} end
function getElementType() return 'player' end
function getElementData(player,key) return state.loggedIn end
assert(loadfile('resources/rp_car/speedometer_server.lua'))()
client={};state.loggedIn=true
handlers['car:requestSpeedometerSession']();assert(sent[1]==client and sent[2]==true)
source=client;state.loggedIn=false
handlers.onElementDataChange('auth:loggedIn');assert(sent[2]==false)
print('Server session: 2 checks passed')
