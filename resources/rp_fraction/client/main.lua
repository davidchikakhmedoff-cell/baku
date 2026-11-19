local window,data,selected,scroll,input,edit=nil,{},nil,0,nil,''
local hits,alpha={},255
local weaponSelection={}
local stopping=false
local scrollBar,dragging=nil,false
local screenW,screenH=guiGetScreenSize()
local scale=math.min(screenW/1920,screenH/1080)
local titleFont=dxCreateFont(':rp_core/CompactC.ttf',math.max(11,math.floor(13*1.05*scale+0.5)),false,'cleartype')
local megaphones={}
local function close()
 if window=='keys' and not stopping then triggerServerEvent('fraction:action',resourceRoot,'keysClose',{}) end
 dragging=false;scrollBar=nil
 window=nil;input=nil;edit='';selected=nil;scroll=0
 local core=getResourceFromName('rp_core')
 if core and getResourceState(core)=='running' then exports.rp_core:closeUI('fraction') else showCursor(false);guiSetInputMode('allow_binds') end
end
local function action(name,payload) triggerServerEvent('fraction:action',resourceRoot,name,payload or {}) end
addEvent('fraction:state',true)
addEventHandler('fraction:state',resourceRoot,function() if window and window~='invite' then close() end end)
addEvent('fraction:ticketPaid',true)
addEventHandler('fraction:ticketPaid',resourceRoot,function(id)
 if window=='ticket' and tonumber(data.id)==tonumber(id) then close()
 elseif window=='tickets' then
  for index=#(data.rows or {}),1,-1 do if tonumber(data.rows[index].id)==tonumber(id) then table.remove(data.rows,index) end end
  selected=nil
 end
end)
addEvent('fraction:closeArmory',true)
addEventHandler('fraction:closeArmory',resourceRoot,function() if window=='armory' then close() end end)
addEvent('fraction:closeKeys',true)
addEventHandler('fraction:closeKeys',resourceRoot,function() if window=='keys' then close() end end)
addEvent('fraction:menu',true)
addEventHandler('fraction:menu',resourceRoot,function(kind,payload)
 if not exports.rp_core:openUI('fraction',true,'no_binds_when_editing') then return end
 local oldSlot=window=='keys' and kind=='keys' and selected and data.rows[selected] and data.rows[selected].slot
 local same=window=='keys' and kind=='keys'
 if kind=='armory' then weaponSelection={} end
 window,data=kind,payload or {};selected=nil;if not same then scroll=0;alpha=255 end;input=nil;edit=''
 if oldSlot then for i,row in ipairs(data.rows or {}) do if row.slot==oldSlot then selected=i end end end
end)
addEvent('fraction:megaphone',true)
addEventHandler('fraction:megaphone',resourceRoot,function(vehicle,text) if isElement(vehicle) and type(text)=='string' then megaphones[vehicle]={text=text,untilTick=getTickCount()+FractionConfig.megaphone.durationMs} end end)
local cuffSnapshot
local controls=FractionConfig.cuffControls
addEvent('fraction:cuff',true)
addEventHandler('fraction:cuff',resourceRoot,function(enabled,serverControls)
 if enabled then
  -- The server captured these states before disabling them. Reading local
  -- controls now would save the already disabled enter/exit key as false.
  cuffSnapshot=serverControls or cuffSnapshot or {}
  for _,name in ipairs(controls) do toggleControl(name,false) end
 elseif cuffSnapshot or serverControls then
  for name,wasEnabled in pairs(serverControls or cuffSnapshot) do
   if not getElementData(localPlayer,'admin:frozen') then toggleControl(name,wasEnabled) end
  end
  cuffSnapshot=nil
 end
end)
addEventHandler('onClientResourceStart',resourceRoot,function()
 triggerServerEvent('fraction:syncCuffs',resourceRoot)
end)
local function text(value,x,y,w,h,color,font,align)
 dxDrawText(tostring(value or ''),math.floor(x),math.floor(y),math.floor(x+w),math.floor(y+h),color or tocolor(245,245,245,alpha),1,font or 'default-bold',align or 'left','center',true,false,false,false,false)
