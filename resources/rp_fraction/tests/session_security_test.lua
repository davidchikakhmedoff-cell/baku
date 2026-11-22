-- Exercise the existing auth resource's protection used by all faction checks.
local handlers={}
root,resourceRoot={},{}
function addEvent() end
function addCommandHandler() end
function addEventHandler(name,element,fn)
 handlers[name]=handlers[name] or {};table.insert(handlers[name],fn)
end
function setElementData(p,key,value) p[key]=value end
function removeElementData(p,key) p[key]=nil end
function getElementData(p,key) return p[key] end
assert(loadfile('resources/rp_core/systems/auth/server.lua'))()
local player={['auth:playerId']=10,['auth:loggedIn']=true,['auth:houseId']=5}
local attacker={}
source,client=player,attacker
local function change(key,oldValue,newValue)
 player[key]=newValue
 for _,fn in ipairs(handlers.onElementDataChange) do fn(key,oldValue) end
end
change('auth:playerId',10,1)
assert(getAuthPlayerId(player)==10,'client cannot impersonate another account or faction leader')
change('auth:loggedIn',true,false)
assert(player['auth:loggedIn']==true,'client cannot overwrite the auth session')
change('auth:houseId',5,999)
assert(player['auth:houseId']==5,'client cannot claim another house')
change('auth:rpName',nil,'Other_Player')
assert(player['auth:rpName']==nil,'missing protected fields cannot be injected')
client=nil;change('auth:houseId',5,7)
assert(player['auth:houseId']==7,'legitimate server updates remain supported')
client=attacker;change('ordinary:key',nil,123)
assert(player['ordinary:key']==123,'unrelated element data remains supported')
print('Auth security: client identity/session forgery rejected; server updates preserved')

-- Public authentication state is needed by independently downloaded client resources.
local file=assert(io.open('resources/rp_core/systems/auth/server.lua'));local code=file:read('*a');file:close()
local setter=assert(code:match('(local function setSessionData.-\nend)'))
local replicated={}
function setElementData(p,key,value,sync) p[key]=value;replicated[key]=sync end
local login=assert(loadstring(setter..'\nreturn setSessionData'))()
login(player,{id=10,rp_name='Test_Player',house_id=5})
assert(replicated['auth:loggedIn']==true,'login status reaches real remote clients')
assert(replicated['auth:playerId']==false,'private account identity stays server-side')
client=attacker;change('auth:loggedIn',true,false)
assert(player['auth:loggedIn']==true and replicated['auth:loggedIn']==true,'forged login edits restore the authoritative public value')
