dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local now,active,near=1000,true,true
local p={};local member={account_id=1,faction_id=2,rank=5,armory_at=0,duty=1,civilian_weapons='[]'}
local ammo,grants={},0
Fraction={markers={['armory:2']={}},vehicles={}}
Fraction.member=function() return member end
Fraction.active=function() return active end
Fraction.near=function() return near end
Fraction.now=function() return now end
Fraction.notify=function() end
Fraction.snapshotWeapons=function() return '[]' end
FractionDB={change=function() return true end,exec=function() return true end}
root={};resourceRoot={}
function addEventHandler() end
function getSlotFromWeapon(id) return id end
function getPedWeapon(player,slot) return ammo[slot] and slot or 0 end
function getPedTotalAmmo(player,slot) return ammo[slot] or 0 end
function giveWeapon(player,id,count) ammo[id]=(ammo[id] or 0)+count;grants=grants+1 end
assert(loadfile('resources/rp_fraction/server/world.lua'))()
Fraction.armory(p);assert(grants==5 and ammo[31]==200,'rank 5 receives M4 and sniper')
Fraction.armory(p);assert(grants==5,'cooldown blocks immediate repeated kit')
now=1700;Fraction.armory(p);assert(grants==5,'full ammo is never stacked')
near=false;now=2400;Fraction.armory(p);assert(grants==5,'remote armory request rejected');near=true
active=false;Fraction.armory(p);assert(grants==5,'off-duty request rejected')
print('Armory: rank loadout, persisted cooldown, no stacking, location and duty checks passed')

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
