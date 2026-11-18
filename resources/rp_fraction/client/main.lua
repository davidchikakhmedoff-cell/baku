local window,data,selected,scroll,input,edit=nil,{},nil,0,nil,''
local hits,alpha={},0
local stopping=false
local screenW,screenH=guiGetScreenSize()
local scale=math.min(screenW/1920,screenH/1080)
local titleFont=dxCreateFont(':rp_core/CompactC.ttf',math.max(11,math.floor(15*scale)),false,'antialiased')
local megaphones={}
local function close()
 if window=='keys' and not stopping then triggerServerEvent('fraction:action',resourceRoot,'keysClose',{}) end
 window=nil;input=nil;edit='';selected=nil;scroll=0
 local core=getResourceFromName('rp_core')
 if core and getResourceState(core)=='running' then exports.rp_core:closeUI('fraction') else showCursor(false);guiSetInputMode('allow_binds') end
end
local function action(name,payload) triggerServerEvent('fraction:action',resourceRoot,name,payload or {}) end
addEvent('fraction:state',true)
addEventHandler('fraction:state',resourceRoot,function() if window and window~='invite' then close() end end)
addEvent('fraction:closeKeys',true)
addEventHandler('fraction:closeKeys',resourceRoot,function() if window=='keys' then close() end end)
addEvent('fraction:menu',true)
addEventHandler('fraction:menu',resourceRoot,function(kind,payload)
 if not exports.rp_core:openUI('fraction',true,'no_binds_when_editing') then return end
 local oldSlot=window=='keys' and kind=='keys' and selected and data.rows[selected] and data.rows[selected].slot
 local same=window=='keys' and kind=='keys'
 window,data=kind,payload or {};selected=nil;if not same then scroll=0;alpha=0 end;input=nil;edit=''
 if oldSlot then for i,row in ipairs(data.rows or {}) do if row.slot==oldSlot then selected=i end end end
end)
addEvent('fraction:megaphone',true)
addEventHandler('fraction:megaphone',resourceRoot,function(vehicle,text) if isElement(vehicle) and type(text)=='string' then megaphones[vehicle]={text=text,untilTick=getTickCount()+FractionConfig.megaphone.durationMs} end end)
local cuffSnapshot
local controls=FractionConfig.cuffControls
addEvent('fraction:cuff',true)
addEventHandler('fraction:cuff',resourceRoot,function(enabled)
 if enabled and not cuffSnapshot then
  cuffSnapshot={};for _,name in ipairs(controls) do cuffSnapshot[name]=isControlEnabled(name);toggleControl(name,false) end
 elseif not enabled and cuffSnapshot then
  for name,wasEnabled in pairs(cuffSnapshot) do toggleControl(name,wasEnabled) end;cuffSnapshot=nil
 end
end)
local function text(value,x,y,w,h,color,font,align)
 dxDrawText(tostring(value or ''),math.floor(x),math.floor(y),math.floor(x+w),math.floor(y+h),color or tocolor(245,245,245,alpha),1,font or 'default-bold',align or 'left','center',true,false,false,false,false)
