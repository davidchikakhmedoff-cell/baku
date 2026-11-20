dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local f=Fractions[1]
local p={id=1,alive=true,hp=20,money=1000,x=f.selfHealPoint.x,y=f.selfHealPoint.y,z=f.selfHealPoint.z,interior=f.interior,dimension=f.dimension}
local players={p};local menu,closed,charged=nil,0,0
Fraction={ready=true,markers={['selfHeal:1']={}},sessions={}}
local F=Fraction
function getElementsByType() return players end
function isPedDead(e) return not e.alive end
function isPedInVehicle(e) return e.vehicle end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementHealth(e) return e.hp end
function setElementHealth(e,hp) e.hp=hp end
function getPedRotation() return 0 end
function triggerClientEvent(e,event,_,kind,data)
 if event=='fraction:menu' then menu={player=e,kind=kind,data=data} end
 if event=='fraction:closeSelfHeal' then closed=closed+1 end
end
F.account=function(e) return e and e.id end
F.active=function(e,fid) return e.faction==fid and e.duty and e.alive end
F.jailed=function(e) return e.jailed end
F.near=function(e) return (e.x-f.selfHealPoint.x)^2+(e.y-f.selfHealPoint.y)^2<=4 end
F.throttle=function() return true end
F.notify=function(e,text) e.notice=text end
F.charge=function(e,amount) if e.money<amount then return false end;e.money=e.money-amount;charged=charged+amount;return true end
F.safeTeleport=function(e,pos,int,dim,fallback) e.prepared=pos;assert(fallback.interior==0 and fallback.dimension==0,'failed model loading returns to street world');return true end
dofile('resources/rp_fraction/server/hospital.lua')
F.openSelfHeal(p);assert(menu.kind=='selfHeal' and menu.data.price==250,'desk opens server-priced healing window')
F.selfHeal(p);assert(p.hp==100 and p.money==750 and charged==250 and closed==1,'desk heals exactly once and charges $250')
F.selfHeal(p);assert(charged==250,'full-health repeated event cannot charge again')
p.hp=20;p.money=249;F.selfHeal(p);assert(p.hp==20 and p.money==249,'insufficient funds cannot heal')
p.money=1000
local doctor={id=2,alive=true,faction=1,duty=true};players={p,doctor};menu=nil
F.openSelfHeal(p);F.selfHeal(p)
assert(not menu and p.hp==20 and p.money==1000,'on-duty doctor blocks both menu and a forged purchase request')
doctor.duty=false;F.openSelfHeal(p);assert(menu,'off-duty doctors do not block emergency desk')
doctor.duty=true;F.selfHeal(p);assert(p.hp==20 and p.money==1000,'doctor starting shift after window opened is rechecked at payment')
doctor.duty=false
for _,key in ipairs({'vehicle','jailed'}) do p[key]=true;F.selfHeal(p);assert(p.hp==20);p[key]=false end
p.dimension=0;F.selfHeal(p);assert(p.hp==20,'wrong dimension cannot heal');p.dimension=f.dimension
p.x=p.x+10;F.selfHeal(p);assert(p.hp==20,'leaving desk blocks stale window');p.x=f.selfHealPoint.x
players={}
math.randomseed(321)
for i=1,9 do
 local q={id=100+i,alive=false}
 local pos=getHospitalRespawnLocation(q)
 assert((pos.x-f.respawnPoint.x)^2+(pos.y-f.respawnPoint.y)^2<=1 and pos.health==20,'death spawn remains inside one-metre radius with 20 HP')
 for _,other in ipairs(players) do assert((pos.x-other.x)^2+(pos.y-other.y)^2>=0.65^2,'simultaneous respawns choose separated unoccupied spots') end
 q.alive=true;q.x,q.y,q.z=pos.x,pos.y,pos.z;q.interior,q.dimension=pos.interior,pos.dimension;players[#players+1]=q
 assert(completeHospitalRespawn(q) and q.prepared.x==q.x,'respawn waits for custom collision without moving outside scatter spot')
end
print('Hospital services: authoritative payment, shift availability, stale/spoofed requests, nine separated respawns and collision preparation passed')
