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
function setPedRotation() end
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
 assert(m.interior==3 and m.dimension==hospital.dimension and math.abs(m.z-1004.8797)<0.01,'hospital markers use the stock interior floor')
end
local news=Fractions[3]
-- Known suite floor from MTA amx's properties/interiors.txt, not roof z=39.1.
assert(news.interior==11 and math.abs(news.inside.z-33.008)<0.01,'News uses actual suite floor')
for _,key in ipairs({'exit','duty','keys'}) do
 local m=F.markers[key..':3']
 assert(m.interior==11 and m.dimension==news.dimension and math.abs(m.z-33.708)<0.01,'News marker is on same floor and dimension')
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
 if id<=3 then
  local roof,back=F.markers['roof:'..id],F.markers['roofBack:'..id]
  assert(roof.interior==f.interior and roof.dimension==f.dimension and back.interior==0 and back.dimension==0,'roof portal is paired across correct dimensions')
  F.member=function() return {faction_id=id} end
  tick=tick+2000;source=roof;handlers.onMarkerHit(p,true)
  assert(p.x==f.roof.outside.x+3.5 and p.z==f.roof.outside.z and p.interior==0 and p.dimension==0,'roof portal reaches configured helicopter parking')
  tick=tick+2000;source=back;handlers.onMarkerHit(p,true)
  assert(p.x==f.inside.x and p.interior==f.interior and p.dimension==f.dimension,'roof return portal restores own faction interior')
  F.member=function() return nil end
  tick=tick+2000;source=back;handlers.onMarkerHit(p,true)
  assert(p.interior==f.interior and p.dimension==f.dimension,'dismissal cannot trap a player on a public faction roof')
 end
end
print('World: six map blips, requested hospital, News floor, markers, entry and saved-position repair passed')

for _,zone in ipairs(elements) do if zone.kind=='colshape' and zone.data['fraction:marker'].kind=='roofBack' then
 local id=zone.data['fraction:marker'].id;local f=Fractions[id]
 assert(math.abs(f.roof.outside.x+3.5-zone.x)>zone.radius,'roof arrival stays outside return trigger')
 tick=tick+2000;source=zone;handlers.onColShapeHit(p,true)
 assert(p.x==f.inside.x and p.dimension==f.dimension,'independent roof colshape returns to correct interior')
end end

local g=Fractions[2].garage
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