end
local function button(id,label,x,y,w,h)
 local cx,cy=getCursorPosition();cx,cy=(cx or -1)*screenW,(cy or -1)*screenH
 local hover=cx>=x and cx<=x+w and cy>=y and cy<=y+h
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,alpha));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(hover and 20 or 14,hover and 20 or 14,hover and 20 or 14,alpha))
 text(label,x+4,y,w-8,h,nil,nil,'center');hits[#hits+1]={id=id,x=x,y=y,w=w,h=h}
end
local function renderMenu()
 if not window then return end
 alpha=math.min(255,alpha+22)
 local function s(v) return math.floor(v*scale+0.5) end
 local w,h=s(700),s(540);local x,y=math.floor((screenW-w)/2),math.floor((screenH-h)/2)
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230*alpha/255));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130*alpha/255))
 hits={};local titles={invite='ПРИГЛАШЕНИЕ',members='СОСТАВ ФРАКЦИИ',duty='РАБОЧАЯ СМЕНА',armory='ОРУЖЕЙНАЯ',news='LS NEWS — ОБЪЯВЛЕНИЯ',tickets='НЕОПЛАЧЕННЫЕ ШТРАФЫ',keys='КЛЮЧИ СЛУЖЕБНОГО ТРАНСПОРТА'}
 text(titles[window],x+s(18),y+s(8),w-s(36),s(32),nil,titleFont or 'default-bold')
 if window=='invite' then
  text(data.inviter..' приглашает вас в '..data.name,x+s(20),y+s(80),w-s(40),s(50))
  text('Приглашение действует '..data.seconds..' сек.',x+s(20),y+s(140),w-s(40),s(35))
  button('accept','Принять',x+s(20),y+s(210),s(300),s(36));button('decline','Отклонить',x+s(340),y+s(210),s(300),s(36))
 elseif window=='duty' then
  text(data.name,x+s(20),y+s(70),w-s(40),s(35))
  button('duty',data.working and 'Завершить работу' or 'Начать работу',x+s(20),y+s(140),w-s(40),s(40))
 elseif window=='armory' then
  local yy=y+s(65)
  for _,weapon in ipairs(data.weapons or {}) do
   text((weapon.rank<=data.rank and '✓ ' or '— ')..getWeaponNameFromID(weapon.id)..' | '..weapon.ammo..' патр. | ранг '..weapon.rank,x+s(20),yy,w-s(40),s(30));yy=yy+s(34)
  end
  button('armory','Получить комплект',x+s(20),y+h-s(100),w-s(40),s(36))
 else
  local rows=data.rows or {};local yy=y+s(52)
  for i=scroll+1,math.min(#rows,scroll+7) do
   local row=rows[i];local label
   if window=='members' then label=row.rp_name..' | аккаунт '..row.account_id..' | '..Fractions[data.faction].ranks[tonumber(row.rank)]
   elseif window=='news' then label='#'..row.id..' '..row.author..': '..row.original
   elseif window=='keys' then label=row.name..' | ранг '..row.rank..' | '..(row.holder and ('Ключи: '..row.holder..(row.mine and ' (вы)' or '')) or (row.available and 'Свободен' or 'Возвращается / недоступен'))
   else label='#'..row.id..' | $'..row.amount..' | '..row.reason end
   if selected==i then dxDrawRectangle(x+s(16),yy,w-s(32),s(32),tocolor(47,80,100,alpha)) end
   text(label,x+s(22),yy,w-s(44),s(32));hits[#hits+1]={id='row:'..i,x=x+s(16),y=yy,w=w-s(32),h=s(32)};yy=yy+s(35)
  end
  text('Строки '..math.min(#rows,scroll+1)..'–'..math.min(#rows,scroll+7)..' / '..#rows..'  • колесо мыши',x+s(20),y+s(301),w-s(40),s(25),tocolor(155,163,173,alpha))
  if window=='members' then
   text('/invite ID   •   /uninvite ID   •   /giverank ID ранг',x+s(20),y+s(350),w-s(40),s(35))
   text('Управление составом — через команды лидера и заместителя',x+s(20),y+s(390),w-s(40),s(35))
  elseif window=='keys' then
   text(data.hasKey and 'У вас уже есть ключи. Сдайте их перед выбором другого транспорта.' or 'Выберите свободный транспорт по вашему рангу.',x+s(20),y+s(340),w-s(40),s(35))
   button('keysTake','Взять ключи',x+s(20),y+s(395),s(205),s(36))
   button('keysReturn','Сдать ключи',x+s(240),y+s(395),s(205),s(36))
   button('keysRefresh','Обновить',x+s(460),y+s(395),s(220),s(36))
  elseif window=='news' then
   button('edit',edit~='' and edit or 'Нажмите для редактирования текста',x+s(20),y+s(340),w-s(40),s(60))
   button('publish','Опубликовать',x+s(20),y+s(415),s(305),s(34));button('reject','Отклонить',x+s(345),y+s(415),s(305),s(34))
  elseif window=='tickets' then button('payticket','Оплатить выбранный штраф',x+s(20),y+s(380),w-s(40),s(36)) end
 end
 button('close','Закрыть',x+w-s(150),y+h-s(45),s(130),s(30))
end
local markerLabels={}
local function addMarkerLabel(text,p,interior,dimension)
 if p then markerLabels[#markerLabels+1]={text=text,p=p,interior=interior,dimension=dimension} end
end
for _,f in pairs(Fractions) do
 addMarkerLabel(f.name,f.entrance,0,0)
 addMarkerLabel('Выход',f.exit,f.interior,f.dimension)
 addMarkerLabel('Ключи транспорта',f.keysPoint,f.interior,f.dimension)
 if f.duty then addMarkerLabel('Начать / завершить смену',f.dutyPoint,f.interior,f.dimension) end
 addMarkerLabel('Оружейная',f.armory,f.interior,f.dimension)
 if f.roof and f.roof.outside then
  addMarkerLabel('На крышу',f.roof.inside,f.interior,f.dimension)
  addMarkerLabel('В интерьер',f.roof.outside,0,0)
 end
end
local function drawMarkerLabels(px,py,pz)
 local cfg=FractionConfig.markerLabel;local interior,dimension=getElementInterior(localPlayer),getElementDimension(localPlayer)
 for _,label in ipairs(markerLabels) do
  local p=label.p
  if interior==label.interior and dimension==label.dimension and (px-p.x)^2+(py-p.y)^2+(pz-p.z)^2<=cfg.distance^2 then
   local x,y=getScreenFromWorldPosition(p.x,p.y,p.z+cfg.zOffset)
   if x and y then
    local half=300*scale;local height=14*scale
    for ox=-1,1 do for oy=-1,1 do if ox~=0 or oy~=0 then
     dxDrawText(label.text,x-half+ox,y-height+oy,x+half+ox,y+height+oy,tocolor(unpack(cfg.outlineColor)),cfg.scale,cfg.font,'center','center',true)
    end end end
    dxDrawText(label.text,x-half,y-height,x+half,y+height,tocolor(unpack(cfg.color)),cfg.scale,cfg.font,'center','center',true)
   end
  end
 end
end
addEventHandler('onClientRender',root,function()
 local w,h=guiGetScreenSize()
 if w~=screenW or h~=screenH then
  screenW,screenH=w,h;scale=math.min(w/1920,h/1080)
  if isElement(titleFont) then destroyElement(titleFont) end
  titleFont=dxCreateFont(':rp_core/CompactC.ttf',math.max(11,math.floor(15*scale)),false,'antialiased')
 end
 local px,py,pz=getElementPosition(localPlayer)
 drawMarkerLabels(px,py,pz)
 for vehicle,message in pairs(megaphones) do
  if not isElement(vehicle) or getTickCount()>message.untilTick then megaphones[vehicle]=nil
  elseif getElementDimension(vehicle)==getElementDimension(localPlayer) and getElementInterior(vehicle)==getElementInterior(localPlayer) then
   local vx,vy,vz=getElementPosition(vehicle);local x,y=getScreenFromWorldPosition(vx,vy,vz+2.3)
   if x and getDistanceBetweenPoints3D(px,py,pz,vx,vy,vz)<FractionConfig.megaphone.range then text(message.text,x-250,y,500,35,tocolor(240,220,100),nil,'center') end
  end
 end
 renderMenu()
end)
addEventHandler('onClientClick',root,function(key,state,cx,cy)
 if key~='left' or state~='down' or not window then return end
 for _,box in ipairs(hits) do if cx>=box.x and cx<=box.x+box.w and cy>=box.y and cy<=box.y+box.h then
  local id=box.id
  if id:sub(1,4)=='row:' then selected=tonumber(id:sub(5));if window=='news' then edit=data.rows[selected].edited or data.rows[selected].original end
  elseif id=='edit' then input=true
  elseif id=='close' then if window=='invite' then action('decline') end;close()
  elseif id=='keysTake' then if selected then action(id,{slot=data.rows[selected].slot}) end
  elseif id=='keysReturn' or id=='keysRefresh' then action(id)
  elseif id=='publish' or id=='reject' then if selected then action(id,{id=data.rows[selected].id,text=edit}) end
  elseif id=='payticket' then if selected then action(id,{id=data.rows[selected].id}) end
  else action(id);close() end
  return
 end end
end)
addEventHandler('onClientCharacter',root,function(char)
 if not window or not input then return end
 if #edit<FractionConfig.textLimit*4 and not char:find('[%c]') then edit=edit..char end
end)
addEventHandler('onClientKey',root,function(key,down)
 if not down or not window then return end
 if key=='escape' then cancelEvent();close()
 elseif key=='backspace' and input then edit=utf8 and utf8.sub and utf8.sub(edit,1,-2) or edit:sub(1,-2);cancelEvent()
 elseif key=='mouse_wheel_down' then scroll=math.min(math.max(0,#(data.rows or {})-7),scroll+1);cancelEvent()
 elseif key=='mouse_wheel_up' then scroll=math.max(0,scroll-1);cancelEvent()
 elseif key=='enter' and input then input=false;cancelEvent()
 elseif input and not key:find('mouse_',1,true) then cancelEvent() end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 stopping=true;close();if isElement(titleFont) then destroyElement(titleFont) end
 if cuffSnapshot then for name,enabled in pairs(cuffSnapshot) do toggleControl(name,enabled) end end
end)
