root,resourceRoot={},{}
local handlers,timers,events={},{},{}
local p={x=246.4,y=87.5,z=1003.6,interior=6,dimension=20002,frozen=false}
Fraction={notify=function() end}
function addEvent() end
function addEventHandler(name,element,fn) handlers[name]=fn end
function isElement(e) return type(e)=='table' end
function isPedDead() return false end
function isPedInVehicle() return false end
function isElementFrozen(e) return e.frozen end
function setElementFrozen(e,v) e.frozen=v end
function getElementPosition(e) return e.x,e.y,e.z end
function setElementPosition(e,x,y,z) e.x,e.y,e.z=x,y,z end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function setElementInterior(e,n) e.interior=n end
function setElementDimension(e,n) e.dimension=n end
function setElementVelocity() end
function setPedRotation() end
function setCameraTarget() end
function setElementData(e,key,value) e[key]=value end
function fadeCamera(e,visible) e.visible=visible end
function setTimer(fn,ms) local t={fn=fn,ms=ms,live=true};timers[#timers+1]=t;return t end
function isTimer(t) return t and t.live end
function killTimer(t) t.live=false end
function triggerClientEvent(player,event,element,token,pos) events[event]={token=token,pos=pos} end
dofile('resources/rp_fraction/server/portal.lua')
local arrival={x=1568.7,y=-1688.2,z=5.9};local fallback={x=246.4,y=86,z=1003.6}
Fraction.safeGarageTeleport(p,arrival,0,0,fallback)
assert(p.frozen and p.visible==false and p.interior==6,'freeze and fade precede teleport')
timers[#timers].fn();local token=events['fraction:portalPrepare'].token
assert(p.x==arrival.x and p.interior==0 and p.frozen,'destination remains frozen until collision ready')
source=resourceRoot;client=p;handlers['fraction:portalReady'](token+1)
assert(p.frozen,'forged/stale readiness token cannot unfreeze player')
handlers['fraction:portalReady'](token)
assert(not p.frozen and p.visible and not p['rp:transitionPending'],'floor-ready confirmation restores movement and opens screen')
p.x,p.y,p.z=246.4,87.5,1003.6;p.interior,p.dimension=6,20002
Fraction.safeGarageTeleport(p,arrival,0,0,fallback);timers[#timers].fn();timers[#timers].fn()
assert(p.x==fallback.x and p.z==fallback.z and p.interior==6 and p.dimension==20002 and not p.frozen and p.visible,'timeout restores safe interior rather than dropping through unloaded floor')
localPlayer={};local waiting,hit,sent=false,false,0
function isElementWaitingForGroundToLoad() return waiting end
function processLineOfSight(x,y,z,a,b,c) assert(c==arrival.z-2.5 and z==arrival.z+0.3,'ray checks garage floor, not street above');return hit end
function triggerServerEvent() sent=sent+1 end
dofile('resources/rp_fraction/client/portal.lua')
handlers['fraction:portalPrepare'](42,arrival);local poll=timers[#timers]
poll.fn();assert(sent==0,'missing floor does not acknowledge spawn')
waiting=true;hit=true;poll.fn();assert(sent==0,'world streaming must finish first')
waiting=false;poll.fn();assert(sent==1 and not poll.live,'loaded garage floor acknowledges once and removes timer')
print('Portal: fade/freeze ordering, streaming floor, private token, timeout recovery and timer cleanup passed')

p.x,p.y,p.z=1479.2773,1509.4697,1183.5667;p.interior,p.dimension=1,20001
local out={x=1174,y=-1323.3,z=14.4,interior=0,dimension=0}
Fraction.safeTeleport(p,{x=p.x,y=p.y,z=p.z},1,20001,out)
timers[#timers].fn();timers[#timers].fn()
assert(p.interior==0 and p.dimension==0 and p.x==out.x and p.z==out.z,'hospital collision timeout returns outside in exterior world, not street coordinates inside virtual interior')
