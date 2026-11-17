local player,vehicle={},{}
localPlayer=player;root={}
local events={}
function addEventHandler(event,element,fn) events[event]=fn end
local task,occupied,fullySeated,dead=nil,true,true,false
function isElement(el) return el==player or el==vehicle end
function isPedDead() return dead end
function getPedTask(p,kind,level) if kind=='primary' and level==2 then return task end end
function getPedOccupiedVehicle() return occupied and vehicle or false end
function getPedOccupiedVehicleSeat() return 0 end
function isPedInVehicle() return fullySeated end
function getVehicleOccupant() return fullySeated and player or false end
assert(loadfile('resources/rp_car/interaction_shared.lua'))()
assert(CarInteraction.ready(player),'fully seated driver allowed')
for _,name in ipairs({'TASK_COMPLEX_ENTER_CAR_AS_DRIVER','TASK_COMPLEX_ENTER_CAR_AS_PASSENGER','TASK_SIMPLE_CAR_GET_IN','TASK_SIMPLE_CAR_CLOSE_DOOR_FROM_INSIDE','TASK_COMPLEX_LEAVE_CAR','TASK_SIMPLE_CAR_GET_OUT'}) do
 task=name;assert(not CarInteraction.ready(player),name..' must block actions')
end
task=nil;fullySeated=false;assert(not CarInteraction.ready(player),'partial occupation rejected')
occupied=false;assert(CarInteraction.ready(player),'on-foot locking retained')
task='TASK_COMPLEX_ENTER_CAR_AS_DRIVER';assert(not CarInteraction.ready(player),'approach animation rejected before occupation')
assert(CarInteraction.canToggleLock(player),'outside lock is exempt during approach')
occupied=true;fullySeated=false;assert(not CarInteraction.canToggleLock(player),'lock remains blocked during occupied entry')
task=nil;fullySeated=true;assert(CarInteraction.canToggleLock(player),'seated lock allowed')
task=nil;dead=true;assert(not CarInteraction.ready(player),'dead player rejected')
assert(not CarInteraction.canToggleLock(player),'dead player cannot lock')
dead=false;occupied=true;fullySeated=true;task='TASK_COMPLEX_ENTER_CAR_AS_DRIVER'
source=vehicle;events.onClientVehicleEnter(player)
assert(CarInteraction.ready(player),'completed dealership warp overrides a lingering entry task')
events.onClientVehicleStartExit(player)
assert(not CarInteraction.ready(player),'starting exit removes the completed-entry exception')
print('Vehicle interaction: seating, exterior locks and dealership warp checks passed')
