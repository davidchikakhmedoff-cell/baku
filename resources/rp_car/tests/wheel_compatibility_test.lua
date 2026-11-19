dofile('resources/rp_car/handling/base.lua')
root,resourceRoot={},{}
local handlers,timer,calls={},nil,{}
local toyota={state='loaded'}
local wheel={[479]={front_axle=0.65,rear_axle=0.66},[404]={front_axle=0.7,rear_axle=0.7},[579]={front_axle=0.82,rear_axle=0.84}}
function addEventHandler(name,element,fn) handlers[name]=handlers[name] or {};handlers[name][element]=fn end
function getResourceFromName(name) assert(name=='toyota_sequoia');return toyota end
function getResourceState(r) return r.state end
function getVehicleModelWheelSize(model,axle) return wheel[model][axle] end
function setVehicleModelWheelSize(model,axle,value)
 assert(model==404 or model==479,'the occupied Huntley model must never be modified')
 calls[#calls+1]={model,axle,value};wheel[model][axle]=value;return true
end
function setTimer(fn,delay) assert(delay==50);timer={fn=fn};return timer end
function isTimer(t) return not t.dead end
function killTimer(t) t.dead=true end
local warnings=0
function outputChatBox() warnings=warnings+1 end
local function fire(name,element) handlers[name][element]() end
local function update() assert(not timer.dead);timer.fn();timer.dead=true end
dofile('resources/rp_car/handling/compatibility_client.lua')
fire('onClientResourceStart',root);update();assert(#calls==2 and wheel[479].front_axle==0.82 and wheel[479].rear_axle==0.84,'Hummer correction applies independently while Toyota replacement is stopped')
toyota.state='running';fire('onClientResourceStart',root);update()
assert(wheel[404].front_axle==0.82 and wheel[404].rear_axle==0.84,'both physical axle sizes match the model the DFF was authored for')
assert(wheel[579].front_axle==0.82 and wheel[579].rear_axle==0.84,'reference remains untouched')
fire('onClientResourceStart',root);update();assert(#calls==4,'unchanged values must not repeatedly restream cars')
fire('onClientResourceStart',root);local old=timer;fire('onClientResourceStart',root);assert(old.dead,'resource-start bursts coalesce');update()
toyota.state='stopped';fire('onClientResourceStop',root);update()
assert(wheel[404].front_axle==0.7 and wheel[404].rear_axle==0.7,'stopping custom Toyota restores stock 404 wheels')
wheel[579].front_axle=0.99;toyota.state='running';fire('onClientResourceStart',root);update()
assert(wheel[404].front_axle==0.82 and wheel[579].front_axle==0.99,'later changes to another Huntley replacement are not copied to Toyota')
local getter,setter=getVehicleModelWheelSize,setVehicleModelWheelSize
getVehicleModelWheelSize=nil;setVehicleModelWheelSize=nil
fire('onClientResourceStart',root);update();fire('onClientResourceStart',root);update()
assert(warnings==1,'unsupported client receives one clear message instead of a Lua error')
getVehicleModelWheelSize,setVehicleModelWheelSize=getter,setter
fire('onClientResourceStart',root);fire('onClientResourceStop',resourceRoot)
assert(timer.dead and wheel[404].front_axle==0.7 and wheel[404].rear_axle==0.7 and wheel[479].front_axle==0.65 and wheel[479].rear_axle==0.66,'resource stop restores sizes and cancels scheduled changes')
print('Wheel compatibility: independent axles, delayed model load, no repeated restream, donor isolation, stop/restart and API guard passed')
