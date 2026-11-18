dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root={}
local events,cancelled={},false
function addEventHandler(name,_,fn) events[name]=fn end
function isElement(e) return type(e)=='table' end
function getElementType(e) return e.type or 'player' end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function cancelEvent() cancelled=true end
dofile('resources/rp_fraction/client/jail_safezone.lua')
local prisoner={interior=6,dimension=FractionConfig.dimensionBase+100}
local outside={interior=0,dimension=0}
source=prisoner;events.onClientPlayerDamage(outside);assert(cancelled,'prisoner immune to incoming damage')
cancelled=false;source=prisoner;events.onClientPlayerDamage(nil);assert(cancelled,'environmental damage cancelled in prison')
cancelled=false;source=outside;events.onClientPlayerDamage(prisoner);assert(cancelled,'prisoner cannot damage another player')
cancelled=false;source=outside;events.onClientPlayerDamage(outside);assert(not cancelled,'normal world damage unchanged')
source=prisoner;events.onClientPlayerStealthKill(prisoner);assert(cancelled,'stealth killing prevented in prison')
cancelled=false;prisoner.dimension=0;events.onClientPlayerDamage(prisoner);assert(not cancelled,'release restores ordinary damage rules')
print('Prison green zone: incoming/outgoing/environmental damage, stealth kill and release passed')
