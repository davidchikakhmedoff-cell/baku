dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local handlers,draws,sent={}, {}, {}
root,resourceRoot,localPlayer={}, {}, {}
local sw,sh,now=1920,1080,1000
function getResourceFromName() return {} end
function getResourceState() return 'running' end
function showCursor() end
function guiSetInputMode() end
function guiGetScreenSize() return sw,sh end
function dxCreateFont() return {} end
function destroyElement() end
function isElement(e) return type(e)=='table' end
function addEvent() end
function addEventHandler(name,element,fn) handlers[name]=fn end
function triggerServerEvent(event,element,name,data) sent[#sent+1]={name=name,data=data} end
function tocolor() return 1 end
function getCursorPosition() return false end
function dxDrawRectangle() end
function dxDrawText(value,x,y,right,bottom) draws[#draws+1]={text=value,x=x,y=y,right=right,bottom=bottom} end
function getElementPosition() return 10000,10000,10000 end
function getElementInterior() return 0 end
function getElementDimension() return 0 end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function getScreenFromWorldPosition() return 960,540 end
function getWeaponNameFromID(id) return 'Weapon '..id end
function getTickCount() return now end
function isControlEnabled() return true end
function toggleControl() end
function cancelEvent() end
exports={rp_core={openUI=function() return true end,closeUI=function() end}}
assert(loadfile('resources/rp_fraction/client/main.lua'))()
local payloads={
 invite={inviter='Leader',name='LSPD',seconds=60},duty={name='LSPD',working=false},
 armory={name='LSPD',rank=5,weapons=FractionConfig.policeWeapons},
 members={faction=2,rank=10,rows={{account_id=2,rp_name='Test_Player',rank=2}}},
 news={rows={{id=1,author='Test_Player',original='Original ad',edited='Original ad'}}},
 tickets={rows={{id=1,amount=100,reason='Test ticket'}}}}
for _,size in ipairs({{1920,1080},{1600,900},{1366,768},{1280,720}}) do
 sw,sh=size[1],size[2]
 for name,data in pairs(payloads) do
  handlers['fraction:menu'](name,data);draws={};handlers.onClientRender()
  for _,d in ipairs(draws) do assert(d.x>=0 and d.y>=0 and d.right<=sw and d.bottom<=sh,name..' must fit screen') end
 end
end
sw,sh=1920,1080
handlers['fraction:menu']('invite',payloads.invite);handlers.onClientRender()
local x,y=(sw-700)/2,(sh-540)/2
handlers.onClientClick('left','down',x+30,y+220)
assert(sent[#sent].name=='accept','invite accept button sends server confirmation')
handlers['fraction:menu']('news',payloads.news);handlers.onClientRender()
handlers.onClientClick('left','down',x+30,y+60)
handlers.onClientClick('left','down',x+30,y+350)
handlers.onClientCharacter('!');handlers.onClientRender()
handlers.onClientClick('left','down',x+30,y+425)
assert(sent[#sent].name=='publish' and sent[#sent].data.text=='Original ad!','edited ad submitted to server')
handlers['fraction:megaphone']({},'Megaphone test');handlers.onClientKey('escape',true)
now=1001;draws={};handlers.onClientRender();local found=false
for _,d in ipairs(draws) do if d.text=='Megaphone test' then found=true end end;assert(found,'megaphone appears')
now=12000;draws={};handlers.onClientRender()
for _,d in ipairs(draws) do assert(d.text~='Megaphone test','megaphone expires after 10 seconds') end
print('Fraction UI: six windows at four resolutions, invite, news editing and megaphone expiry passed')
