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
assert(hospital.interior==1 and hospital.inside.x==1479.4 and hospital.inside.y==1505 and hospital.inside.z==1183.5,'hospital uses custom shell indoor spawn')
for _,key in ipairs({'exit','duty','keys'}) do
 local m=F.markers[key..':1'];local point=key=='exit' and hospital.exit or (key=='duty' and hospital.dutyPoint or hospital.keysPoint)
 assert(m.interior==1 and m.dimension==hospital.dimension and math.abs(m.z-(point.z+(key=='exit' and 0.7 or FractionConfig.interactionIconZOffset)))<0.01,'hospital markers use their configured collision floor height')
end
local news=Fractions[3]
-- Use the exact Bike School spawn requested for LS News.
assert(news.interior==3 and news.inside.x==1494.4 and news.inside.y==1305 and math.abs(news.inside.z-1093.29)<0.01,'News uses requested Bike School interior')
for _,key in ipairs({'exit','duty','keys'}) do
 local m=F.markers[key..':3']
 assert(m.interior==3 and m.dimension==news.dimension and math.abs(m.z-((key=='exit' and news.exit or (key=='duty' and news.dutyPoint or news.keysPoint)).z+(key=='exit' and 0.7 or FractionConfig.interactionIconZOffset)))<0.01,'News marker is on same floor and dimension')
end
local p=element('player',news.entrance.x,news.entrance.y,news.entrance.z)
source=F.markers['enter:3'];handlers.onMarkerHit(p,true)
assert(p.interior==3 and p.dimension==news.dimension and p.z==news.inside.z,'real entrance handler spawns on News floor')
for _,old in ipairs({{2003.1178,1018.3948,33.008},{2011.603,1017.023,39.091}}) do
 p.interior=11;p.x,p.y,p.z=unpack(old)
 F.repairInteriorPosition(p)
 assert(p.interior==3 and p.x==news.inside.x and p.z==news.inside.z,'both previous News positions migrate to Bike School')
end
p.x,p.y,p.z=news.inside.x+1,news.inside.y,news.inside.z
F.repairInteriorPosition(p)
assert(p.x==news.inside.x+1 and p.z==news.inside.z,'repair leaves players on the correct Bike School floor untouched')
p.dimension=0;p.z=39.1;F.repairInteriorPosition(p)
assert(p.z==39.1,'repair does not move unrelated exterior players')
tick=12000
p.x,p.y,p.z=hospital.entrance.x,hospital.entrance.y,hospital.entrance.z
source=F.markers['enter:1'];handlers.onMarkerHit(p,true)
assert(p.interior==1 and p.dimension==hospital.dimension and p.x==hospital.inside.x and p.y==hospital.inside.y,'real hospital entrance reaches custom shell')
p.x,p.y,p.z=5000,4992,1001.2;p.interior=1
F.repairInteriorPosition(p)
assert(p.interior==1 and p.x==hospital.inside.x and p.z==hospital.inside.z,'saved old hospital shell positions migrate to custom interior')
p.x,p.y,p.z=830.6016,5.9404,1004.1797;p.interior=3
F.repairInteriorPosition(p)
assert(p.interior==1 and p.x==hospital.inside.x,'saved Inside Track visitors migrate to custom hospital')
for id,f in pairs(Fractions) do
 assert(not F.markers['desk:'..id] and F.markers['keys:'..id],'composition markers replaced with key desks')
 assert(F.markers['keys:'..id].kind=='colshape','key icon uses invisible interaction sphere')
 if f.duty then assert(F.markers['duty:'..id].kind=='pickup' and F.markers['duty:'..id].model==1275,'shift uses stock rotating clothes pickup') end
 if f.roof then
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
  tick=tick+2000;source=roof;handlers.onMarkerHit(p,true)
  assert(p.x==arrival.x and p.y==arrival.y and p.z==arrival.z and p.dimension==0,'any authenticated visitor can reach the actual roof')
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

local russian=Fractions[6]
assert(russian.interior==2 and russian.inside.x==1204.86 and russian.inside.y==-11.64 and russian.inside.z==1000.92,'Russian Mafia uses requested Pig Pen coordinates')
for _,key in ipairs({'exit','keys','armory'}) do
 assert(F.markers[key..':6'].interior==2 and F.markers[key..':6'].dimension==20006,'Russian Mafia interactions moved to isolated Pig Pen interior')
