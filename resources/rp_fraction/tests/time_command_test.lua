-- Exercise the existing /time entry point, not a parallel command.
local file=assert(io.open('resources/rp_core/systems/hud/server.lua','rb'));local code=file:read('*a');file:close()
local helper=assert(code:match('(function togglePlayerTime.-)\naddCommandHandler'))
local p={};resourceRoot={};local clientEvents,serverEvents={},{}
function isElement(e) return e==p end
function getElementType() return 'player' end
function getRealTime() return {timestamp=12345} end
function triggerClientEvent(target,event,element,stamp) clientEvents[#clientEvents+1]={target,stamp} end
function triggerEvent(name,target) serverEvents[#serverEvents+1]={name,target} end
assert(loadstring('local EVENT_TIME_TOGGLE="rp:time:toggle"\n'..helper))()
assert(togglePlayerTime(p))
assert(clientEvents[1][1]==p and clientEvents[1][2]==12345,'time HUD remains available')
assert(serverEvents[1][1]=='rp:timeRequested' and serverEvents[1][2]==p,'time notifies jail handler using actual player source')
assert(not togglePlayerTime(false) and #serverEvents==1,'invalid command source rejected')
print('Time command: existing HUD preserved and server jail bridge dispatched')
