dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
localPlayer,resourceRoot={},{}
local garage=Fractions[2].garage
local position={garage.outside.x,garage.outside.y,garage.outside.z}
local interior,dimension,enabled=0,0,true
local poll,stop
function getElementPosition() return unpack(position) end
function getElementInterior() return interior end
function getElementDimension() return dimension end
function getOcclusionsEnabled() return enabled end
function setOcclusionsEnabled(value) enabled=value end
function setTimer(fn) poll=fn;return {} end
function addEventHandler(_,_,fn) stop=fn end
function isTimer() return true end
function killTimer() end
dofile('resources/rp_fraction/client/garage_visibility.lua')
poll();assert(not enabled,'garage disables GTA occlusion')
position[3]=14;poll();assert(enabled,'street above garage restores occlusion')
position[3]=garage.outside.z;dimension=20002;poll();assert(enabled,'LSPD interior dimension unaffected')
dimension=0;poll();assert(not enabled)
stop();assert(enabled,'resource stop restores original occlusion state')
enabled=false;poll();position[1]=0;poll();assert(not enabled,'pre-existing disabled state preserved')
print('Garage visibility: underground-only occlusion override and restoration passed')