end
p.interior=12;p.dimension=20006;p.x,p.y,p.z=2324.5,-1147.1,1050.7
F.repairInteriorPosition(p)
assert(p.interior==2 and p.x==russian.inside.x and p.z==russian.inside.z,'saved Russian Mafia visitors migrate from old interior')
F.member=function() return nil end
local denied=0
F.notify=function() denied=denied+1 end
for id,f in ipairs(Fractions) do
 tick=tick+2000;p.interior=0;p.dimension=0;p.x,p.y,p.z=f.entrance.x,f.entrance.y,f.entrance.z
 source=F.markers['enter:'..id];handlers.onMarkerHit(p,true)
 assert(p.interior==f.interior and p.dimension==f.dimension and p.x==f.inside.x,'nonmember may enter any faction HQ')
 tick=tick+2000;source=F.markers['keys:'..id];handlers.onColShapeHit(p,true)
 assert(denied==id,'visitors cannot obtain faction vehicle keys')
 tick=tick+2000;source=F.markers['exit:'..id];handlers.onMarkerHit(p,true)
 assert(p.interior==0 and p.dimension==0 and p.x==(f.outsideSpawn or f.entrance).x,'visitors can leave every faction HQ')
end
print('Public headquarters: all six enter/exit routes accept visitors; faction vehicle keys remain protected')

assert(news.entrance.x==1653.96 and news.entrance.y==-1655.8 and news.entrance.z==22.51,'News entrance uses requested new coordinates')
assert(news.outsideSpawn.x==1653.96 and news.outsideSpawn.y==-1657.8,'News exit arrival follows relocated HQ')
assert(#news.vehicles==4 and news.vehicles[3].slot==3,'News relocation retains complete fleet and stable helicopter key')
for _,v in ipairs(news.vehicles) do
 assert(v.p.x>1650 and v.p.x<1680 and v.p.y<-1699 and v.p.y>-1720,'all News parking positions follow new HQ')
 assert(not v.helipad and not v.roofDeck,'News does not create artificial helipad or roof deck')
end
assert(not news.roof and not F.markers['roof:3'] and not F.markers['roofBack:3'],'News has no redundant roof/interior portal')
assert(F.markers['enter:3'] and F.markers['exit:3'],'News main entrance and normal interior exit remain available')
for _,e in ipairs(elements) do
 local info=e.data['fraction:marker']
 assert(not(info and info.id==3 and (info.kind=='roof' or info.kind=='roofBack')),'no invisible News roof return trigger remains')
end
for _,e in ipairs(elements) do
 assert(not(e.kind=='object' and math.abs(e.x-741)<40 and math.abs(e.y+1348)<40),'no artificial helicopter objects remain at old News location')
end
print('News relocation: entrance, exit, all four vehicles, single exterior entrance and removal of old helicopter deck verified')

HospitalInteriorConfig={}
local waiting
function getPedRotation(e) return e.rotation or 0 end
F.safeTeleport=function(player,pos,interior,dimension) waiting={pos=pos,interior=interior,dimension=dimension};return true end
p.interior,p.dimension=1,hospital.dimension;p.x,p.y,p.z=hospital.inside.x+1,hospital.inside.y,hospital.inside.z
F.repairInteriorPosition(p)
assert(waiting and waiting.pos.x==p.x and waiting.pos.z==p.z,'reconnect at valid custom hospital position waits for collision without resetting saved position')
p.z=hospital.inside.z-5;waiting=nil
F.repairInteriorPosition(p)
assert(waiting.pos.x==hospital.inside.x and waiting.pos.z==hospital.inside.z,'players below custom hospital floor recover to safe spawn')

assert(Fractions[3].blip.icon==35,'News uses requested map icon 35')
for _,v in ipairs(hospital.vehicles) do assert(not v.helipad and not v.roofDeck,'hospital creates no artificial rooftop objects') end
for _,e in ipairs(elements) do
 assert(not(e.kind=='object' and math.abs(e.x-1176)<35 and math.abs(e.y+1326)<35),'hospital roof has no generated platform or helipad')
end
