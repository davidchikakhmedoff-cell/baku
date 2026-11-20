function setVehicleDamageProof() end
local function build() dofile('resources/rp_fraction/config.lua') end
local function defaults() dofile('resources/rp_fraction/fleet_config.lua');build() end
defaults()
local counts={4,17,4,9,9,9}
assert(#FractionFleetWarnings==0,'default fleet has no configuration warnings')
for id,f in pairs(Fractions) do
 assert(#f.vehicles==counts[id],'original default fleet count retained')
 for index,v in ipairs(f.vehicles) do assert(v.slot==index,'original persistent vehicle IDs retained') end
end
local expectedX={1595.5,1591.5,1587.5,1583.5,1578.5,1574.5,1570.5,1566.5,1562.5,1559}
for slot=1,10 do
 local v=Fractions[2].vehicles[slot];local model=slot<=2 and 596 or (slot<=6 and 597 or 598)
 assert(v.slot==slot and v.model==model and v.rank==2,'patrol slots map to 2 Explorer, 4 Taurus and 4 Charger with unchanged rank and fuel identity')
 assert(v.p.x==expectedX[slot] and v.p.y==-1710 and v.p.z==5.8 and v.p.rotation==0,'existing patrol parking positions retained')
end
assert(Fractions[2].vehicles[15].model==599 and Fractions[2].vehicles[17].model==497,'Rangers and helicopter retain their original fleet slots')
FractionFleetConfig[1][1].count=0;build()
assert(#Fractions[1].vehicles==2 and Fractions[1].vehicles[1].slot==3 and Fractions[1].vehicles[2].slot==4,'disabling ambulances does not renumber helicopter/sedan fuel IDs')
FractionFleetConfig[1][2].count=0;build()
assert(#Fractions[1].vehicles==1 and Fractions[1].vehicles[1].slot==4,'helicopters can be disabled without changing other slots')

defaults()
local group=FractionFleetConfig[1][1]
group.parking[1].x=1200;group.parking[1].y=-1400;group.parking[1].z=14;group.parking[1].rotation=90
group.model=400;group.rank=2
group.parking[3]={slot=20,x=1210,y=-1400,z=14,rotation=180};group.count=3
build()
local car=Fractions[1].vehicles[1]
assert(car.model==400 and car.rank==2 and car.p.x==1200 and car.p.y==-1400 and car.p.z==14 and car.p.rotation==90,'model, access rank and explicit parking position are configurable')
assert(Fractions[1].vehicles[3].slot==20 and Fractions[1].vehicles[4].slot==3,'new parking slot does not steal existing vehicle identity')

-- Actual spawn code must use stable slot IDs, even when array indexes change.
root,resourceRoot={},{}
Fraction={vehicles={},markers={},blips={}}
FractionDependencies={ready=function() return true end}
function addEventHandler() end
function getElementsByType() return {} end
function getTickCount() return 0 end
function createVehicle(model) return {model=model} end
function setVehicleColor(v,...) v.colors={...} end
function setVehicleEngineState() end
function setVehicleLocked() end
function setElementData() end
FractionDB={one=function() return {fuel=30} end}
local registered={}
exports={rp_car={registerFactionVehicle=function(self,vehicle,key) registered[key]=vehicle;return true end}}
dofile('resources/rp_fraction/server/world.lua')
Fraction.spawnFleet()
assert(registered['fraction:1:3'].model==487 and registered['fraction:1:20'].model==400,'native adapter fuel keys follow stable configured slots')
for slot=1,9 do
 local v=registered['fraction:4:'..slot]
 assert(v.model==(slot<=5 and 546 or (slot<=8 and 479 or 409)),'La Cosa Nostra retains 5 sedans, 3 SUVs and limousine in stable fleet slots')
 assert(table.concat(v.colors,',')==(slot==9 and '0,0,0,35,19,12' or '35,19,12,35,19,12'),'actual fleet spawn applies dark brown, with black/brown limousine')
end
for slot=6,8 do
 assert(registered['fraction:6:'..slot].model==400,'three Russian Mafia SUVs use Mercedes ML63 replacement 400')
end
assert(registered['fraction:5:6'].model==404 and table.concat(registered['fraction:5:6'].colors,',')=='35,5,12,0,0,0','actual Toyota spawn applies group color')
assert(table.concat(registered['fraction:5:1'].colors,',')=='35,5,12,0,0,0','actual Lexus spawn retains faction default')
assert(table.concat(registered['fraction:5:9'].colors,',')=='35,5,12,0,0,0','limousine matches Lexus and Toyota with black secondary color')

defaults()
FractionFleetConfig[1][1].count=1000;build()
assert(#Fractions[1].vehicles==4 and #FractionFleetWarnings==1,'excess count capped to configured parking capacity with one diagnostic')
FractionFleetConfig[1][1].parking[2].slot=1;build()
assert(#Fractions[1].vehicles==3 and #FractionFleetWarnings==2,'duplicate slot cannot register duplicate vehicle/fuel identity')
defaults();FractionFleetConfig[5][2].color={-1,5,12,0,0,0};build()
assert(#FractionFleetWarnings==1 and not Fractions[5].vehicles[6].color,'invalid optional colors safely fall back to faction color')
defaults();FractionFleetConfig[1][1].parking[1].x=0/0;build()
assert(#Fractions[1].vehicles==3 and #FractionFleetWarnings==1,'non-finite parking coordinates rejected')

-- The world must also start when an entire faction or every fleet is disabled.
FractionFleetConfig={};build()
function createObject() error('disabled fleets must not create a helipad') end
function createBlip() return {} end
function createColSphere() return {} end
function createMarker() return {} end
function createPickup() return {} end
function setElementInterior() end
function setElementDimension() end
Fraction.createWorld()
assert(#Fractions[1].vehicles==0 and #Fractions[2].vehicles==0,'disabled fleets do not break world creation')
print('Fleet config: counts, parking, models/ranks, stable fuel IDs, adapter keys, invalid input and fully disabled fleets passed')
