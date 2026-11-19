root={}
local handlers,cancelled,repairs={},false,0
function addEventHandler(name,_,fn) handlers[name]=fn end
function getElementType() return 'vehicle' end
function getElementData(e,key) return e[key] end
function cancelEvent() cancelled=true end
function fixVehicle() repairs=repairs+1 end
dofile('resources/rp_fraction/client/parked_vehicles.lua')
local parked={['fraction:vehicle']=2,['fraction:issued']=false}
source=parked;handlers.onClientVehicleDamage()
assert(cancelled and repairs==1,'unissued parked vehicle has no visual damage')
cancelled=false;parked['fraction:issued']=true;handlers.onClientVehicleDamage()
assert(not cancelled and repairs==1,'issued vehicle has ordinary damage')
source={};handlers.onClientVehicleDamage();assert(not cancelled and repairs==1,'personal vehicles unaffected')
source=parked;parked['fraction:issued']=false;handlers.onClientElementStreamIn()
assert(repairs==2,'streamed parked fleet vehicle has pristine bodywork')
print('Fleet protection: visual damage cancellation, issued vehicles and stream-in repair passed')
