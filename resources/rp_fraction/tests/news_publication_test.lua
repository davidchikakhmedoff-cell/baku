dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local editor={id=1,name='Editor',faction=3,rank=3,duty=true,money=1000}
local author={id=2,name='Author',money=500,dynamic=15}
local players={editor,author};local commands,messages,balances={}, {},{}
local ad={id=7,account_id=2,author='Author',display_id=15,status='pending'}
local now,last,submissions=1000,nil,0
local changed,failUpdate=0,false
Fraction={}
local F=Fraction
F.account=function(p) return p and p.id end
F.name=function(p) return p.name end
F.member=function(p) return {faction_id=p.faction,rank=p.rank} end
F.active=function(p,fid) return p.faction==fid and p.duty end
F.notify=function(p,text) p.notice=text end
F.balance=function(id) balances[#balances+1]=id end
F.now=function() return now end
function getElementsByType() return players end
function addCommandHandler(name,fn) commands[name]=fn end
function triggerClientEvent() end
exports={rp_core={getAuthPlayerBalance=function(_,p) return p.money end,getPlayerDynamicID=function(_,p) return p.dynamic end,
 sendCoreChatMessage=function(_,p,text,r,g,b) messages[#messages+1]={p=p,text=text,color={r,g,b}} end}}
FractionDB={
 one=function(sql,id)
  if sql:find('submitted_at',1,true) then return last and {submitted_at=last} end
  if sql:find('SELECT * FROM fraction_ads',1,true) then return ad and ad.status=='pending' and ad or nil end
  return nil
 end,
 query=function() return {} end,
 exec=function(sql,id,name,dynamic,original,edited,timestamp)
  if sql:find('INSERT INTO fraction_ads',1,true) then
   assert(id==2 and dynamic==15 and original==edited and timestamp==now,'submission stores permanent account and current phone ID')
   submissions=submissions+1;last=timestamp
  elseif sql:find('DELETE FROM fraction_ads',1,true) then ad=nil end
  return true
 end,
 change=function(sql,text,id,name,adid)
  if failUpdate or not ad or ad.status~='pending' then return false end
  changed=changed+1
  if sql:find("status='published'",1,true) then
   assert(id==1 and name=='Editor' and adid==7 and text=='Продам машину','guarded publication stores edited text and responsible editor')
   ad.status='published'
  else ad.status='rejected' end
  return true
 end
}
dofile('resources/rp_fraction/server/services.lua')
F.newsProcess(editor,'publish',7,'Продам машину')
assert(changed==1 and balances[1]==2 and balances[2]==1,'successful atomic publication refreshes author and editor balances')
assert(#messages==4,'two green lines reach both online players')
for _,m in ipairs(messages) do assert(table.concat(m.color,',')=='105,210,110','entire announcement is green') end
assert(messages[1].text=='Объявление: Продам машину. Телефон: 15','announcement uses edited text and sender phone ID')
assert(messages[2].text=='Подал: Author. Отредактировал: Редактор Editor','second line contains author and editor rank/name')
F.newsProcess(editor,'publish',7,'Продам машину');assert(changed==1 and #messages==4,'second editor/stale click never republishes or pays twice')
ad.status='pending';author.money=149;messages={};balances={}
F.newsProcess(editor,'publish',7,'Продам машину');assert(ad.status=='pending' and #messages==0 and #balances==0,'insufficient author funds leave ad pending without broadcast')
author.money=500;failUpdate=true;F.newsProcess(editor,'publish',7,'Продам машину')
assert(#messages==0 and #balances==0,'database payment failure cannot announce success')
failUpdate=false;editor.duty=false;F.newsProcess(editor,'publish',7,'Продам машину');assert(changed==1,'off-duty editor cannot process ads');editor.duty=true
players={editor};F.newsProcess(editor,'publish',7,'Продам машину');assert(not ad and #messages==0,'offline author cannot be charged or published')
players={editor,author}
commands.add(author,'add','');assert(submissions==0 and last==nil,'invalid ad does not consume cooldown')
commands.add(author,'add','Текст');assert(submissions==1 and last==1000,'first valid submission starts account cooldown')
now=1179;commands.add(author,'add','Текст');assert(submissions==1 and author.notice:find('1 сек.',1,true),'early resubmission reports remaining cooldown')
now=1180;commands.add(author,'add','Текст');assert(submissions==2 and last==1180,'submission allowed at exactly three minutes')
print('News publication: exact green chat, price guard, balance refresh, stale requests, authorization, offline author and 180-second submission interval passed')
