dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local commands,chat={},{}
local doctor={id=1,faction=1,duty=true,hp=100,money=1000};local patient={id=2,hp=40,money=1000}
Fraction={sessions={},cuffs={},members={}}
local F=Fraction
F.account=function(p) return type(p)=='table' and p.id end
F.player=function(id) return tonumber(id)==1 and doctor or (tonumber(id)==2 and patient or nil) end
F.active=function(p,id) return p.faction==id and p.duty end
F.throttle=function() return true end
F.near=function() return not patient.far end
F.jailed=function() return false end
F.notify=function() end
F.name=function(p) return 'Player'..p.id end
F.charge=function(p,amount) if p.money<amount then return false end;p.money=p.money-amount;return true end
function addCommandHandler(name,fn) commands[name]=fn end
function isPedDead(p) return p.dead end
function getElementHealth(p) return p.hp end
function setElementHealth(p,v) p.hp=v end
function outputChatBox(text,p) chat[#chat+1]={text,p} end
exports={rp_core={getPlayerDynamicID=function(self,p) return p.id end}}
root={}
assert(loadfile('resources/rp_fraction/server/services.lua'))()
commands.heal(doctor,'heal','2');assert(patient.hp==100 and patient.money==900,'heal debits patient $100')
commands.heal(doctor,'heal','2');assert(patient.money==900,'full health never charged')
patient.hp=40;patient.far=true;commands.heal(doctor,'heal','2');assert(patient.money==900,'remote heal rejected');patient.far=false
patient.dead=true;commands.heal(doctor,'heal','2');assert(patient.money==900,'dead patient rejected');patient.dead=false
doctor.duty=false;commands.heal(doctor,'heal','2');assert(patient.money==900,'off duty rejected');doctor.duty=true
patient.money=99;commands.heal(doctor,'heal','2');assert(patient.hp==40,'insufficient patient balance rejected')
commands.sms(doctor,'sms','2','hello');assert(doctor.money==999 and #chat==2,'SMS charged once and delivered to both parties')
commands.sms(doctor,'sms','1','self');assert(doctor.money==999,'self SMS rejected')
commands.sms(doctor,'sms','999','missing');assert(doctor.money==999,'missing target never charged')
print('Hospital/SMS: 9 payment, duty, distance, life-state and delivery checks passed')
