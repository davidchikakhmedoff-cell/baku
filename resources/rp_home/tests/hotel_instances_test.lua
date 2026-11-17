-- Run from the repository root with Lua 5.1.
local f=assert(io.open('resources/rp_home/server.lua','rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local cfg=assert(io.open('resources/rp_home/config.lua','rb'))
local config=cfg:read('*a');cfg:close()
local base=assert(tonumber(config:match('hotelDimensionBase%s*=%s*(%d+)')))
local make=assert(source:match('makeHotelDimension = function%(hotelId%).-\nend'))
local exit=assert(source:match('local function exitHotel%(player, publicId%).-\nend'))
local env={HomeConfig={hotelDimensionBase=base},RPHomeDB={hotels={}},tonumber=tonumber}
setmetatable(env,{__index=_G})
env.hotelConfig=function() return {dimensionBase=base} end
env.isLogged=function() return true end
env.getElementDimension=function(p) return p.dimension end
env.getElementInterior=function(p) return p.interior end
env.hotelInteriorConfig=function() return {interior=5} end
env.getHotelOutsidePosition=function(h) return {x=h.id*100,y=0,z=10,interior=0,dimension=0} end
env.setElementDimension=function(p,d) assert(d>=0 and d<=65535);p.dimension=d end
env.setElementInterior=function(p,i) p.interior=i end
env.setElementPosition=function(p,x) p.x=x end
env.setPedRotation=function() end
env.setCameraTarget=function() end
env.fadeCamera=function() end
local loader=assert(loadstring(make..'\n'..exit..'\nreturn exitHotel'));setfenv(loader,env)
local exitHotel=loader()
local seen={}
for id=1,4 do
 env.RPHomeDB.hotels[id]={id=id}
 local dim=env.makeHotelDimension(id)
 assert(dim>=0 and dim<=65535 and not seen[dim],'unique supported MTA dimension')
 seen[dim]=true
 local player={dimension=dim,interior=5}
 assert(exitHotel(player,-3),'can exit actual hotel even with a stale selection of hotel 3')
 assert(player.x==id*100,'exit must match actual hotel, not client selection')
end
assert(not exitHotel({dimension=0,interior=5},-3),'shared interior alone cannot select a hotel exit')
assert(not exitHotel({dimension=base+1,interior=0},-1),'wrong interior cannot exit')
print('Hotels 1-4: unique valid dimensions and correct exits; stale/wrong contexts rejected')
