dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local payer,officer={id=1,money=1000},{id=2}
local online={payer,officer}
local ticket={id=10,account_id=1,officer_id=2,amount=100,paid=false}
local changed,balances,notices=0,{},{}
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
function addCommandHandler() end
function addEventHandler() end
function triggerClientEvent() end
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
