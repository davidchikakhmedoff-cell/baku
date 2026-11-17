-- Run from repository root using Lua 5.1. Deterministic MTA server simulation.
assert(loadfile('resources/rp_car/fuel_config.lua'))()
local tests=0
local function check(ok,message) tests=tests+1;assert(ok,message) end
local function near(a,b) return math.abs(a-b)<0.000001 end
check(FuelConfig.capacity(400)==60,'default tank')
FuelConfig.modelTanks[400]=80;check(FuelConfig.capacity(400)==80,'model tank override');FuelConfig.modelTanks[400]=nil
check(FuelConfig.clamp(nil,60)==30,'legacy null defaults to 30')
check(FuelConfig.clamp(100,60)==60,'legacy value capped')
check(FuelConfig.clamp(-5,60)==0,'negative clamp')
check(FuelConfig.used(0,0,500)==0,'no idle consumption')
check(near(FuelConfig.used(10,36,1000),0.0008),'8L/100km band')
check(near(FuelConfig.used(20,72,1000),0.002),'10L/100km band')
check(near(FuelConfig.used(30,108,1000),0.0036),'12L/100km band')
check(near(FuelConfig.used(40,144,1000),0.006),'15L/100km band')
check(FuelConfig.used(1000,72,500)==0,'teleport rejected')
check(FuelConfig.used(20,72,5000)==0,'stalled sample rejected')
local callbacks, timer, now, order, balance={},nil,0,nil,1000
root,resourceRoot={},{}
local player={kind='player',id=1};local car={kind='vehicle',x=0,engine=false,fuel=30}
local row={id=1,model=400,fuel=30,owner_account_id=1}
local notifications={}
local function addHandler(event,element,fn) callbacks[event]=fn end
addEventHandler=addHandler
function addEvent() end
function getResourceFromName() return {} end
function getResourceState() return 'running' end
function isElement(el) return type(el)=='table' and not el.destroyed end
function getElementData(el,key)
 if el==player then if key=='auth:loggedIn' then return true elseif key=='auth:playerId' then return player.id end end
 return el[key]
end
function setElementData(el,key,value) el[key]=value end
function getElementType(el) return el.kind end
function getTickCount() return now end
function getRealTime() return {timestamp=100} end
function getPedOccupiedVehicle() return player.car end
function getPedOccupiedVehicleSeat() return player.seat or 0 end
function isPedDead() return player.dead or false end
function getElementPosition(el) return el.x or 0,0,0 end
function getElementDimension(el) return el.dimension or 0 end
function getElementInterior(el) return el.interior or 0 end
function getElementVelocity() return (car.speed or 0)/180,0,0 end
function getVehicleEngineState() return car.engine end
function setVehicleEngineState(v,value) v.engine=value end
function getVehicleOccupant() return player.car==car and player or false end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function isElementWithinColShape() return car.inZone end
function createColSphere() return {} end
function createBlip() return {} end
function setTimer(fn) timer=fn end
function getPlayerMoney() return balance end
function setPlayerMoney(p,value) balance=value end
function getElementsByType() return {player} end
function getResourceRootElement() return {} end
function triggerClientEvent() end
local function copy(o) local c={} for k,v in pairs(o) do c[k]=v end return c end
local dbFuel=30
RPCarDB={connection=true,vehicles={[1]=row},exec=function(sql,value)
 if sql:find('SET fuel') then dbFuel=value end
 return true
end}
local function sqlExec(sql,...)
 local args={...}
 if sql:find('INSERT INTO car_fuel_orders') then
  if balance<args[6] then return false end
  balance=balance-args[6];order={id=1,account_id=args[1],vehicle_id=args[2],base=args[3],requested=args[4],price=args[5],paid=args[6],delivered=0,settled=0}
 elseif sql:find('SET delivered') then order.delivered=args[1]
 elseif sql:find('SET charged') and order.settled==0 then order.charged=args[1];order.settled=1;balance=balance+order.paid-order.charged end
 return true
end
local function sqlQuery(sql,...)
 if sql:find('FROM players') then return {{money=balance}} end
 if sql:find('last_insert_rowid') then return order and {copy(order)} or {} end
 if sql:find('SELECT settled') then return {{settled=order.settled}} end
 if sql:find('SELECT delivered') then return {{delivered=order.delivered}} end
 if sql:find('FROM car_fuel_orders') then return order and order.settled==0 and {copy(order)} or {} end
 return {}
