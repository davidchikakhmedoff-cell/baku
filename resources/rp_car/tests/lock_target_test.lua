-- Run from repository root, Lua 5.1. Execute the production target resolver.
local f=assert(io.open('resources/rp_car/server.lua','rb'))
local source=f:read('*a');f:close()
local resolver=assert(source:match('local function resolveLockVehicle%(.-\nend'))
local player={owner=1,x=0,dimension=0,interior=0}
local own={id=10,x=4,dimension=0,interior=0,ownerCache=999}
local foreign={id=11,x=2,dimension=0,interior=0}
local showcase={id=12,x=1,dimension=0,interior=0}
local vehicles={[own]=10,[foreign]=11}
local rows={[10]={id=10,owner_account_id=1,house_id=0,status='no_parking'},[11]={id=11,owner_account_id=2}}
local env={CarConfig={lockServerDistance=16},personalByElement=vehicles,showcaseByElement={[showcase]=true},RPCarDB={vehicles=rows}}
setmetatable(env,{__index=_G})
env.isElement=function(v) return type(v)=='table' end
env.getElementPosition=function(v) return v.x,0,0 end
env.getElementDimension=function(v) return v.dimension end
env.getElementInterior=function(v) return v.interior end
env.getDistanceBetweenPoints3D=function(x,y,z,a,b,c) return math.abs(x-a) end
env.getPersonalRuntime=function(v) return {vehicleId=v.id,ownerAccountId=v.ownerCache} end
env.ownsVehicleRow=function(p,row) return row and p.owner==row.owner_account_id end
env.setPersonalRuntime=function(v,row) v.ownerCache=row.owner_account_id end
local fn=assert(loadstring(resolver..'\nreturn resolveLockVehicle'));setfenv(fn,env);local resolve=fn()
assert(resolve(player,foreign)==own,'foreign aimed car must not block owned neighbour')
assert(resolve(player,showcase)==own,'showroom aimed car must not block owner')
assert(resolve(player,nil)==own,'camera miss falls back to owned car')
assert(own.ownerCache==1,'cache refreshed from actual database owner')
rows[10].house_id=20;rows[10].status='active'
assert(resolve(player,own)==own,'reassigning house keeps lock access')
rows[10].house_id=0;rows[10].status='no_parking'
assert(resolve(player,own)==own,'selling house keeps lock access')
own.dimension=1;assert(not resolve(player,nil),'different dimension rejected');own.dimension=0
own.x=17;assert(not resolve(player,nil),'out of range rejected');own.x=4
rows[10].owner_account_id=2;assert(not resolve(player,own),'actual vehicle sale removes previous owner access')
print('Lock target: 9 ownership, house resale and target-selection checks passed')
