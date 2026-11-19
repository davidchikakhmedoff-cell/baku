dofile('resources/rp_car/dealerships.lua')
function getVehicleNameFromModel(model) return 'Stock '..model end
dofile('resources/rp_car/vehicles.lua')
assert(getConfiguredVehicleName(579)=='BMW X5M E70','vehicle model uses real dealership customName')
assert(getConfiguredVehicleName(421)=='LEXUX LS 400 XF10' and getConfiguredVehicleName(404)=='TOYOTA SEQUOIA','explicit model names use exact user spelling')
assert(getVehicleDisplayName(421,'Washington')=='LEXUX LS 400 XF10' and getVehicleDisplayName(404,'Perennial')=='TOYOTA SEQUOIA','old stored/default names cannot override canonical labels')
assert(getConfiguredVehicleName(409)=='Stock 409','models without configured names retain GTA name')
local file=assert(io.open('resources/rp_fraction/server/vehicle_keys.lua','rb'));local code=file:read('*a');file:close()
local helper=assert(code:match('(local function vehicleName.-\nend)'))
FractionCarConfig={models={[596]={name='Ford Explorer'}}}
exports={rp_car={getConfiguredVehicleName=function(_,model) return getConfiguredVehicleName(model) end}}
local name=assert(loadstring(helper..'\nreturn vehicleName'))()
assert(name({model=579})=='BMW X5M E70','mafia key menu reads the actual dealership name')
Dealerships[1].vehicles[#Dealerships[1].vehicles+1]={model=400,customName='Catalog 400'}
assert(name({model=400})=='Catalog 400','catalog additions automatically appear in key menu without duplicate mapping')
Dealerships[1].vehicles[#Dealerships[1].vehicles].customName='Renamed catalog 400'
assert(name({model=400})=='Renamed catalog 400','renames propagate to key/menu notifications')
assert(name({model=421})=='LEXUX LS 400 XF10' and name({model=404})=='TOYOTA SEQUOIA','mafia menu uses canonical vehicle labels')
assert(name({model=596})=='Ford Explorer','PD explicit replacement names remain intact')
assert(getVehicleDisplayName(579,'Personal name')=='Personal name','stored personal names preserved')
print('Vehicle names: real dealership lookup, automatic additions/renames, faction key menu, fallbacks and PD/personal names passed')
