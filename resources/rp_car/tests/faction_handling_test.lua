dofile('resources/rp_car/handling/base.lua')
local file=assert(io.open('resources/rp_car/server.lua','rb'));local sourceCode=file:read('*a');file:close()
local supported=assert(sourceCode:match('(local supportedHandlingProperties = {.-\n})'))
local apply=assert(sourceCode:match('(local function applyConfiguredHandling.-)\nfunction applyPersonalVehicleHandling'))
root,resourceRoot={},{}
function isElement(e) return type(e)=='table' end
function getElementModel(e) return e.model end
function getVehicleHandling(e) return e.handling end
function setVehicleHandling(e,key,value) e.handling[key]=value;return true end
assert(loadstring(supported..'\n'..apply))()
local function vehicle() return {model=421,handling={driveType='rwd',suspensionLowerLimit=-0.2}} end
local personal=vehicle();assert(applyConfiguredVehicleHandling(personal))
assert(personal.handling.driveType=='awd' and personal.handling.suspensionLowerLimit==-0.13,'shared dealership handler uses 421 AWD and mild lowering')
local r={};sourceResource=r
function getResourceFromName() return r end
function getVehicleType() return 'Automobile' end
function getTickCount() return 0 end
function setElementFrozen() end
function setElementData() end
function setTimer() end
function addEvent() end
function addEventHandler() end
FuelSystem={attachExternal=function() end}
CarConfig={parkingSettleDelay=1000}
dofile('resources/rp_car/faction_adapter.lua')
local fleet=vehicle();assert(registerFactionVehicle(fleet,'fraction:5:1',30))
assert(fleet.handling.driveType==personal.handling.driveType and fleet.handling.suspensionLowerLimit==personal.handling.suspensionLowerLimit,'faction registration applies actual shared handling function')
VehicleHandling[421].suspensionLowerLimit=-0.25
local nextSpawn=vehicle();assert(registerFactionVehicle(nextSpawn,'fraction:5:2',30))
assert(nextSpawn.handling.suspensionLowerLimit==-0.25,'editing the one shared profile reaches subsequent faction spawns')
print('Faction handling: actual shared dealership function, 421 AWD/lowering and config changes applied on fleet registration passed')

local donor={suspensionForceLevel=1.5,suspensionDamping=0.1,suspensionHighSpeedDamping=0,
 suspensionUpperLimit=0.35,suspensionLowerLimit=-0.24,suspensionFrontRearBias=0.5,suspensionAntiDiveMultiplier=0.3,
 mass=2500,driveType='awd'}
function getOriginalHandling(model) assert(model==579);return donor end
local toyota={model=404,handling={mass=1200,driveType='fwd'}}
assert(applyConfiguredVehicleHandling(toyota))
for _,property in ipairs(VehicleSuspensionReferenceProperties) do assert(toyota.handling[property]==donor[property],'Toyota suspension copies original Huntley '..property) end
assert(toyota.handling.mass==1200 and toyota.handling.driveType=='fwd','unrequested engine/mass/drive properties remain untouched')
local factionToyota={model=404,handling={}}
assert(registerFactionVehicle(factionToyota,'fraction:5:6',30))
assert(factionToyota.handling.suspensionLowerLimit==donor.suspensionLowerLimit,'real faction registration receives the same suspension correction')
assert(donor.mass==2500 and donor.suspensionLowerLimit==-0.24,'original donor handling was not mutated')
print('Toyota handling: original Huntley suspension shared by direct and faction spawns, donor/performance isolation passed')

local hummer={model=479,handling={mass=1700,driveType='rwd'}}
assert(applyConfiguredVehicleHandling(hummer))
for _,property in ipairs(VehicleSuspensionReferenceProperties) do
 local expected=donor[property]+(property=='suspensionLowerLimit' and -0.02 or 0)
 assert(math.abs(hummer.handling[property]-expected)<0.000001,'Hummer receives SUV suspension geometry with a small lift')
end
assert(hummer.handling.mass==1700 and hummer.handling.driveType=='rwd','wheel correction does not change unrequested performance')
local factionHummer={model=479,handling={}}
assert(registerFactionVehicle(factionHummer,'fraction:4:6',30))
assert(math.abs(factionHummer.handling.suspensionLowerLimit-(donor.suspensionLowerLimit-0.02))<0.000001,'Hummer faction registration receives the same small lift')
