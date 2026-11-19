dofile('resources/rp_fraction/cars/config.lua')
root,resourceRoot={},{}
local p={logged=true,seat=0};local v={model=596};p.vehicle=v;v.driver=p
local handlers,now={},0
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function isElement(e) return type(e)=='table' end
function getElementType(e) return e.model and 'vehicle' or 'player' end
function getElementModel(e) return e.model end
function getPedOccupiedVehicle(e) return e.vehicle end
function isPedInVehicle(e) return e.vehicle~=nil end
function getPedOccupiedVehicleSeat(e) return e.seat end
function getVehicleOccupant(e) return e.driver end
function getVehicleSirensOn(e) return e.siren or false end
function setVehicleSirensOn(e,state) e.siren=state end
function setElementData(e,key,value) e[key]=value end
function getElementData(e,key) return e[key] end
function removeElementData(e,key) e[key]=nil end
function isPedDead(e) return e.dead or false end
function isVehicleBlown(e) return e.blown or false end
function getTickCount() return now end
function getElementsByType() return {v} end
Fraction={cuffs={},account=function(e) return e and e.logged end,jailed=function(e) return e.jailed end}
dofile('resources/rp_fraction/cars/server.lua')
handlers.onResourceStart();assert(v['fraction:sirenMode']==0 and not v.siren)
local function cycle() client=p;source=resourceRoot;handlers['fraction:cycleSirens']();now=now+250 end
cycle();assert(v['fraction:sirenMode']==1 and not v.siren,'first tap: lights only')
cycle();assert(v['fraction:sirenMode']==2 and v.siren,'second tap: lights plus sound')
cycle();assert(v['fraction:sirenMode']==0 and not v.siren,'third tap: all off')
p.seat=1;cycle();assert(v['fraction:sirenMode']==0,'passenger cannot change mode');p.seat=0
p.logged=false;cycle();assert(v['fraction:sirenMode']==0,'guest rejected');p.logged=true
Fraction.cuffs[p]={};cycle();assert(v['fraction:sirenMode']==0,'cuffed driver rejected');Fraction.cuffs[p]=nil
p.jailed=true;cycle();assert(v['fraction:sirenMode']==0,'prisoner rejected');p.jailed=false
cycle();assert(v['fraction:sirenMode']==1)
now=now-250;cycle();assert(v['fraction:sirenMode']==1,'rapid duplicate rejected')
v['fraction:sirenMode']=2;source=v;client=p;handlers.onElementDataChange('fraction:sirenMode');assert(v['fraction:sirenMode']==1 and not v.siren,'client cannot forge mode data')
source=v;handlers.onVehicleExplode();assert(v['fraction:sirenMode']==0 and not v.siren,'explosion clears mode')
client=nil;handlers.onResourceStop();assert(v['fraction:sirenMode']==nil)

-- Exercise keyboard interception, hold threshold and cleanup independently.
localPlayer=p;p['auth:loggedIn']=true
handlers={};local timer,uiBlocked,horn,requests,cancelled=nil,false,false,0,0
function getBoundKeys(control) assert(control=='horn');return {h=true} end
function isControlEnabled() return true end
function isChatBoxInputActive() return uiBlocked end
function isCursorShowing() return false end
function addCommandHandler() end
function isConsoleActive() return false end
function isMainMenuActive() return false end
function isMTAWindowActive() return false end
function getResourceFromName() return false end
function cancelEvent() cancelled=cancelled+1 end
function setTimer(fn,ms) assert(ms==250);timer={fn=fn};return timer end
function isTimer(e) return not e.dead end
function killTimer(e) e.dead=true end
function setPedControlState(player,key,state) assert(player==localPlayer and key=='horn');horn=state end
function triggerServerEvent(name,element) assert(name=='fraction:cycleSirens' and element==resourceRoot);requests=requests+1 end
dofile('resources/rp_fraction/cars/controls.lua')
handlers.onClientKey('h',true);assert(not horn and requests==0 and cancelled==1,'tap does not start native siren immediately')
handlers.onClientKey('h',false);assert(requests==1 and not horn and timer.dead,'tap cycles on release')
v['fraction:sirenMode']=1
handlers.onClientKey('h',true);timer.fn();assert(horn and requests==1,'hold starts horn without cycling mode')
v.siren=true;handlers.onClientPreRender();assert(not v.siren,'hold restores silent mode after native horn processing')
handlers.onClientKey('h',false);assert(not horn and requests==1 and v['fraction:sirenMode']==1,'release stops horn without changing mode')
uiBlocked=true;handlers.onClientKey('h',true);assert(requests==1 and not horn,'typing H in chat does nothing');uiBlocked=false
function isControlEnabled() return false end
function getBoundKeys() return false end
getResourceFromName=function() return {} end;function getResourceState() return 'running' end
exports={rp_core={isTextInputActive=function() return true end,isAnyBlockingUIOpen=function() return true end}}
handlers.onClientKey('h',true);handlers.onClientKey('h',false);assert(requests==2,'H works with missing native binding and stale invisible core UI flags')
getResourceFromName=function() return false end
handlers.onClientKey('h',true);timer.fn();p.vehicle=nil;handlers.onClientPreRender();assert(not horn and requests==2,'leaving car cancels held horn')
p.vehicle=v;handlers.onClientKey('h',true);handlers.onClientResourceStop();assert(not horn and timer.dead,'stop cancels pending press')
v.model=599;local n=cancelled;handlers.onClientKey('h',true);assert(cancelled==n,'other models keep native horn behavior')
assert(FractionCarConfig.sirenBrightness>2 and FractionCarConfig.sirenOpacity>1,'brightness and opacity increased')
print('Siren controls: server modes, authorization, replication protection, cooldown, tap/hold, chat, native horn and cleanup passed')
