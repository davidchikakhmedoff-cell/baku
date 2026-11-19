dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot,localPlayer={},{},{}
local handlers,now,drawn={},0,nil
local dimension=FractionConfig.dimensionBase+100
local retry,loggedIn
loggedIn=true
function setTimer(fn) retry=fn;return {} end
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function getTickCount() return now end
function getElementData() return loggedIn end
function getElementInterior() return 6 end
function getElementDimension() return dimension end
function guiGetScreenSize() return 1920,1080 end
function tocolor() return 1 end
function dxDrawRectangle() end
function dxDrawText(value) drawn=value end
local requests=0
function triggerServerEvent(name) assert(name=='fraction:requestJailClock');requests=requests+1 end
dofile('resources/rp_fraction/client/jail_clock.lua')
handlers.onClientResourceStart();assert(requests==1,'restart requests authoritative jail time')
loggedIn=false;retry();assert(requests==1,'no retry before authentication')
loggedIn=true;handlers.onClientElementDataChange('auth:loggedIn');assert(requests==2,'login requests missed clock')
retry();assert(requests==3,'prison retries missing initial sync')
handlers['fraction:jailClock'](300);handlers.onClientRender();assert(drawn=='КПЗ   05:00','initial server time shown')
now=3400;handlers.onClientRender();assert(drawn=='КПЗ   04:57','smooth local countdown between server updates')
handlers['fraction:jailClock'](290);handlers.onClientRender();assert(drawn=='КПЗ   04:50','server time corrects local clock')
dimension=0;drawn=nil;handlers.onClientRender();assert(drawn=='КПЗ   04:50','server sentence remains visible during dimension transitions')
now=15000;dimension=FractionConfig.dimensionBase+100;retry();assert(requests==4,'stale clock is resynchronized')
loggedIn=false;drawn=nil;handlers.onClientRender();assert(not drawn,'logout hides clock');loggedIn=true
dimension=FractionConfig.dimensionBase+100;handlers['fraction:jailClock'](0);drawn=nil;handlers.onClientRender();assert(not drawn,'release hides timer')
print('Jail clock: server sync, countdown, correction, restart request and release passed')
