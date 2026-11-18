-- Production startup and destruction handlers, with service order controlled.
local f=assert(io.open('resources/rp_car/server.lua','rb'));local sourceCode=f:read('*a');f:close()
local spawn=assert(sourceCode:match('local function spawnAllPersonalVehicles%(.-\nend'))
local destroy=assert(sourceCode:match('addEventHandler%("onElementDestroy", root, function%(.-\nend%)'))
local ready=false;local removed,created=0,0
local row={id=1,status='active',owner_account_id=7,house_id=3,parking_slot=1}
local parking={house_id=3,slot=1,x=222,y=333,z=10}
local env={RPCarDB={vehicles={[1]=row}},VehicleStatuses={destroyed='destroyed'},root={},resourceStopping=false}
setmetatable(env,{__index=_G})
env.coreRunning=function() return true end
env.homeRunning=function() return ready end
env.isVehicleStoredWithoutParking=function() return false end
env.validateVehicleParking=function() return ready and parking or false end
env.clearVehicleParking=function() removed=removed+1;row.house_id=0 end
env.isUnparkedActiveVehicle=function() return false end
env.createPersonalVehicle=function(r,park,p) assert(r==row and park==true and p==parking);created=created+1 end
env.getElementsByType=function() return {} end
local fn=assert(loadstring(spawn..'\nreturn spawnAllPersonalVehicles'));setfenv(fn,env);fn=fn()
fn();assert(removed==0 and created==0 and row.house_id==3,'dependencies unavailable must not strip parking')
ready=true;fn();assert(created==1 and removed==0,'active saved car returns to its assigned parking')
local callback
env.addEventHandler=function(name,element,cb) callback=cb end
local loadDestroy=assert(loadstring(destroy));setfenv(loadDestroy,env);loadDestroy()
env.resourceStopping=true;callback();assert(removed==0,'shutdown destruction does not alter persistence')
env.resourceStopping=false;ready=false;callback();assert(removed==0,'dependency shutdown does not strip ownership/parking')
print('Startup persistence: dependency order, parking restoration and shutdown preservation passed')
