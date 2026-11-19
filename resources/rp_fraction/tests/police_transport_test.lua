dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local p={id=1}
local q={id=2};local v={model=596,occupants={}}
local key='fraction:2:1'
Fraction={cuffs={},vehicles={},playerKeys={[p]=key},vehicleByKey={[key]=v}}
local F=Fraction;local commands={};local warped=0
function isElement(e) return type(e)=='table' and not e.destroyed end
function getElementModel(e) return e.model end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function isPedDead(e) return e.dead end
function isVehicleBlown(e) return e.blown end
function isPedInVehicle(e) return e.vehicle~=nil end
function getPedOccupiedVehicle(e) return e.vehicle end
function getPedOccupiedVehicleSeat(e) return e.seat end
function getVehicleMaxPassengers() return 3 end
function getVehicleOccupant(e,seat) return e.occupants[seat] end
function getElementVelocity(e) return e.speed or 0,0,0 end
function getElementData(e,k) return e[k] end
function addCommandHandler(name,fn) commands[name]=fn end
function warpPedIntoVehicle(e,car,seat)
 if car.occupants[seat] then return false end
 warped=warped+1;e.vehicle=car;e.seat=seat;car.occupants[seat]=e;return true
end
function removePedFromVehicle(e)
 if not e.vehicle then return false end
 e.vehicle.occupants[e.seat]=nil;e.vehicle=nil;e.seat=nil;return true
end
F.account=function(e) return e and e.logged and e.id end
F.active=function(e,fid,rank) return F.account(e) and e.faction==fid and e.rank>=rank and e.duty and not e.dead and not e.jailed end
F.jailed=function(e) return e.jailed end
F.player=function(id) return tonumber(id)==2 and q or (tonumber(id)==1 and p) end
F.hasVehicleKey=function(e,k) return e==p and F.playerKeys[e]==k and not p.noKey end
F.name=function(e) return 'Player'..e.id end
F.notify=function(e,text) e.notice=text end
F.throttle=function() return true end
F.near=function(a,b,r)
 return a.interior==b.interior and a.dimension==b.dimension and (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=r*r
end
local function reset()
 for _,e in ipairs({p,q,v}) do e.x,e.y,e.z,e.interior,e.dimension=0,0,10,0,0;e.dead=false;e.vehicle=nil;e.seat=nil;e.logged=true;e.jailed=false;e.notice=nil end
 p.faction,p.rank,p.duty,p.noKey=2,2,true,false
 v.model,v.speed,v.blown,v.occupants=596,0,false,{}
 F.vehicles[v]={faction=2,key=key};F.playerKeys[p]=key
 F.cuffs={[q]={issuer=p,controls={enter_exit=true}}};q['fraction:cuffed']=true
end
dofile('resources/rp_fraction/server/police_transport.lua')
local function put() local before=warped;commands.putcar(p,'putcar','2');return warped>before end
for _,model in ipairs({596,597,598}) do
 reset();v.model=model;local cuff=F.cuffs[q]
 assert(put() and q.vehicle==v and q.seat==2 and F.cuffs[q]==cuff,'all patrol models use rear seat and preserve cuffs')
end
reset();v.occupants[2]={};assert(put() and q.seat==3,'occupied left rear uses right rear')
reset();v.occupants[2]={};v.occupants[3]={};assert(not put(),'full rear seats never substitute front passenger or driver')
for _,model in ipairs({599,427,497,523}) do reset();v.model=model;assert(not put(),'non-patrol vehicle rejected') end
for _,edit in ipairs({
 function() F.cuffs[q]=nil end,function() p.rank=1 end,function() p.duty=false end,
 function() p.faction=3 end,function() p.noKey=true end,function() F.vehicles[v].faction=1 end,
 function() p.x=3.1 end,function() q.x=3.1 end,function() q.dimension=1 end,
 function() p.interior=6 end,function() v.speed=0.1 end,function() v.blown=true end,
 function() q.dead=true end,function() q.jailed=true end,function() q.vehicle={} end,
 function() p.vehicle={} end,function() F.cuffs[p]={} end,
}) do reset();edit();assert(not put(),'unauthorized, remote or invalid seating rejected') end
reset();commands.putcar(p,'putcar','-1');assert(not q.vehicle,'malformed ID rejected')
reset();assert(put());assert(getPoliceEjectVehicle(p,q)==v,'officer on foot can use existing eject for their cuffed rear passenger')
p.x=4;assert(not getPoliceEjectVehicle(p,q),'eject rejects remote officer');p.x=0
q.seat=1;assert(not getPoliceEjectVehicle(p,q),'on-foot permission covers rear prisoners only');q.seat=2

-- Existing rp_car eject path must use the verified on-foot permission and
-- never enable enter_exit while the passenger remains cuffed.
local file=assert(io.open('resources/rp_car/server.lua','rb'));local code=file:read('*a');file:close()
local helper=assert(code:match('(local function ejectPassengerCommand.-)\naddCommandHandler%("eject"'))
local fraction={};local exited=0
function isLogged(e) return e.logged end
function resolvePlayerById(id) return F.player(id) end
function getResourceFromName() return fraction end
function getResourceState() return 'running' end
function getResourceExportedFunctions() return {'getPoliceEjectVehicle'} end
function call(_,name,actor,target) assert(name=='getPoliceEjectVehicle');return getPoliceEjectVehicle(actor,target) end
function vehicleExitPoint() return {x=2,y=0,z=10} end
function movePlayerToSafeExit(e,pos) assert(not e.vehicle);e.x,e.y,e.z=pos.x,pos.y,pos.z;exited=exited+1 end
function notify(e,text) F.notify(e,text) end
function rpName(e) return F.name(e) end
function triggerClientEvent() error('cuffed eject must not enable client exit controls') end
CarInteraction={ready=function() return true end}
CarConfig={events={forceExitVehicle='car:forceExit'}}
local eject=assert(loadstring(helper..'\nreturn ejectPassengerCommand'))()
assert(eject(p,2) and not q.vehicle and F.cuffs[q] and q['fraction:cuffed'] and exited==1,'existing eject removes cuffed passenger safely and preserves restrictions')
reset();assert(put());p.noKey=true;assert(not eject(p,2) and q.vehicle==v,'on-foot eject cannot use another officers keys')
print('Police transport: patrol-only rear seating, cuff persistence, rank/duty/key ownership, geometry, speed, full seats and existing eject passed')
