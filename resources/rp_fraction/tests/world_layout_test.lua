dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local handlers,elements={},{}
Fraction={markers={},blips={}}
local F=Fraction
function addEventHandler(name,element,fn) handlers[name]=fn end
local function element(kind,x,y,z)
 local e={kind=kind,x=x,y=y,z=z,interior=0,dimension=0,data={}};elements[#elements+1]=e;return e
end
function createObject(model,x,y,z) return element('object',x,y,z) end
function createColSphere(x,y,z,r) local e=element('colshape',x,y,z);e.radius=r;return e end
function createMarker(x,y,z) return element('marker',x,y,z) end
function createPickup(x,y,z,kind,model) local p=element('pickup',x,y,z);p.model=model;return p end
function createBlip(x,y,z,icon,size,r,g,b,alpha,ordering,distance) local e=element('blip',x,y,z);e.icon,e.size,e.color,e.visibleDistance=icon,size,{r,g,b},distance;return e end
function setElementData(e,key,value) e.data[key]=value end
function getElementData(e,key) return e.data[key] end
function setElementInterior(e,value) e.interior=value end
function setElementDimension(e,value) e.dimension=value end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function getElementPosition(e) return e.x,e.y,e.z end
function setElementPosition(e,x,y,z) e.x,e.y,e.z=x,y,z end
function setElementDoubleSided() end
function setPedRotation(p,rotation) p.rotation=rotation end
function setCameraTarget() end
function isPedInVehicle() return false end
local tick=10000
function getTickCount() return tick end
F.account=function() return 1 end
F.jailed=function() return false end
F.near=function() return true end
F.member=function() return nil end
dofile('resources/rp_fraction/server/world.lua')
F.createWorld()
local count=0
for id,blip in pairs(F.blips) do
 count=count+1;local f=Fractions[id]
 assert(blip.x==f.entrance.x and blip.y==f.entrance.y and blip.dimension==0 and blip.interior==0,'each HQ has an exterior map blip')
 assert(blip.icon==f.blip.icon and blip.data['blip:name']==f.name and blip.color[1]==f.color[1],'configured icon, name and faction color applied')
 assert(blip.visibleDistance==250,'faction blips use the same nearby radar range as car systems')
end
assert(count==6,'six faction map blips')
local hospital=Fractions[1]
assert(hospital.interior==3 and hospital.inside.x==830.6016 and hospital.inside.y==5.9404 and hospital.inside.z==1004.1797,'hospital uses requested Inside Track Betting coordinates')
for _,key in ipairs({'exit','duty','keys'}) do
 local m=F.markers[key..':1']
 assert(m.interior==3 and m.dimension==hospital.dimension and math.abs(m.z-(hospital.inside.z+(key=='exit' and 0.7 or FractionConfig.interactionIconZOffset)))<0.01,'hospital markers use the stock interior floor')
end
local news=Fractions[3]
-- Known suite floor from MTA amx's properties/interiors.txt, not roof z=39.1.
assert(news.interior==11 and math.abs(news.inside.z-33.008)<0.01,'News uses actual suite floor')
for _,key in ipairs({'exit','duty','keys'}) do
 local m=F.markers[key..':3']
 assert(m.interior==11 and m.dimension==news.dimension and math.abs(m.z-(news.inside.z+(key=='exit' and 0.7 or FractionConfig.interactionIconZOffset)))<0.01,'News marker is on same floor and dimension')
end
local p=element('player',news.entrance.x,news.entrance.y,news.entrance.z)
source=F.markers['enter:3'];handlers.onMarkerHit(p,true)
assert(p.interior==11 and p.dimension==news.dimension and p.z==news.inside.z,'real entrance handler spawns on News floor')
p.x,p.y,p.z=2011.6,1017,39.1
F.repairInteriorPosition(p)
assert(p.x==news.inside.x and p.z==news.inside.z,'players saved on old roof are moved onto floor')
p.dimension=0;p.z=39.1;F.repairInteriorPosition(p)
assert(p.z==39.1,'repair does not move unrelated exterior players')
tick=12000
p.x,p.y,p.z=hospital.entrance.x,hospital.entrance.y,hospital.entrance.z
source=F.markers['enter:1'];handlers.onMarkerHit(p,true)
assert(p.interior==3 and p.dimension==hospital.dimension and p.x==830.6016 and p.y==5.9404,'real hospital entrance uses requested stock interior')
p.x,p.y,p.z=5000,4992,1001.2;p.interior=1
F.repairInteriorPosition(p)
assert(p.interior==3 and p.x==830.6016 and p.z==1004.1797,'saved old hospital positions migrate to stock interior')
for id,f in pairs(Fractions) do
 assert(not F.markers['desk:'..id] and F.markers['keys:'..id],'composition markers replaced with key desks')
 assert(F.markers['keys:'..id].kind=='colshape','key icon uses invisible interaction sphere')
 if f.duty then assert(F.markers['duty:'..id].kind=='pickup' and F.markers['duty:'..id].model==1275,'shift uses stock rotating clothes pickup') end
 if id<=3 then
  local roof,back=F.markers['roof:'..id],F.markers['roofBack:'..id]
  assert(roof.interior==f.interior and roof.dimension==f.dimension and back.interior==0 and back.dimension==0,'roof portal is paired across correct dimensions')
  F.member=function() return {faction_id=id} end
  tick=tick+2000;source=roof;handlers.onMarkerHit(p,true)
  local arrival=f.roof.arrival
  assert(p.x==arrival.x and p.y==arrival.y and p.z==arrival.z and p.interior==0 and p.dimension==0,'roof portal reaches configured helicopter parking')
  p.x,p.y,p.z=f.roof.outside.x+1.2,f.roof.outside.y,f.roof.outside.z
  tick=tick+2000;source=back;handlers.onMarkerHit(p,true)
  assert(p.dimension==0,'roof arrow does not trigger beyond small radius')
  p.x=f.roof.outside.x+0.4
  tick=tick+2000;source=back;handlers.onMarkerHit(p,true)
  assert(p.x==f.roof.returnSpawn.x and p.interior==f.interior and p.dimension==f.dimension,'roof return portal restores configured faction interior position')
  F.member=function() return nil end
  p.x,p.y,p.z=f.roof.outside.x,f.roof.outside.y,f.roof.outside.z;p.interior,p.dimension=0,0
  tick=tick+2000;source=back;handlers.onMarkerHit(p,true)
  assert(p.interior==f.interior and p.dimension==f.dimension,'dismissal cannot trap a player on a public faction roof')
 end
end
print('World: six map blips, requested hospital, News floor, markers, entry and saved-position repair passed')
local cancelled,opened=false,false
function cancelEvent() cancelled=true end
function triggerClientEvent(player,event,element,kind) if event=='fraction:menu' then opened=kind end end
F.sessions={[p]={duty=false}};F.member=function() return {faction_id=1} end
tick=tick+2000;source=F.markers['duty:1'];handlers.onPickupHit(p,true)
assert(cancelled and opened=='duty','clothes pickup opens shift menu without consuming pickup')

for _,zone in ipairs(elements) do if zone.kind=='colshape' and zone.data['fraction:marker'].kind=='roofBack' then
 local id=zone.data['fraction:marker'].id;local f=Fractions[id]
 assert(zone.radius==(f.roof.triggerRadius or 0.9),'roof auxiliary sphere respects uploaded trigger radius')
 local arrival=f.roof.arrival
 assert((arrival.x-zone.x)^2+(arrival.y-zone.y)^2>zone.radius^2,'roof arrival stays outside return trigger')
 p.x,p.y,p.z=zone.x+1.2,zone.y,zone.z;p.interior,p.dimension=0,0
 tick=tick+2000;source=zone;handlers.onColShapeHit(p,true)
 assert(p.dimension==0,'roof sphere cannot teleport players passing outside configured radius')
 p.x=zone.x+0.4;tick=tick+2000;handlers.onColShapeHit(p,true)
 assert(p.x==f.roof.returnSpawn.x and p.dimension==f.dimension,'independent roof colshape returns to configured interior position')
end end

local g=Fractions[2].garage
assert(g.arrival.rotation==180,'garage arrival faces the parking area')
F.member=function() return {faction_id=2} end
F.safeGarageTeleport=function(p,pos,interior,dimension)
 setElementInterior(p,interior);setElementDimension(p,dimension);setElementPosition(p,pos.x,pos.y,pos.z)
end
tick=tick+2000;source=F.markers['garage:2'];handlers.onMarkerHit(p,true)
assert(p.x==g.arrival.x and p.dimension==0 and p.interior==0,'LSPD interior garage exit reaches underground parking')
tick=tick+2000;source=F.markers['garageBack:2'];handlers.onMarkerHit(p,true)
assert(p.x==g.arrival.x and p.dimension==0,'garage arrival outside small radius must not return immediately')
p.x,p.y,p.z=g.outside.x+1.2,g.outside.y,g.outside.z
tick=tick+2000;handlers.onMarkerHit(p,true)
assert(p.dimension==0,'visible arrow cannot trigger entry beyond configured radius')
p.x=g.outside.x+0.5
tick=tick+2000;handlers.onMarkerHit(p,true)
assert(p.x==g.returnSpawn.x and p.dimension==Fractions[2].dimension,'garage return reaches LSPD interior')
for _,zone in ipairs(elements) do if zone.kind=='colshape' and zone.data['fraction:marker'].kind=='garageBack' then
 assert(zone.radius==0.9,'garage auxiliary sphere is reduced to marker-sized radius')
 p.interior,p.dimension=0,0;p.x,p.y,p.z=g.outside.x+2,g.outside.y,g.outside.z
 tick=tick+2000;source=zone;handlers.onColShapeHit(p,true)
 assert(p.dimension==0,'auxiliary colshape cannot teleport a player walking past')
 p.x=g.outside.x+0.4;tick=tick+2000;handlers.onColShapeHit(p,true)
 assert(p.dimension==Fractions[2].dimension,'auxiliary colshape still allows entering inside marker')
end end

local lspd=Fractions[2]
tick=tick+2000;source=F.markers['exit:2'];handlers.onMarkerHit(p,true)
assert(p.x==1552.4 and p.y==lspd.entrance.y and p.z==lspd.entrance.z and p.rotation==90,'LSPD main exit faces street on exterior porch in front of marker')
assert(p.x<lspd.entrance.x-2 and p.interior==0 and p.dimension==0,'exit stays outside entrance trigger on street side')

local armories=0
for id,f in pairs(Fractions) do if f.armory then
 local pickup=F.markers['armory:'..id];armories=armories+1
 assert(pickup.kind=='pickup' and pickup.model==2040,'all armories use GTA ammunition box pickups')
 assert(pickup.interior==f.interior and pickup.dimension==f.dimension,'ammunition box stays in own faction interior')
end end
assert(armories==4,'LSPD and three mafia armories replaced')
F.member=function() return {faction_id=2,rank=2} end
F.active=function() return true end
cancelled,opened=false,false;tick=tick+2000;source=F.markers['armory:2']
handlers.onPickupHit(p,true)
assert(cancelled and opened=='armory','ammunition box opens armory menu without consuming the pickup')

local mafia=Fractions[4]
F.member=function() return {faction_id=4,rank=1} end
assert(mafia.interior==1 and mafia.inside.x==625.45 and mafia.inside.y==-12 and mafia.inside.z==1000.92,'La Cosa Nostra uses requested TransFender arrival')
for _,key in ipairs({'exit','keys','armory'}) do
 local marker=F.markers[key..':4']
 assert(marker.interior==1 and marker.dimension==20004,'TransFender interactions use isolated La Cosa Nostra interior')
end
for _,old in ipairs({{5,1262.1,-785.3,1091.9},{1,1405.312,-8.2928,1000.913},{2,2536.53,-1294.84,1044.12}}) do
 p.interior=old[1];p.dimension=20004;p.x,p.y,p.z=old[2],old[3],old[4]
 F.repairInteriorPosition(p)
 assert(p.interior==1 and p.x==mafia.inside.x and p.z==mafia.inside.z,'saved residents migrate from all previous interiors to TransFender')
end
tick=tick+2000;source=F.markers['exit:4'];handlers.onMarkerHit(p,true)
assert(p.interior==0 and p.dimension==0 and p.x==mafia.outsideSpawn.x,'TransFender exit returns to current exterior entrance')
tick=tick+2000;source=F.markers['enter:4'];handlers.onMarkerHit(p,true)
assert(p.interior==1 and p.dimension==20004 and p.x==mafia.inside.x,'HQ entrance reaches TransFender floor')
print('La Cosa Nostra TransFender: markers, entry, exit and old saved-position recovery passed')

p.x,p.y,p.z=mafia.inside.x+1,mafia.inside.y,mafia.inside.z
F.repairInteriorPosition(p)
assert(p.x==mafia.inside.x+1,'current TransFender residents are not moved')
p.interior=1;p.dimension=0;p.x,p.y,p.z=1405.312,-8.2928,1000.913
F.repairInteriorPosition(p)
assert(p.x==1405.312 and p.dimension==0,'warehouse players outside faction dimension are not moved')
