dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local payer,officer={id=1,money=1000},{id=2}
local online={payer,officer}
local ticket={id=10,account_id=1,officer_id=2,amount=100,paid=false}
local changed,balances,notices=0,{},{}
local commands,menu={},nil
Fraction={cuffs={}}
local F=Fraction
F.account=function(p) return p and p.id end
F.balance=function(id) balances[#balances+1]=id end
F.notify=function(p,text) notices[#notices+1]={player=p,text=text} end
FractionDB={
 one=function(sql,id,owner)
  if id==ticket.id and owner==ticket.account_id and not ticket.paid then return ticket end
 end,
 query=function() return {} end,
 change=function(sql,id,owner)
  assert(sql=='UPDATE fraction_tickets SET paid=1 WHERE id=? AND account_id=? AND paid=0','payment uses one guarded database update')
  assert(id==ticket.id and owner==ticket.account_id)
  if ticket.paid then return false end
  ticket.paid=true;changed=changed+1;return true
 end
}
exports={rp_core={getAuthPlayerBalance=function(_,p) return p.money end}}
function addEvent() end
function addCommandHandler(name,fn) commands[name]=fn end
dofile('resources/rp_fraction/server/commands.lua')
function addEventHandler() end
function triggerClientEvent(player,event,source,kind,data)
 if event=='fraction:menu' and kind=='ticket' then menu={player=player,data=data} end
end
function getElementsByType() return online end
dofile('resources/rp_fraction/server/police.lua')
F.payTicket(payer,10)
assert(changed==1 and balances[1]==1 and balances[2]==2,'successful payment refreshes both existing economy balances')
assert(notices[#notices].player==officer and notices[#notices].text:find('$60',1,true),'online issuer sees actual commission')
F.payTicket(payer,10);assert(changed==1,'repeat payment rejected')
ticket.paid=false;payer.money=99;F.payTicket(payer,10);assert(changed==1 and not ticket.paid,'insufficient balance rejected')
payer.money=1000;F.payTicket(officer,10);assert(changed==1,'another account cannot pay this ticket')
online={payer};balances={};F.payTicket(payer,10)
assert(changed==2 and balances[2]==2,'offline issuer balance is still refreshed through existing economy')
print('Ticket handler: guarded payment, balance sync, issuer notice, duplicates, insufficient funds and ownership passed')

-- Real custom-chat command route: another player receives a ticket and popup.
local core,fraction={},{}
function getResourceFromName(name) return name=='rp_core' and core or fraction end
function getResourceState() return 'running' end
function getResourceExportedFunctions() return {'executeFractionCommand'} end
function call(res,name,...)
 local old=sourceResource;sourceResource=core
 local result=executeFractionCommand(...);sourceResource=old;return result
end
function executeCommandHandler(name,player,args)
 local words={};for word in args:gmatch('%S+') do words[#words+1]=word end
 commands[name](player,name,unpack(words))
end
function addEvent() end
function isElement(p) return type(p)=='table' end
function getElementType() return 'player' end
function getElementData(p,key) return key=='auth:loggedIn' end
function isPedDead() return false end
function getRealTime() return {hour=12,minute=0,timestamp=1000} end
F.member=function(p) return p==officer and {faction_id=2,rank=10} or nil end
F.active=function() return true end
F.throttle=function() return true end
F.near=function() return true end
F.player=function(id) return tonumber(id)==1 and payer or (tonumber(id)==2 and officer) end
F.now=function() return 1000 end
local created
FractionDB.exec=function(sql,owner,issuer,amount,reason)
 assert(sql:find('INSERT INTO fraction_tickets',1,true))
 created={id=11,account_id=owner,officer_id=issuer,amount=amount,reason=reason};return true
end
FractionDB.one=function(sql,owner,issuer)
 assert(sql:find('last_insert_rowid()',1,true),'new ticket identified from actual insert')
 assert(owner==1 and issuer==2);return {id=11}
end
dofile('resources/rp_fraction/server/members.lua')
dofile('resources/rp_core/systems/chat/config.lua')
dofile('resources/rp_core/systems/chat/server.lua')
RPChat.processMessage(officer,'/ticket 1 250 Причина штрафа')
assert(created and created.account_id==1 and created.officer_id==2 and created.amount==250 and created.reason=='Причина штрафа','civilian ticket reaches SQL through custom chat')
assert(menu.player==payer and menu.data.id==11 and menu.data.amount==250 and menu.data.reason=='Причина штрафа','civilian ticket opens matching amount/reason popup')
menu=nil;RPChat.processMessage(officer,'/ticket 1 -100 test');assert(not menu,'negative fine cannot open payment window')
print('Ticket issuance: real custom chat bridge, civilian target, persistence, popup and invalid amount passed')

local before=created;menu=nil
RPChat.processMessage(officer,'/ticket 2 250 Self')
assert(created==before and not menu,'self ticket cannot reach database or open a popup')
