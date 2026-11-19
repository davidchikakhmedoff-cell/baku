function setVehicleDamageProof() end
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local now,active,near=1000,true,true
local p={};local member={account_id=1,faction_id=2,rank=5,armory_at=999999,duty=1,civilian_weapons='[]'}
local ammo,grants,armor={},0,0
local notice
function getPedArmor() return armor end
function setPedArmor(p,value) armor=value end
function getWeaponNameFromID(id) return tostring(id) end
Fraction={markers={['armory:2']={}},vehicles={}}
FractionDependencies={ready=function() return true end}
Fraction.member=function() return member end
Fraction.active=function() return active end
Fraction.near=function() return near end
Fraction.now=function() return now end
Fraction.notify=function(p,text) notice=text end
Fraction.snapshotWeapons=function() return '[]' end
FractionDB={change=function() return true end,exec=function() return true end}
root={};resourceRoot={}
function addEventHandler() end
function triggerClientEvent() end
function getSlotFromWeapon(id) return id end
function getPedWeapon(player,slot) return ammo[slot] and slot or 0 end
function getPedTotalAmmo(player,slot) return ammo[slot] or 0 end
function giveWeapon(player,id,count) ammo[id]=(ammo[id] or 0)+count;grants=grants+1 end
assert(loadfile('resources/rp_fraction/server/world.lua'))()
Fraction.armory(p);assert(armor==100,'armor issued with standard kit');assert(grants==5 and ammo[31]==200,'rank 5 receives M4 and sniper')
Fraction.armory(p);assert(grants==5,'repeated kits do not stack ammo')
now=1700;Fraction.armory(p);assert(grants==5,'full ammo is never stacked')
near=false;now=2400;Fraction.armory(p);assert(grants==5,'remote armory request rejected');near=true
active=false;Fraction.armory(p);assert(grants==5,'off-duty request rejected')
active=true;near=true;now=3000;member.armory_at=0;ammo={};grants=0
Fraction.armory(p,{24});assert(notice=='Вы взяли Desert Eagle.','selected item notification');assert(grants==1 and ammo[24]==70 and not ammo[31],'only selected weapon issued')
member.armory_at=0;Fraction.armory(p,{35});assert(grants==1 and member.armory_at==0,'unlisted weapon rejected')
Fraction.armory(p,{});assert(grants==1,'empty selection rejected')
member.rank=1;Fraction.armory(p,{31});assert(grants==1,'selected rank-restricted weapon rejected');member.rank=5
member.rank=1;member.armory_at=0;armor=0;Fraction.armory(p,{'armor'})
assert(armor==100 and notice=='Вы взяли Бронежилет.','rank one can select armor without receiving weapons')
Fraction.armory(p,{'armor'});assert(armor==100,'armor does not stack')
member.rank=5;member.armory_at=999999;ammo={};grants=0
Fraction.armory(p,{24});Fraction.armory(p,{31})
assert(grants==2 and ammo[24]==70 and ammo[31]==200,'different weapons available immediately despite old database cooldown')
ammo[24]=1;Fraction.armory(p,{24});assert(grants==3 and ammo[24]==70,'spent ammo can be replenished immediately')
armor=0;Fraction.armory(p,{'armor'});assert(armor==100,'damaged armor replenishes immediately')
print('Armory: rank loadout, no cooldown, no stacking, location and duty checks passed')

-- The regular missing-slot scan must not bypass a destroyed car's respawn timer.
local definition=Fractions[2];definition.vehicles={definition.vehicles[1]};Fractions={[2]=definition}
Fraction.vehicles={};Fraction.missing={['fraction:2:1']={at=60000}}
local clock,created=0,0
function getTickCount() return clock end
function getElementsByType() return {} end
function createVehicle() created=created+1;return {} end
function setVehicleColor() end
function setVehicleEngineState() end
function setVehicleLocked() end
function setElementData() end
FractionDB.one=function() return {fuel=30} end
exports={rp_car={registerFactionVehicle=function() return true end}}
Fraction.spawnFleet();assert(created==0,'missing-slot scan observes respawn delay')
clock=60000;Fraction.spawnFleet();assert(created==1,'destroyed car returns after configured delay')
Fraction.spawnFleet();assert(created==1,'existing service car is not duplicated')
print('Fleet: destroyed vehicle delay, eventual respawn and no duplicate slots passed')
