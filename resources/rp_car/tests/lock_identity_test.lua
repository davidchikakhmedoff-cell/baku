-- Real session handler: auth:loggedIn is set before auth:playerId in rp_core.
local handlers, data, messages = {}, {}, {}
root,resourceRoot={},{}
local player={}
function addEvent() end
function addEventHandler(name,element,fn) handlers[name]=fn end
function getElementType() return 'player' end
function getElementData(p,key) return data[key] end
function triggerClientEvent(p,event,element,value)
 if event=='car:lockIdentity' then messages[#messages+1]=value end
end
assert(loadfile('resources/rp_car/speedometer_server.lua'))()
source=player
-- Reproduce actual login ordering, not the old mocks' fully initialised session.
data['auth:loggedIn']=true;handlers.onElementDataChange('auth:loggedIn')
assert(not messages[#messages],'missing account identity does not invent an owner')
data['auth:playerId']=7;handlers.onElementDataChange('auth:playerId')
assert(messages[#messages]==7,'later account ID must refresh lock selection')
data['auth:houseId']=0;handlers.onElementDataChange('auth:houseId')
assert(messages[#messages]==7,'eviction must not remove vehicle ownership identity')
client=player;handlers['car:requestSpeedometerSession']()
assert(messages[#messages]==7,'explicit recovery works without a house')
data['auth:loggedIn']=false;handlers.onElementDataChange('auth:loggedIn')
assert(messages[#messages]==false,'logout clears the lock identity')
print('Lock identity: actual login ordering, eviction, explicit refresh and logout passed')
