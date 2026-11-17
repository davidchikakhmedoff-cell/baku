-- Run from repository root using Lua 5.1; production parking-detach path.
local f=assert(io.open('resources/rp_car/server.lua','rb'));local code=f:read('*a');f:close()
local body=assert(code:match('local function clearVehicleParking%(.-\nend'))
local active=assert(code:match('local function isUnparkedActiveVehicle%(.-\nend'))
local vehicle={};local row={id=1,owner_account_id=7,house_id=5,parking_slot=1,lights_on=1,fuel=22}
local updates
local env={VehicleStatuses={active='active',noParking='no_parking'},elementByVehicleId={[1]=vehicle},respawnLocks={},RPCarDB={vehicles={[1]=row}}}
setmetatable(env,{__index=_G})
env.isElement=function(v) return v==vehicle end
env.getElementPosition=function() return 10,20,30 end
env.getElementRotation=function() return 0,0,90 end
env.getElementInterior=function() return 0 end
env.getElementDimension=function() return 0 end
env.getElementHealth=function() return 800 end
env.getVehicleEngineState=function() return true end
env.isVehicleLocked=function() return false end
env.setElementData=function() end
env.setPersonalRuntime=function(v,r) assert(r.owner_account_id==7) end
env.applyPersonalVehicleState=function(v,r) assert(r.engine_on==1 and r.locked==0) end
env.syncVehicleToner=function() end
env.destroyPersonalVehicle=function() error('live car must not be destroyed') end
env.RPCarDB.updateVehicle=function(id,data) updates=data;for k,v in pairs(data) do row[k]=v end;return true end
local factory=assert(loadstring(body..'\n'..active..'\nreturn clearVehicleParking,isUnparkedActiveVehicle'));setfenv(factory,env)
local detach,unparked=factory()
assert(detach(1,'no_parking',true))
assert(row.owner_account_id==7 and row.house_id==0 and row.parking_slot==0)
assert(row.status=='active' and row.engine_on==1 and row.locked==0 and row.lights_on==1)
assert(row.health==800 and row.fuel==22 and row.x==10 and row.y==20)
assert(unparked(row),'active car without house remains eligible for saved-position spawn')
assert(not unparked({status='no_parking',house_id=0,parking_slot=0}),'stored cars are not revived automatically')
print('House detach: ownership, live state, saved position and restart eligibility passed')
