-- Run from repository root. Real event-driven helper with simulated MTA seats.
local player,vehicle={},{}
localPlayer=player;root={};local events={}
function addEventHandler(name,element,fn) events[name]=fn end
local occupied,fullySeated,dead=true,true,false
function isElement(v) return v==player or v==vehicle end
function isPedDead() return dead end
function getPedOccupiedVehicle() return occupied and vehicle or false end
function getPedOccupiedVehicleSeat() return 0 end
function isPedInVehicle() return fullySeated end
function getVehicleOccupant() return fullySeated and player or false end
-- A stale task must never disable controls after a completed entry or restart.
function getPedTask() return 'TASK_COMPLEX_ENTER_CAR_AS_DRIVER' end
assert(loadfile('resources/rp_car/interaction_shared.lua'))()
assert(CarInteraction.ready(player),'already seated after resource restart')
source=vehicle;events.onClientVehicleStartEnter(player)
assert(not CarInteraction.ready(player),'entry not complete')
assert(not CarInteraction.canToggleLock(player),'occupied entry animation blocked')
events.onClientVehicleEnter(player)
assert(CarInteraction.ready(player),'completed entry ignores stale GTA task')
assert(CarInteraction.canToggleLock(player),'seated locks allowed')
fullySeated=false;assert(not CarInteraction.ready(player),'invalid occupation blocked')
occupied=false;assert(CarInteraction.canToggleLock(player),'outside locks remain available')
events.onClientVehicleStartEnter(player)
assert(CarInteraction.canToggleLock(player),'outside locks remain available during approach')
events.onClientVehicleExit(player)
occupied=true;fullySeated=true;assert(CarInteraction.ready(player),'warp/seat after canceled approach')
dead=true;assert(not CarInteraction.ready(player) and not CarInteraction.canToggleLock(player),'dead player blocked')
print('Interaction: restart, actual entry events, stale tasks, warp and outside-lock exception passed')