end
local function button(id,label,x,y,w,h)
 local cx,cy=getCursorPosition();cx,cy=(cx or -1)*screenW,(cy or -1)*screenH
 local hover=cx>=x and cx<=x+w and cy>=y and cy<=y+h
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,alpha));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(hover and 17 or 14,hover and 17 or 14,hover and 17 or 14,alpha))
 dxDrawRectangle(x+3,y+1,w-6,1,tocolor(18,18,18,255));dxDrawRectangle(x+3,y+h-2,w-6,1,tocolor(5,5,5,255))
 text(label,x+4,y,w-8,h,nil,nil,'center');hits[#hits+1]={id=id,x=x,y=y,w=w,h=h}
end
local function visibleRows() return window=='members' and 17 or 7 end
local function renderMenu()
 if not window then return end
 alpha=255;scrollBar=nil
 local function s(v) return math.floor(v*scale+0.5) end
 if window=='ticket' then
  local w=s(420)
  local reason='Причина: '..tostring(data.reason or '')
  local lineWidth,lineCount=0,1
  for word in reason:gmatch('%S+') do
   local width=dxGetTextWidth(word..' ',1,'default-bold')
   if lineWidth>0 and lineWidth+width>w-s(24) then lineCount=lineCount+1;lineWidth=0 end
   lineWidth=lineWidth+width
  end
  local reasonHeight=math.ceil(dxGetFontHeight(1,'default-bold')*lineCount)
  local h=s(112)+reasonHeight;local x,y=math.floor((screenW-w)/2),math.floor((screenH-h)/2)
  dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130))
  hits={}
  text('ШТРАФ',x+s(10),y+s(2),w-s(20),s(30),nil,titleFont)
  text('Сумма: $'..tostring(data.amount),x+s(12),y+s(32),w-s(24),s(26))
  dxDrawText(reason,x+s(12),y+s(66),x+w-s(12),y+s(66)+reasonHeight,tocolor(245,245,245),1,'default-bold','left','top',true,true)
  local bw=(w-s(28))/2
  button('payCurrentTicket','Оплатить',x+s(10),y+h-s(40),bw,s(30))
  button('close','Закрыть',x+s(18)+bw,y+h-s(40),bw,s(30))
  return
 end
 if window=='duty' or window=='armory' or window=='keys' or window=='members' then
  local rows=window=='armory' and (data.weapons or {}) or (data.rows or {})
  local limit=visibleRows()
  local visible=window=='members' and limit or math.min(limit,#rows)
  local w=s(window=='duty' and 340 or (window=='armory' and 480 or (window=='members' and 540 or 660)))
  local h=s(window=='duty' and 130 or (visible*32+88))
  local x,y=math.floor((screenW-w)/2),math.floor((screenH-h)/2)
  dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130))
  hits={};scrollBar=nil
  text(window=='duty' and 'РАБОЧАЯ СМЕНА' or (window=='armory' and 'ОРУЖЕЙНАЯ' or (window=='members' and 'СОСТАВ ФРАКЦИИ' or 'КЛЮЧИ ТРАНСПОРТА')),x+s(10),y+s(2),w-s(20),s(30),nil,titleFont)
  if window=='duty' then
   text(data.working and 'Завершить работу?' or 'Начать работу?',x+s(10),y+s(35),w-s(20),s(30))
   button('duty',data.working and 'Завершить работу' or 'Начать работу',x+s(10),y+h-s(42),s(170),s(30))
   button('close','Закрыть',x+w-s(100),y+h-s(42),s(90),s(30))
  else
   scroll=math.max(0,math.min(scroll,math.max(0,#rows-limit)))
   for i=scroll+1,math.min(#rows,scroll+limit) do
    local row=rows[i];local yy=y+s(35+(i-scroll-1)*32)
    local picked=window=='armory' and weaponSelection[row.id] or ((window=='keys' or window=='members') and selected==i)
    dxDrawRectangle(x+s(10),yy,w-s(30),s(30),tocolor(picked and 29 or 14,picked and 35 or 14,picked and 42 or 14,255))
    if window=='members' then
     local rank=Fractions[data.faction].ranks[tonumber(row.rank)] or ''
     local rankWidth=math.min(math.ceil(dxGetTextWidth(rank,1,'default-bold'))+1,w-s(190))
     text(rank,x+s(16),yy,rankWidth,s(30))
     text(row.rp_name,x+s(16)+rankWidth+s(16),yy,w-rankWidth-s(64),s(30))
    else
     local label=window=='armory' and ((row.name or getWeaponNameFromID(row.id))..(row.armor and '' or (' | '..row.ammo..' патр.'))) or (row.name..' | '..(row.holder and ('Ключи: '..row.holder) or (row.available and 'Свободен' or 'Недоступен')))
     text(label,x+s(16),yy,w-s(42),s(30))
    end
    hits[#hits+1]={id=window=='armory' and ('weapon:'..row.id) or ('row:'..i),x=x+s(10),y=yy,w=w-s(30),h=s(30)}
   end
   local trackH=s(visible*32);local tx,ty=x+w-s(15),y+s(35)
   dxDrawRectangle(tx,ty,s(5),trackH,tocolor(69,74,76,255))
   if #rows>limit then
    local thumb=math.max(s(24),trackH*limit/#rows)
    dxDrawRectangle(tx,ty+(trackH-thumb)*scroll/(#rows-limit),s(5),thumb,tocolor(245,245,245,255))
    scrollBar={x=tx,y=ty,w=s(10),h=trackH,thumb=thumb,max=#rows-limit}
   end
   if window=='members' then
    button('close','Закрыть',x+w-s(130),y+h-s(40),s(120),s(30))
   else
    local count=window=='armory' and 2 or 3;local bw=(w-s(20)-s(8)*(count-1))/count
    button(window=='armory' and 'armory' or 'keysTake','Получить',x+s(10),y+h-s(40),bw,s(30))
    if window=='keys' then button('keysReturn','Сдать ключи',x+s(18)+bw,y+h-s(40),bw,s(30)) end
    button('close','Закрыть',x+w-s(10)-bw,y+h-s(40),bw,s(30))
   end
  end
  return
 end
 local w,h=s(700),s(540);local x,y=math.floor((screenW-w)/2),math.floor((screenH-h)/2)
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230*alpha/255));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130*alpha/255))
 dxDrawRectangle(x+s(5),y+s(35),w-s(10),h-s(40),tocolor(0,0,0,255))
 hits={};local titles={invite='ПРИГЛАШЕНИЕ',duty='РАБОЧАЯ СМЕНА',armory='ОРУЖЕЙНАЯ',news='LS NEWS — ОБЪЯВЛЕНИЯ',tickets='НЕОПЛАЧЕННЫЕ ШТРАФЫ',keys='КЛЮЧИ СЛУЖЕБНОГО ТРАНСПОРТА'}
 text(titles[window],x+s(18),y+s(8),w-s(36),s(32),nil,titleFont or 'default-bold')
 if window=='invite' then
  text(data.inviter..' приглашает вас в '..data.name,x+s(20),y+s(80),w-s(40),s(50))
  text('Приглашение действует '..data.seconds..' сек.',x+s(20),y+s(140),w-s(40),s(35))
  button('accept','Принять',x+s(20),y+s(210),s(300),s(36));button('decline','Отклонить',x+s(340),y+s(210),s(300),s(36))
 else
  local rows=data.rows or {};local yy=y+s(52)
  for i=scroll+1,math.min(#rows,scroll+7) do
   local row=rows[i];local label
   if window=='news' then label='#'..row.id..' '..row.author..': '..row.original
   else label='#'..row.id..' | $'..row.amount..' | '..row.reason end
   if selected==i then dxDrawRectangle(x+s(16),yy,w-s(32),s(32),tocolor(47,113,151,255)) end
   if selected==i then
    local bx,by,bw,bh=x+s(7),yy,w-s(20),s(32)
    dxDrawRectangle(bx,by,bw,1,tocolor(195,195,195,255));dxDrawRectangle(bx,by+bh-1,bw,1,tocolor(195,195,195,255))
    dxDrawRectangle(bx,by,1,bh,tocolor(195,195,195,255));dxDrawRectangle(bx+bw-1,by,1,bh,tocolor(195,195,195,255))
   end
   text(label,x+s(22),yy,w-s(44),s(32));hits[#hits+1]={id='row:'..i,x=x+s(16),y=yy,w=w-s(32),h=s(32)};yy=yy+s(35)
  end
  local trackX,trackY,trackH=x+w-s(12),y+s(52),s(245)
  dxDrawRectangle(trackX,trackY,s(6),trackH,tocolor(69,74,76,255))
  if #rows>7 then
   local thumbH=math.max(s(36),trackH*7/#rows)
   dxDrawRectangle(trackX,trackY+(trackH-thumbH)*scroll/(#rows-7),s(6),thumbH,tocolor(255,255,255,255))
  end
  text('Строки '..math.min(#rows,scroll+1)..'–'..math.min(#rows,scroll+7)..' / '..#rows..'  • колесо мыши',x+s(20),y+s(301),w-s(40),s(25),tocolor(155,163,173,alpha))
  if window=='news' then
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
 if f.garage then
  addMarkerLabel('В гараж',f.garage.inside,f.interior,f.dimension)
  addMarkerLabel('В участок',f.garage.outside,0,0)
 end
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
  titleFont=dxCreateFont(':rp_core/CompactC.ttf',math.max(11,math.floor(13*1.05*scale+0.5)),false,'cleartype')
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
 if key=='left' and state=='up' then dragging=false;return end
 if key~='left' or state~='down' or not window then return end
 if scrollBar and cx>=scrollBar.x-3 and cx<=scrollBar.x+scrollBar.w and cy>=scrollBar.y and cy<=scrollBar.y+scrollBar.h then
  dragging=true;scroll=math.floor(math.max(0,math.min(1,(cy-scrollBar.y-scrollBar.thumb/2)/(scrollBar.h-scrollBar.thumb)))*scrollBar.max+0.5);return
 end
 for _,box in ipairs(hits) do if cx>=box.x and cx<=box.x+box.w and cy>=box.y and cy<=box.y+box.h then
  local id=box.id
  if id:sub(1,7)=='weapon:' then
   local weaponId=id:sub(8);if weaponId~='armor' then weaponId=tonumber(weaponId) end
   for _,w in ipairs(data.weapons or {}) do if w.id==weaponId then weaponSelection[weaponId]=not weaponSelection[weaponId] end end
  elseif id=='armory' then
   local chosen={};for _,w in ipairs(data.weapons or {}) do if weaponSelection[w.id] then chosen[#chosen+1]=w.id end end
   if #chosen>0 then action('armory',{weapons=chosen}) end
  elseif id:sub(1,4)=='row:' then selected=tonumber(id:sub(5));if window=='news' then edit=data.rows[selected].edited or data.rows[selected].original end
  elseif id=='edit' then input=true
  elseif id=='close' then if window=='invite' then action('decline') end;close()
  elseif id=='keysTake' then if selected then action(id,{slot=data.rows[selected].slot}) end
  elseif id=='keysReturn' or id=='keysRefresh' then action(id)
  elseif id=='publish' or id=='reject' then if selected then action(id,{id=data.rows[selected].id,text=edit}) end
  elseif id=='payCurrentTicket' then action('payticket',{id=data.id})
  elseif id=='payticket' then if selected then action(id,{id=data.rows[selected].id}) end
  else action(id);close() end
  return
 end end
end)
addEventHandler('onClientCursorMove',root,function(_,_,cx,cy)
 if dragging and scrollBar then scroll=math.floor(math.max(0,math.min(1,(cy-scrollBar.y-scrollBar.thumb/2)/(scrollBar.h-scrollBar.thumb)))*scrollBar.max+0.5) end
end)
addEventHandler('onClientCharacter',root,function(char)
 if not window or not input then return end
 if #edit<FractionConfig.textLimit*4 and not char:find('[%c]') then edit=edit..char end
end)
addEventHandler('onClientKey',root,function(key,down)
 if not down or not window then return end
 if key=='escape' then cancelEvent();close()
 elseif key=='backspace' and input then edit=utf8 and utf8.sub and utf8.sub(edit,1,-2) or edit:sub(1,-2);cancelEvent()
 elseif key=='mouse_wheel_down' then scroll=math.min(math.max(0,#(window=='armory' and (data.weapons or {}) or (data.rows or {}))-visibleRows()),scroll+1);cancelEvent()
 elseif key=='mouse_wheel_up' then scroll=math.max(0,scroll-1);cancelEvent()
 elseif key=='enter' and input then input=false;cancelEvent()
 elseif input and not key:find('mouse_',1,true) then cancelEvent() end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 stopping=true;close();if isElement(titleFont) then destroyElement(titleFont) end
 if cuffSnapshot and not getElementData(localPlayer,'admin:frozen') then for name,enabled in pairs(cuffSnapshot) do toggleControl(name,enabled) end end
end)
