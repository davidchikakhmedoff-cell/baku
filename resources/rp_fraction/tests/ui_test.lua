dofile('resources/rp_fraction/skins/config.lua')
dofile('resources/rp_fraction/skins/client.lua')
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
function dxGetTextWidth(text) return #text*7 end
function dxGetFontHeight() return 16 end
function dxDrawText(value,x,y,right,bottom,color,size,font) draws[#draws+1]={text=value,x=x,y=y,right=right,bottom=bottom,color=color,size=size,font=font} end
function getElementPosition() return unpack(position) end
function getElementInterior() return 0 end
function getElementDimension() return 0 end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function getScreenFromWorldPosition() return 960,540 end
function getWeaponNameFromID(id) return 'Weapon '..id end
function getTickCount() return now end
local controlState={}
function isControlEnabled(name) return controlState[name]~=false end
function toggleControl(name,state) controlState[name]=state end
function getElementData() return false end
function cancelEvent() end
exports={rp_core={openUI=function() return true end,closeUI=function() end}}
assert(loadfile('resources/rp_fraction/client/main.lua'))()
controlState.enter_exit=false
handlers['fraction:cuff'](true,{enter_exit=true,fire=true,jump=false})
handlers['fraction:cuff'](false,{enter_exit=true,fire=true,jump=false})
assert(controlState.enter_exit and controlState.fire and not controlState.jump,'uncuff restores authoritative states, including F, rather than the already blocked client snapshot')
local payloads={
 invite={inviter='Leader',name='LSPD',seconds=60},duty={name='LSPD',working=false},
 armory={name='LSPD',rank=5,weapons=FractionConfig.policeWeapons},
 wardrobe={title='ГАРДЕРОБ LSPD',subtitle='Выберите служебную форму',token=123,current=281,rows=SkinConfig.list(2,'male',3)},
 members={faction=2,rank=10,rows={{account_id=2,rp_name='Test_Player',rank=2}}},
 news={rows={{id=1,author='Test_Player',original='Original ad',edited='Original ad'}}},
 ticket={id=11,amount=250,reason='Test fine reason'},
 tickets={rows={{id=1,amount=100,reason='Test ticket'}}},
 keys={name='LSPD',rows={{slot=7,name='Maverick №7',rank=9,available=true,holder='Holder_Name',mine=false}}}}
for _,size in ipairs({{1920,1080},{1600,900},{1366,768},{1280,720}}) do
 sw,sh=size[1],size[2]
 for name,data in pairs(payloads) do
  handlers['fraction:menu'](name,data);draws={};handlers.onClientRender()
  for _,d in ipairs(draws) do assert(d.x>=0 and d.y>=0 and d.right<=sw and d.bottom<=sh,name..' must fit screen') end
  if name=='members' then
   local rank,nickname,title,close
   for _,d in ipairs(draws) do
    if d.text=='Офицер' then rank=d end
    if d.text=='Test_Player' then nickname=d end
    if d.text=='СОСТАВ ФРАКЦИИ' then title=d end
    if d.text=='Закрыть' then close=d end
    assert(not d.text:find('аккаунт',1,true) and not d.text:find('/invite',1,true) and not d.text:find('Управление составом',1,true) and not d.text:find('Строки',1,true),'members has no account numbers or footer hints')
   end
   assert(rank and nickname and rank.y==nickname.y and nickname.x>rank.right and nickname.x-rank.right<=20,'members shows rank then nickname with a small gap')
   assert(title.right-title.x<600 and close.bottom-title.y>350 and close.bottom-title.y<650,'members uses a narrow vertical list window')
  end
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
handlers['fraction:menu']('duty',{working=true,wardrobe=true});draws={};handlers.onClientRender()
clickText('Сменить одежду');assert(sent[#sent].name=='wardrobeOpen','on-duty LSPD marker offers changing clothes')
handlers['fraction:menu']('wardrobe',payloads.wardrobe);draws={};handlers.onClientRender()
local equipped=false;for _,d in ipairs(draws) do if d.text:find('Надето',1,true) and d.text:find('281',1,true) then equipped=true end end
assert(equipped,'current uniform has equipped status')
clickText('Полицейская форма');clickText('Надеть')
assert(sent[#sent].name=='wardrobeWear' and sent[#sent].data.model==280 and sent[#sent].data.token==123,'wardrobe sends selected model and server token')
clickText('Закрыть');assert(sent[#sent].name=='wardrobeClose' and sent[#sent].data.token==123,'closing wardrobe releases only its own session')
handlers['fraction:menu']('ticket',payloads.ticket);draws={};handlers.onClientRender()
local amountShown,reasonShown=false,false
for _,d in ipairs(draws) do
 if d.text=='Сумма: $250' then amountShown=true end
 if d.text=='Причина: Test fine reason' then reasonShown=true end
end
assert(amountShown and reasonShown,'fine window displays persisted amount and reason')
local top,bottom
for _,d in ipairs(draws) do if d.text=='ШТРАФ' then top=d.y end;if d.text=='Закрыть' then bottom=d.bottom end end
assert(bottom-top<170,'short fine reason uses compact window without empty area')
clickText('Оплатить');assert(sent[#sent].name=='payticket' and sent[#sent].data.id==11,'fine button pays only shown ticket ID')
handlers['fraction:ticketPaid'](99);draws={};handlers.onClientRender();assert(#draws>0,'unrelated payment does not close fine window')
handlers['fraction:ticketPaid'](11);draws={};handlers.onClientRender();assert(#draws==0,'successful fine payment closes window')
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
local wardrobe={title='ГАРДЕРОБ LSPD',token=124,current=280,rows={}}
for i=1,12 do wardrobe.rows[i]={model=270+i,name='Uniform '..i,minRank=1} end
handlers['fraction:menu']('wardrobe',wardrobe);draws={};handlers.onClientRender()
handlers.onClientKey('mouse_wheel_down',true);draws={};handlers.onClientRender()
local eighth=false;for _,d in ipairs(draws) do if d.text:find('Uniform 8 |',1,true) then eighth=true end end
assert(eighth,'wardrobe supports mouse wheel scrolling')
handlers.onClientClick('left','down',1276,445)
handlers.onClientCursorMove(0,0,1276,640)
handlers.onClientClick('left','up',1276,640)
draws={};handlers.onClientRender();local last=false
for _,d in ipairs(draws) do if d.text:find('Uniform 12 |',1,true) then last=true end end
assert(last,'wardrobe scrollbar reaches final configured form')
handlers.onClientKey('escape',true)
local members={faction=2,rows={}}
for i=1,35 do members.rows[i]={rank=2,rp_name='Member_'..i} end
local function memberVisible(name)
 for _,d in ipairs(draws) do if d.text==name then return true end end
 return false
end
handlers['fraction:menu']('members',members);draws={};handlers.onClientRender()
assert(memberVisible('Member_1') and memberVisible('Member_17') and not memberVisible('Member_18'),'members shows 17 rows like TAB')
handlers.onClientKey('mouse_wheel_down',true);draws={};handlers.onClientRender()
assert(not memberVisible('Member_1') and memberVisible('Member_18'),'wheel scrolls the members list')
for i=1,50 do handlers.onClientKey('mouse_wheel_down',true) end
draws={};handlers.onClientRender()
assert(memberVisible('Member_19') and memberVisible('Member_35') and not memberVisible('Member_18'),'wheel stops at the last complete page')
handlers['fraction:menu']('members',members);draws={};handlers.onClientRender()
handlers.onClientClick('left','down',1215,260)
handlers.onClientCursorMove(0,0,1215,803)
handlers.onClientClick('left','up',1215,803)
draws={};handlers.onClientRender()
assert(memberVisible('Member_35') and not memberVisible('Member_1'),'right scrollbar reaches final member')
handlers.onClientKey('escape',true)
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

handlers['fraction:menu']('selfHeal',{price=250});draws={};handlers.onClientRender()
local healing,cancel,message
for _,d in ipairs(draws) do
 if d.text=='Лечиться' then healing=d elseif d.text=='Отмена' then cancel=d elseif d.text=='Самолечение на стойке стоит 250$.' then message=d end
end
assert(healing and cancel and message,'compact desk menu shows server price and both requested buttons')
handlers.onClientClick('left','down',(healing.x+healing.right)/2,(healing.y+healing.bottom)/2)
assert(sent[#sent].name=='selfHeal','healing button invokes server action without client-supplied price or health')
handlers['fraction:closeSelfHeal']();draws={};handlers.onClientRender()
for _,d in ipairs(draws) do assert(d.text~='САМОЛЕЧЕНИЕ','successful payment closes healing window') end
