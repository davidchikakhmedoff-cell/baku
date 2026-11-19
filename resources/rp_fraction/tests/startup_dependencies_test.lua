function setVehicleDamageProof() end
-- Reproduce updated files with stale loaded dependency exports, then recovery.
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local resources={rp_core={},rp_car={}}
local states={rp_core='running',rp_car='running'}
local loaded,handlers,timers,warnings={},{},{},{}
local function readExports(name)
 local f=assert(io.open('resources/'..name..'/meta.xml'));local xml=f:read('*a');f:close()
 local list={};for fn in xml:gmatch('<export%s+function="([^"]+)"') do list[#list+1]=fn end
 return list
end
for name in pairs(resources) do resources[name].name=name;loaded[name]=readExports(name) end
local function removeExport(name,fn)
 for i,value in ipairs(loaded[name]) do if value==fn then table.remove(loaded[name],i);return end end
 error('test export not found: '..fn)
end
function getResourceFromName(name) return resources[name] end
function getResourceState(resource) return states[resource.name] end
function getResourceExportedFunctions(resource) return loaded[resource.name] end
function outputDebugString(text,level) if level==2 then warnings[#warnings+1]=text end end
function addEvent() end
function addEventHandler(event,element,fn)
 handlers[event]=handlers[event] or {};table.insert(handlers[event],{element=element,fn=fn})
end
function setTimer(fn,interval,repetitions)
 local timer={fn=fn,interval=interval,repetitions=repetitions};timers[#timers+1]=timer;return timer
end
function killTimer(timer) timer.killed=true end
function getElementsByType() return {} end
local migrated,world,fleet=0,0,0
FractionDB={available=function() return true end,init=function() migrated=migrated+1 end}
dofile('resources/rp_fraction/server/dependencies.lua')
dofile('resources/rp_fraction/server/main.lua')
dofile('resources/rp_fraction/server/world.lua')
local spawnFleet=Fraction.spawnFleet
Fraction.createWorld=function() world=world+1 end
Fraction.spawnFleet=function() fleet=fleet+1 end
Fraction.tick=function() end
removeExport('rp_core','getPlayerByDynamicID')
removeExport('rp_car','registerFactionVehicle')
for _,handler in ipairs(handlers.onResourceStart) do if handler.element==resourceRoot then handler.fn(resources.rp_fraction) end end
assert(not Fraction.ready and migrated==0 and world==0 and fleet==0,'old dependencies cannot start partial world or migrations')
assert(#warnings==1 and warnings[1]:find('rp_core:getPlayerByDynamicID',1,true),'loaded core version diagnosed')
assert(Fraction.account({})==false and Fraction.player(1)==nil,'commands cannot call stale auth exports while waiting')
local retry=timers[1];assert(retry.interval==5000,'one bounded-interval startup retry')
for i=1,100 do retry.fn() end
assert(#warnings==1 and migrated==0,'waiting does not spam logs or repeat migrations')
loaded.rp_core=readExports('rp_core');retry.fn()
assert(#warnings==2 and warnings[2]:find('rp_car:registerFactionVehicle',1,true),'old car export diagnosed before any spawn')
loaded.rp_car=readExports('rp_car');retry.fn()
assert(Fraction.ready and migrated==1 and world==1 and fleet==1 and retry.killed,'updated loaded dependencies resume startup once')
local count=#timers;Fraction.tryStart();assert(migrated==1 and #timers==count,'no duplicate startup timers')

-- Even with exports declared, a broken/rejected registration must stop at one
-- vehicle, rather than being repeated for all 52 cars on every fleet tick.
Fraction.spawnFleet=spawnFleet
local created,destroyed,calls,reject=0,0,0,true
function createVehicle() created=created+1;return {} end
function destroyElement() destroyed=destroyed+1 end
function setVehicleColor() end
function setVehicleEngineState() end
function setVehicleLocked() end
function setElementData() end
function getTickCount() return 0 end
FractionDB.one=function() return {fuel=30} end
exports={rp_car={registerFactionVehicle=function() calls=calls+1;return not reject end}}
Fraction.spawnFleet()
assert(created==1 and destroyed==1 and calls==1 and FractionDependencies.blocked,'registration failure removes partial car and pauses fleet')
local warningCount=#warnings
for i=1,100 do Fraction.fleetTick() end
assert(calls==1 and created==1 and #warnings==warningCount,'no repeated calls, vehicles or warnings after adapter failure')
reject=false
for _,handler in ipairs(handlers.onResourceStart) do if handler.element==root then handler.fn(resources.rp_car) end end
Fraction.spawnFleet()
local total=0;for _ in pairs(Fraction.vehicles) do total=total+1 end
assert(total==52 and calls==53,'car restart clears failure and recreates all 52 service vehicles')
print('Startup dependencies: stale core/car, guarded commands, quiet wait, one startup, registration failure and full fleet recovery passed')
