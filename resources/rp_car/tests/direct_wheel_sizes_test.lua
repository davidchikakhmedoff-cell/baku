dofile('resources/rp_car/handling/base.lua')
root,resourceRoot={},{}
local handlers,resources,wheels,originals={}, {},{},{}
local expected={}
for model,cfg in pairs(VehicleHandling) do if cfg.wheelSize then
 expected[model]=cfg;resources[cfg.modelResource]=resources[cfg.modelResource] or {state='loaded'}
 wheels[model]={front_axle=0.61,rear_axle=0.63};originals[model]={front_axle=0.61,rear_axle=0.63}
end end
VehicleHandling=expected
function getResourceFromName(name) return resources[name] end
function getResourceState(r) return r.state end
function getVehicleModelWheelSize(model,axle) return wheels[model][axle] end
local changes=0
function setVehicleModelWheelSize(model,axle,value) changes=changes+1;wheels[model][axle]=value end
function addEventHandler(name,element,fn) handlers[name]=handlers[name] or {};handlers[name][element]=fn end
local timer
function setTimer(fn) timer={fn=fn};return timer end
function isTimer(t) return not t.dead end
function killTimer(t) t.dead=true end
function outputChatBox() error('wheel APIs are available') end
dofile('resources/rp_car/handling/compatibility_client.lua')
local function fire(event,element)
 handlers[event][element]();if timer and not timer.dead then timer.fn();timer.dead=true end
end
fire('onClientResourceStart',root);assert(changes==0,'inactive resources cannot change stock model wheel sizes')
for _,r in pairs(resources) do r.state='running' end
fire('onClientResourceStart',root)
local count=0
for model,cfg in pairs(expected) do
 count=count+1
 assert(wheels[model].front_axle==cfg.wheelSize.front_axle and wheels[model].rear_axle==cfg.wheelSize.rear_axle,'physical sizes apply to both independent axles')
end
assert(count==10 and changes==count*2,'all seven civil and three service models receive correction once')
fire('onClientResourceStart',root);assert(changes==count*2,'unchanged sizes never restream models repeatedly')
resources.bmw_i8.state='stopped';fire('onClientResourceStop',root)
assert(wheels[451].front_axle==originals[451].front_axle and wheels[550].front_axle==expected[550].wheelSize.front_axle,'stopping one resource restores only its model')
resources.rp_fraction.state='stopped';fire('onClientResourceStop',root)
for _,id in ipairs({416,582,523}) do assert(wheels[id].front_axle==originals[id].front_axle,'stopping faction resource restores each service vehicle') end
fire('onClientResourceStop',resourceRoot)
for model in pairs(expected) do
 assert(wheels[model].front_axle==originals[model].front_axle and wheels[model].rear_axle==originals[model].rear_axle,'stopping rp_car restores every original physical size')
end
print('Direct wheel sizes: resource gating, ten models, both axles, no repeated restream and independent restoration passed')
