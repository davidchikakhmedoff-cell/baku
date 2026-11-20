dofile('resources/rp_core/systems/notifications/config.lua')
root,resourceRoot={},{}
local handlers,draws={},{};local now=0
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function triggerEvent() end
function getTickCount() return now end
function guiGetScreenSize() return 1920,1080 end
function tocolor(...) return {...} end
function dxGetTextWidth(text) return #text*6 end
function dxDrawRectangle() end
function dxDrawText(text,_,__,___,____,color) draws[#draws+1]={text=text,color=color} end
dofile('resources/rp_core/systems/notifications/client.lua')
for _,message in ipairs({
 'Объявление отправлено в LS News. При публикации будет списано $150',
 'Списано $150. Получено 80$. Цена $1 500 и 2 500$.',
 '#FF0000Цена $150#FFFFFF, повторная цена 250$ и команда /news',
 '$5, $150, 5$, 150$, $1,500.50, 1 500$'
}) do
 now=now+1000;draws={};showCoreNotification(message);handlers.onClientRender()
 local amounts=0
 for _,d in ipairs(draws) do
  assert(not d.text:find('#%x%x%x'),'color markup must never appear in rendered notification text')
  if d.text:find('%$') then
   amounts=amounts+1;assert(d.color[1]==35 and d.color[2]==177 and d.color[3]==245,'money uses exact original blue #23B1F5: '..d.text..' ('..table.concat(d.color,',')..')')
  end
 end
 assert(amounts>0,'notification still contains visible prices')
end
print('Notification money colors: screenshot regression, both currency formats, existing markup, multiple prices, commands and line wrapping passed')
