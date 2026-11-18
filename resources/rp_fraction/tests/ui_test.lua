dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local handlers,draws,sent={}, {}, {}
root,resourceRoot,localPlayer={}, {}, {}
local sw,sh,now=1920,1080,1000
local position={10000,10000,10000}
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
function tocolor(r,g,b,a) return r*1000000+g*1000+b end
function getCursorPosition() return false end
function dxDrawRectangle() end
function dxDrawText(value,x,y,right,bottom,color,size,font) draws[#draws+1]={text=value,x=x,y=y,right=right,bottom=bottom,color=color,size=size,font=font} end
function getElementPosition() return unpack(position) end
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
 tickets={rows={{id=1,amount=100,reason='Test ticket'}}},
 keys={name='LSPD',rows={{slot=7,name='Maverick №7',rank=9,available=true,holder='Holder_Name',mine=false}}}}
for _,size in ipairs({{1920,1080},{1600,900},{1366,768},{1280,720}}) do
 sw,sh=size[1],size[2]
 for name,data in pairs(payloads) do
  handlers['fraction:menu'](name,data);draws={};handlers.onClientRender()
  for _,d in ipairs(draws) do assert(d.x>=0 and d.y>=0 and d.right<=sw and d.bottom<=sh,name..' must fit screen') end
  if name=='duty' then
   local question=false
   for _,d in ipairs(draws) do
    if d.text=='Начать работу?' then question=true end
    assert(d.text~=data.name,'shift prompt replaces faction name')
    if d.text=='Начать работу' then assert(d.x<sw/2 and d.right-d.x<200,'short start button stays on left') end
   end
   assert(question,'shift window asks whether to start work')
  end
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
local function clickText(needle)
 for _,d in ipairs(draws) do if d.text:find(needle,1,true) then handlers.onClientClick('left','down',(d.x+d.right)/2,(d.y+d.bottom)/2);return end end
 error('missing UI text '..needle)
end
handlers['fraction:menu']('armory',payloads.armory);draws={};handlers.onClientRender()
clickText('Дубинка');clickText('Получить')
assert(sent[#sent].name=='armory' and #sent[#sent].data.weapons==1 and sent[#sent].data.weapons[1]==3,'weapon selector submits only selected weapon')
handlers['fraction:closeArmory']();draws={};handlers.onClientRender();assert(#draws==0,'successful armory response closes window')
handlers['fraction:menu']('armory',payloads.armory);draws={};handlers.onClientRender()
clickText('Бронежилет');clickText('Получить')
assert(sent[#sent].data.weapons[1]=='armor','armor selector submits item ID without numeric coercion')
handlers['fraction:closeArmory']()
handlers['fraction:menu']('keys',payloads.keys);draws={};handlers.onClientRender()
clickText('Holder_Name');clickText('Получить')
assert(sent[#sent].name=='keysTake' and sent[#sent].data.slot==7,'key request sends stable configured vehicle slot')
clickText('Сдать ключи');assert(sent[#sent].name=='keysReturn','return-key button uses server action')
handlers['fraction:closeKeys']();draws={};handlers.onClientRender();assert(#draws==0,'successful key response closes window')
local many={rows={}};for i=1,12 do many.rows[i]={slot=i,name='Car '..i,available=true} end
handlers['fraction:menu']('keys',many);handlers.onClientRender()
handlers.onClientClick('left','down',1276,430)
handlers.onClientCursorMove(0,0,1276,640)
handlers.onClientClick('left','up',1276,640)
draws={};handlers.onClientRender();local bottom=false
for _,d in ipairs(draws) do if d.text:find('Car 12',1,true) then bottom=true end end
assert(bottom,'dragging right scrollbar reaches end of key list')
handlers['fraction:closeKeys']()
handlers['fraction:megaphone']({},'Megaphone test');handlers.onClientKey('escape',true)
now=1001;draws={};handlers.onClientRender();local found=false
for _,d in ipairs(draws) do if d.text=='Megaphone test' then found=true end end;assert(found,'megaphone appears')
now=12000;draws={};handlers.onClientRender()
for _,d in ipairs(draws) do assert(d.text~='Megaphone test','megaphone expires after 10 seconds') end
for _,f in pairs(Fractions) do
 position={f.entrance.x,f.entrance.y,f.entrance.z};draws={};handlers.onClientRender()
 local count=0
 for _,d in ipairs(draws) do if d.text==f.name then
  count=count+1;assert(d.font=='default-bold' and d.size==1,'faction labels match house font and scale')
  if count==9 then assert(d.color==tocolor(0,190,255,255),'all factions use house cyan, not faction color') end
 end end
 assert(count==9,'house-style eight-direction outline and single text pass')
end
print('Fraction UI: seven windows, keys and holder names, four resolutions, house-style labels, invite/news and megaphone passed')
