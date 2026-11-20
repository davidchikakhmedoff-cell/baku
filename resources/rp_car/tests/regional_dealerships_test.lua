dofile('resources/rp_car/dealerships.lua')
dofile('resources/rp_car/tuning_shops.lua')
local expected={europe={560,579,529,547,411,405,436,477,400,413,602,480,451,458,445},america={550,546,479},russia={},asia={421,404}}
local seen={}
for _,dealer in ipairs(Dealerships) do
    local models=assert(expected[dealer.region])
    assert(#models==#dealer.vehicles)
    assert(dealer.blipIcon==55 and dealer.blipVisibleDistance==250)
    for index,vehicle in ipairs(dealer.vehicles) do
        assert(vehicle.model==models[index] and vehicle.id==index)
        assert(not seen[vehicle.model], 'duplicate showroom model')
        seen[vehicle.model]=dealer.region
        assert(vehicle.price>0 and vehicle.price==math.floor(vehicle.price))
        assert(vehicle.customName and not vehicle.customName:find('_'))
        assert(getDealershipVehicle(dealer.id,vehicle.id)==vehicle)
        assert(vehicle.position.interior==0 and vehicle.position.dimension==0)
    end
end
assert(#Dealerships==4 and not seen[409])
assert(getDealershipById(2).playerSpawn.x==2126.56 and getDealershipById(2).playerSpawn.y==1398.25)
for id=3,4 do
    local p=getDealershipById(id).playerSpawn
    assert(p.x < -1600 and p.y>250 and p.y<1300, 'San Fierro showroom')
end
for id,model in ipairs({560,579,529,547,411}) do assert(getDealershipVehicle(1,id).model==model) end
assert(#TuningShops==3 and not getTuningShopById(99))
for id=1,3 do assert(getTuningShopById(id)) end

local file=assert(io.open('resources/rp_car/server.lua','rb'));local source=file:read('*a');file:close()
local spawn=assert(source:match('(local function spawnShowcases%(%).-\nend)'))
local elements,handlers={},{}
local function element(kind) local e={kind=kind};elements[#elements+1]=e;return e end
function isElement(e) return type(e)=='table' and not e.destroyed end
function destroyElement(e) e.destroyed=true end
function createVehicle(model,x,y,z) local e=element('vehicle');e.model=model;e.x=x;e.y=y;e.z=z;return e end
function createMarker(x,y,z) local e=element('marker');e.x=x;e.y=y;e.z=z;return e end
function setElementInterior(e,v) e.interior=v end
function setElementDimension(e,v) e.dimension=v end
function addEventHandler(_,e,fn) handlers[e]=fn end
function setElementData(e,key,value) e[key]=value end
for _,fn in ipairs({'setVehicleColor','applyConfiguredHandling','setVehicleDamageProof','setElementFrozen','setVehicleEngineState','setVehicleOverrideLights','setVehicleLocked','setElementHealth'}) do _G[fn]=function() end end
function isLogged(p) return p.logged end
function isPedInVehicle(p) return p.inVehicle end
local notices=0
function notify() notices=notices+1 end
local run=assert(loadstring('local showcaseByElement,emptyDealershipMarkers={},{}\n'..spawn..'\nreturn spawnShowcases'))()
for repetition=1,2 do
    run()
    local count,emptyMarker=0,nil
    for _,e in ipairs(elements) do if isElement(e) then
        if e.kind=='vehicle' then count=count+1;assert(e['car:showcase']) else emptyMarker=e end
    end end
    assert(count==20 and emptyMarker, 'showrooms replace previous elements without duplication')
    assert(emptyMarker.x==getDealershipById(3).playerSpawn.x)
    handlers[emptyMarker]({logged=true},false)
    handlers[emptyMarker]({logged=false},true)
    handlers[emptyMarker]({logged=true,inVehicle=true},true)
    assert(notices==repetition-1)
    handlers[emptyMarker]({logged=true},true)
    assert(notices==repetition)
end
print('Regional dealerships: grouping, prices, stable IDs, no limousine, tuning removal, showroom creation/cleanup and empty dealer feedback passed')
