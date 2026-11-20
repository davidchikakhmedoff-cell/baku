dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
function addEvent() end
function addEventHandler() end
function setElementData() end
function triggerClientEvent() end
function getElementModel(p) return p.model end
function setElementModel(p,id) p.model=id end
local gender,queries='female',0
FractionDB={one=function(sql,id)
 assert(sql=='SELECT gender FROM players WHERE id=?' and id==87,'gender comes from permanent account record')
 queries=queries+1;return {gender=gender}
end,exec=function() return true end,change=function() return true end}
dofile('resources/rp_fraction/server/main.lua')
local F=Fraction;local p={model=9}
local m={account_id=87,faction_id=2,rank=1,duty=0}
F.member=function() return m end
F.sessions[p]={duty=false};F.markers['duty:2']={}
F.near=function() return true end;F.jailed=function() return false end
function isPedInVehicle() return false end
F.snapshotWeapons=function() return '[]' end
F.notify=function() end;F.clearCuffs=function() end;F.revokeDriver=function() end;F.restoreWeapons=function() end
local expected={129,130,130,130,130,131,131,131,150,151}
for rank,id in ipairs(expected) do m.rank=rank;assert(F.workSkin(p)==id,'female rank skin '..rank) end
assert(queries==1,'account gender cached, no repeated query per sync')
m.rank=2;F.toggleDuty(p);assert(p.model==130 and m.civilian_skin==9,'female uniform applied on shift without overwriting civilian skin')
F.endDuty(p);assert(p.model==9,'civilian model restored after shift')
gender='male';m.gender=nil
for rank,id in ipairs(Fractions[2].skins) do m.rank=rank;assert(F.workSkin(p)==id,'male skin mapping preserved') end
p.gender='female';m.gender=nil;assert(F.workSkin(p)==61,'client field cannot change account gender')
print('Female uniforms: all ten ranks, existing account gender, caching, duty restore and male compatibility passed')

F.markers['duty:1']={};m.faction_id=1
for _,case in ipairs({{gender='male',skins={276,276,275,275,71,70}},{gender='female',skins={152,152,145,145,148,91}}}) do
 gender=case.gender;m.gender=nil
 p.model=23;p.gender=gender=='female' and 'male' or 'female'
 for rank,id in ipairs(case.skins) do
  m.rank=rank;assert(F.workSkin(p)==id,'hospital '..gender..' rank '..rank..' uses requested uniform')
 end
 m.rank=1;F.toggleDuty(p)
 assert(p.model==case.skins[1] and m.civilian_skin==23,'hospital shift chooses uniform from persistent account gender')
 for rank,id in ipairs(case.skins) do m.rank=rank;F.sync(p);assert(p.model==id,'hospital shift sync applies correct rank model') end
 F.endDuty(p);assert(p.model==23,'hospital shift restores saved civilian clothing')
end
print('Hospital uniforms: all six ranks for both account genders, shift application, rank sync and civilian restoration passed')
