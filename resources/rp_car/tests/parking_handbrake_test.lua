local f=assert(io.open('resources/rp_car/server.lua','rb'));local code=f:read('*a');f:close()
local schedule=assert(code:match('local function scheduleParkingFreeze%(.-\nend'))
local car={};local callback,delay
local row={id=1,status='parked',engine_on=0}
local env={CarConfig={parkingSettleDelay=1000},VehicleStatuses={parked='parked'},handbrakeVehicles={},RPCarDB={vehicles={[1]=row}}}
setmetatable(env,{__index=_G})
env.isElement=function(v) return v==car and not car.destroyed end
env.setElementFrozen=function(v,value) v.frozen=value end
env.setElementData=function(v,key,value) v[key]=value end
env.setTimer=function(fn,ms,count,v,id) delay=ms;callback=function() fn(v,id) end end
env.getElementPosition=function() return 10,20,30 end
env.getElementRotation=function() return 0,0,90 end
env.getElementInterior=function() return 0 end
env.getElementDimension=function() return 0 end
env.RPCarDB.updateVehicle=function(id,data) for k,v in pairs(data) do row[k]=v end return true end
env.applyPersonalVehicleState=function() end
env.syncVehicleToner=function() end
env.setElementVelocity=function() end
env.setElementAngularVelocity=function() end
local fn=assert(loadstring(schedule..'\nreturn scheduleParkingFreeze'));setfenv(fn,env);fn=fn()
fn(car,1);assert(delay==1000 and not car.frozen and not env.handbrakeVehicles[car],'one second settling period')
callback();assert(car.frozen and env.handbrakeVehicles[car] and car['car:handbrake'],'custom B handbrake and HUD state both set')
car.frozen=false;car['car:handbrake']=false;env.handbrakeVehicles[car]=nil;row.engine_on=1
fn(car,1);callback();assert(not car.frozen and not env.handbrakeVehicles[car],'do not freeze a car already started by its driver')
print('Parking spawn: one-second delay, custom handbrake and active-driver guard passed')
