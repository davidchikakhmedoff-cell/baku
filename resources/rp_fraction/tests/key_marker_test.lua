dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot,localPlayer={},{},{}
local handlers,draws,now={}, {},0
local f=Fractions[2]
function svgCreate() return {} end
function addEventHandler(name,element,fn) handlers[name]=fn end
function getElementPosition() return f.keysPoint.x,f.keysPoint.y,f.keysPoint.z end
function getElementInterior() return f.interior end
function getElementDimension() return f.dimension end
function getTickCount() return now end
function tocolor() return 1 end
function dxDrawMaterialLine3D(...) draws[#draws+1]={...} end
function isElement() return true end
local cleaned=false
function destroyElement() cleaned=true end
dofile('resources/rp_fraction/client/key_marker.lua')
handlers.onClientRender();assert(#draws==1,'only current faction dimension renders nearby key icon')
local first=draws[1];now=1000;handlers.onClientRender()
assert(first[1]==f.keysPoint.x and first[7] and first[8]==0.8,'key icon uses configured marker position and 3D material')
assert(first[11]~=draws[2][11] or first[12]~=draws[2][12],'3D key icon rotates over time')
handlers.onClientResourceStop();assert(cleaned,'key material cleaned on stop')
print('Key marker: configured position/dimension, 3D rotation and cleanup passed')
