-- Render through the existing faction window's exact text/button helpers.
-- No fonts, GUI windows or temporary world elements are created here.
WardrobeClient={}
local C=WardrobeClient
local token,selected
function C.open(data)
 token=data.token;selected=1
 for index,row in ipairs(data.rows or {}) do if row.model==data.current then selected=index;break end end
end
function C.close(notify)
 if token and notify~=false then triggerServerEvent('fraction:action',resourceRoot,'wardrobeClose',{token=token}) end
 token,selected=nil,nil
end
function C.click(id,data)
 local index=tonumber(id:match('^wardrobeRow:(%d+)$'))
 if index then if data.rows[index] then selected=index end;return true end
 if id=='wardrobeWear' then
  local row=data.rows and data.rows[selected or 0]
  if row then triggerServerEvent('fraction:action',resourceRoot,'wardrobeWear',{token=token,model=row.model}) end
  return true
 end
 return false
end
function C.render(data,ui)
 local s=ui.s;local rows=data.rows or {};local visible=math.min(7,#rows)
 local w,h=s(660),s(visible*32+118)
 local x,y=math.floor((ui.width-w)/2),math.floor((ui.height-h)/2)
 dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230));dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130))
 ui.text(data.title or 'ГАРДЕРОБ',x+s(10),y+s(2),w-s(20),s(30),nil,ui.font)
 ui.text(data.subtitle or 'Выберите служебную форму',x+s(16),y+s(32),w-s(32),s(26))
 local scroll=math.max(0,math.min(ui.scroll,math.max(0,#rows-7)))
 for index=scroll+1,math.min(#rows,scroll+7) do
  local row=rows[index];local yy=y+s(65+(index-scroll-1)*32);local picked=selected==index
  dxDrawRectangle(x+s(10),yy,w-s(30),s(30),tocolor(picked and 29 or 14,picked and 35 or 14,picked and 42 or 14,255))
  local status=row.model==data.current and ' | Надето' or (picked and ' | Выбрано' or '')
  ui.text(row.name..' | Скин: '..row.model..' | С '..row.minRank..' ранга'..status,x+s(16),yy,w-s(42),s(30))
  ui.hit('wardrobeRow:'..index,x+s(10),yy,w-s(30),s(30))
 end
 local trackH=s(visible*32);local tx,ty=x+w-s(15),y+s(65);local bar
 dxDrawRectangle(tx,ty,s(5),trackH,tocolor(69,74,76,255))
 if #rows>7 then
  local thumb=math.max(s(24),trackH*7/#rows)
  dxDrawRectangle(tx,ty+(trackH-thumb)*scroll/(#rows-7),s(5),thumb,tocolor(245,245,245,255))
  bar={x=tx,y=ty,w=s(10),h=trackH,thumb=thumb,max=#rows-7}
 end
 local bw=(w-s(28))/2
 ui.button('wardrobeWear','Надеть',x+s(10),y+h-s(40),bw,s(30))
 ui.button('close','Закрыть',x+s(18)+bw,y+h-s(40),bw,s(30))
 return scroll,bar
end
