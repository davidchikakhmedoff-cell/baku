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
assert(personal.handling.driveType=='awd' and personal.handling.suspensionLowerLimit==-0.23,'shared dealership handler uses 421 AWD and mild lowering')
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
