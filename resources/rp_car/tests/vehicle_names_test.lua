dofile('resources/rp_car/dealerships.lua')
function getVehicleNameFromModel(model) return 'Stock '..model end
dofile('resources/rp_car/vehicles.lua')
assert(getConfiguredVehicleName(579)=='BMW X5M E70','vehicle model uses real dealership customName')
assert(getConfiguredVehicleName(421)=='Stock 421','models absent from catalog retain GTA name')
local file=assert(io.open('resources/rp_fraction/server/vehicle_keys.lua','rb'));local code=file:read('*a');file:close()
local helper=assert(code:match('(local function vehicleName.-\nend)'))
FractionCarConfig={models={[596]={name='Ford Explorer'}}}
exports={rp_car={getConfiguredVehicleName=function(_,model) return getConfiguredVehicleName(model) end}}
local name=assert(loadstring(helper..'\nreturn vehicleName'))()
assert(name({model=579})=='BMW X5M E70','mafia key menu reads the actual dealership name')
Dealerships[1].vehicles[#Dealerships[1].vehicles+1]={model=421,customName='Catalog 421'}
assert(name({model=421})=='Catalog 421','catalog additions automatically appear in key menu without duplicate mapping')
Dealerships[1].vehicles[#Dealerships[1].vehicles].customName='Renamed catalog 421'
assert(name({model=421})=='Renamed catalog 421','renames propagate to key/menu notifications')
assert(name({model=596})=='Ford Explorer','PD explicit replacement names remain intact')
assert(getVehicleDisplayName(579,'Personal name')=='Personal name','stored personal names preserved')
print('Vehicle names: real dealership lookup, automatic additions/renames, faction key menu, fallbacks and PD/personal names passed')
