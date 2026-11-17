local file=assert(io.open('resources/rp_car/client.lua','rb'));local code=file:read('*a');file:close()
local selector=assert(code:match('function getLookedVehicle%(%)%s*.-\nend'))
localPlayer={};CarLockAccountId=7;CarConfig={lockAimDistance=12}
local centred={owner=7,x=9,sx=960,sy=540}
local near={owner=7,x=2,sx=1020,sy=540}
local foreign={owner=8,x=1,sx=960,sy=540}
local cars={near,centred,foreign}
function getCameraMatrix() return 0,0,1 end
function guiGetScreenSize() return 1920,1080 end
function getElementPosition(v) return v.x or 0,0,0 end
function getElementData(v,key) if key=='car:ownerAccountId' then return v.owner end end
function getElementInterior() return 0 end
function getElementDimension(v) return v.dimension or 0 end
function getElementsByType() return cars end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.abs(x-a) end
function getScreenFromWorldPosition(x) for _,v in ipairs(cars) do if v.x==x then return v.sx,v.sy end end end
function isLineOfSightClear(cx,cy,cz,x) return x~=centred.blockedX end
assert(loadstring(selector))()
assert(getLookedVehicle()==centred,'screen centre outranks physical distance')
centred.blockedX=9;assert(getLookedVehicle()==near,'occluded car ignored')
near.sx=1500;assert(not getLookedVehicle(),'outside aim area does not select a neighbour')
near.sx=960;near.dimension=1;assert(not getLookedVehicle(),'different world ignored')
CarLockAccountId=nil;assert(not getLookedVehicle(),'no session identity means no selection')
print('Lock aim: 5 screen-centre, visibility and ownership checks passed')
