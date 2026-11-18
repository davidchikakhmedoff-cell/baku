-- Run from repository root using Lua 5.1.
local f=assert(io.open('resources/rp_car/database.lua','rb'));local source=f:read('*a');f:close()
local method=assert(source:match('function RPCarDB.createVehicle%(data%).-\nend'))
local args,mode,deleted
RPCarDB={connection={},vehicles={}}
function isElement(value) return value==RPCarDB.connection end
function RPCarDB.reload()
 RPCarDB.vehicles={}
 if mode~='missing' then RPCarDB.vehicles[42]={id=42,owner_account_id=mode=='owner' and 99 or 7,house_id=3,parking_slot=2} end
end
function RPCarDB.exec(sql,id) deleted=id;return true end
function dbQuery(connection,sql,...) args={...};return {} end
function dbPoll() if mode=='sqlerror' then return false,1,'SQL error' end return {},1,42 end
function outputDebugString() end
FuelConfig={initial=30};VehicleStatuses={active='active'}
local stamp=function() return 100 end
local fn=assert(loadstring('local stamp=...\n'..method));fn(stamp)
local data={owner_account_id=7,model=400,custom_name='Car',gov_price=1000,house_id=3,parking_slot=2,x=1,y=2,z=3}
assert(RPCarDB.createVehicle(data)==42,'uses actual INSERT ID')
assert(args[1]==7 and args[24]==3 and args[25]==2,'owner and parking passed to INSERT')
mode='sqlerror';assert(not RPCarDB.createVehicle(data),'SQL error cannot report purchase success')
mode='owner';deleted=nil;assert(not RPCarDB.createVehicle(data) and deleted==42,'wrong owner rolls back only inserted vehicle')
mode='missing';assert(not RPCarDB.createVehicle(data),'missing saved row cannot report success')
print('Purchase record: insert identity, ownership, parking and failure checks passed')

local serverFile=assert(io.open('resources/rp_car/server.lua','rb'))
local server=serverFile:read('*a');serverFile:close()
local recover=assert(server:match('recoverPlayerVehicleParking = function%(player%).-\nend'))
local owner=7;local house={id=3};local authorized=true;local called
local env=setmetatable({accountId=function() return owner end,getPlayerHouse=function() return house end,
 accountOwnsHouse=function() return authorized end,assignHouseVehicles=function(id,home) called={id,home};return 1 end},{__index=_G})
local restore=assert(loadstring(recover..'\nreturn recoverPlayerVehicleParking'));setfenv(restore,env);restore=restore()
assert(restore({})==1 and called[1]==7 and called[2]==3,'restores only current owner parking')
authorized=false;called=nil;assert(restore({})==0 and not called,'never reassign to a stale property')
print('Parking recovery: current-property ownership checks passed')