end
exports={rp_core={AuthDBQuery=function(self,...) return sqlQuery(...) end,AuthDBExec=function(self,...) return sqlExec(...) end,
 getAuthPlayerId=function() return player.id end,sendCoreNotification=function(self,p,message) notifications[#notifications+1]=message end}}
assert(loadfile('resources/rp_car/fuel_server.lua'))()
callbacks.onResourceStart();FuelSystem.attach(car,row);player.car=car;car.inZone=true
local function event(name,...)
 now=now+500;client=player;callbacks[name](...);client=nil
end
local function tick(ms) now=now+(ms or 500);timer() end
check(FuelSystem.recovered,'journal recovery initializes')
event('car:fuelBuy',-1);check(not order,'negative purchase rejected')
event('car:fuelBuy',0/0);check(not order,'NaN rejected')
event('car:fuelBuy',math.huge);check(not order,'infinity rejected')
event('car:fuelBuy','10');check(not order,'string rejected')
event('car:fuelBuy',31);check(not order,'overfill rejected')
player.id=2;event('car:fuelBuy',10);check(not order,'non-owner rejected');player.id=1
player.seat=1;event('car:fuelBuy',10);check(not order,'passenger rejected');player.seat=0
car.inZone=false;event('car:fuelBuy',10);check(not order,'outside zone rejected');car.inZone=true
car.engine=true;event('car:fuelBuy',10);check(not order,'running engine rejected');car.engine=false
car.speed=10;event('car:fuelBuy',10);check(not order,'moving vehicle rejected');car.speed=0
balance=2;event('car:fuelBuy',10);check(not order,'insufficient funds rejected');balance=1000
event('car:fuelBuy',10);check(order and balance==950,'escrow charged once')
check(not FuelSystem.canStart(car),'engine blocked during refuelling')
event('car:fuelBuy',10);check(balance==950,'duplicate purchase rejected')
tick();check(near(FuelSystem.get(car),32),'progress uses elapsed time, capped at 1s')
event('car:fuelCancel');check(balance==990 and near(dbFuel,32),'cancel refunds only unissued litres')
event('car:fuelCancel');check(balance==990,'cancel cannot refund twice')
check(FuelSystem.canStart(car),'engine restored after cancellation')
event('car:fuelBuy',2);tick(1000);check(balance==980 and near(dbFuel,34),'successful full delivery persisted')
event('car:fuelBuy',4);car.inZone=false;tick();check(balance==980,'leaving zone refunds undelivered fuel');car.inZone=true
car.engine=true;car.speed=72;tick();car.x=car.x+10;tick();check(FuelSystem.get(car)<34,'distance consumption')
local before=FuelSystem.get(car);car.x=car.x+1000;tick();check(near(FuelSystem.get(car),before),'server jump not consumed')
car.engine=false;car.x=car.x+10;tick();check(near(FuelSystem.get(car),before),'engine-off motion not consumed')
FuelSystem.detach(car);check(near(dbFuel,before),'despawn saves')
row.fuel=dbFuel;FuelSystem.attach(car,row);check(near(FuelSystem.get(car),before),'spawn restores fuel')
FuelSystem.detach(car);row.fuel=0;FuelSystem.attach(car,row);check(not FuelSystem.canStart(car),'empty tank blocks engine')
car.engine=true;tick();check(not car.engine,'empty tank shuts engine off')
-- Simulate a server restart after a charged order delivered only 3 litres.
order={id=2,account_id=1,vehicle_id=1,base=10,requested=10,delivered=3,price=5,paid=50,settled=0}
balance=950;row.fuel=10;dbFuel=10
assert(loadfile('resources/rp_car/fuel_server.lua'))()
callbacks.onResourceStart()
check(balance==985,'restart refunds 7 unissued litres')
check(near(dbFuel,13) and near(row.fuel,13),'restart updates database AND cached spawn row')
FuelSystem.attach(car,row);check(near(FuelSystem.get(car),13),'post-restart spawn retains delivered fuel')
callbacks.onResourceStart();check(balance==985,'second recovery cannot duplicate refund')
print('Fuel: '..tests..' checks passed')
