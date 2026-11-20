-- Reproduce the actual HUD cache going stale after native spawn initialization,
-- then run the real fraction health message and the core HUD refresh handler.
local file=assert(io.open('resources/rp_core/systems/hud/client.lua','rb'));local code=file:read('*a'):gsub('\r\n','\n');file:close()
local updates=assert(code:match('(local function applyFlatUpdate.-)local function attachRender'))
local vitals=assert(code:match('(local function updateLocalVitals.-)local function updateLocalWeapon'))
root,resourceRoot,localPlayer={},{},{}
local handlers={};local nativeHealth=100
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function getElementData(e,key) assert(e==localPlayer and key=='auth:playerId');return 87 end
function getElementHealth() return nativeHealth end
function getPedArmor() return 0 end
function setElementHealth(e,hp) assert(e==localPlayer);nativeHealth=hp end
function triggerEvent(name,element)
 local old=source;source=element;handlers[name]();source=old
end
local prefix=[[local hud={initialized=true,data={player={accountId=87},economy={},vitals={health=100,armor=0}},smooth={health=100,armor=0,money=0}}
local function refreshLocalWeaponNow() end
]]
local hud=assert(loadstring(prefix..updates..vitals..'\nreturn {state=hud,update=applyFlatUpdate,localVitals=updateLocalVitals}'))()
hud.update({health=20})
assert(hud.state.data.vitals.health==20)
hud.localVitals()
assert(hud.state.data.vitals.health==100,'reproduces stale local spawn value overwriting the HUD cache')
file=assert(io.open('resources/rp_fraction/client/main.lua','rb'));code=file:read('*a');file:close()
local sync=assert(code:match("(addEvent%('fraction:healthSync',true%).-)addEvent%('fraction:closeSelfHeal'"))
assert(loadstring(sync))()
source=resourceRoot;handlers['fraction:healthSync'](20)
assert(nativeHealth==20 and hud.state.data.vitals.health==20,'death correction immediately refreshes displayed HUD health')
handlers['fraction:healthSync'](100)
assert(hud.state.data.vitals.health==100,'self-healing refreshes displayed HUD health immediately')
hud.state.data.player.accountId=88;hud.update({health=37})
handlers['fraction:healthSync'](20)
assert(hud.state.data.vitals.health==37,'admin watching another player keeps target health instead of local health')
print('HUD health client regression: native spawn race, real cross-resource refresh, treatment and spectate isolation passed')

-- Exercise the actual server HUD, including propagation to an admin spectator.
local patient={id=87,hp=100};local viewer={id=88,hp=100};local people={patient,viewer};local messages={}
handlers={}
function isElement(e) return e==patient or e==viewer end
function getElementType() return 'player' end
function getElementData(e,key)
 if key=='auth:loggedIn' then return true end
 if key=='auth:playerId' or key=='rp:id' then return e.id end
 if key=='rp:level' then return 1 end
 return nil
end
function getElementHealth(e) return e.hp end
function getPlayerName(e) return 'Player'..e.id end
function getPlayerMoney() return 1000 end
function getPedWeapon() return 0 end
function getPedAmmoInClip() return 0 end
function getPedTotalAmmo() return 0 end
function getElementsByType() return people end
function addCommandHandler() end
function triggerClientEvent(p,event,_,payload) messages[#messages+1]={player=p,event=event,data=payload} end
dofile('resources/rp_core/systems/hud/server.lua')
source=patient;handlers.onPlayerSpawn()
assert(messages[#messages].data.health==100,'HUD initially observes native spawn HP')
patient.hp=20;updatePlayerHUD(patient)
assert(messages[#messages].player==patient and messages[#messages].data.health==20,'authoritative post-spawn push sends true HP to player')
client=viewer;source=viewer;handlers['admin:spectateHudTarget'](patient)
assert(messages[#messages].data.vitals.health==20,'admin starts watching real patient health')
messages={};patient.hp=100;updatePlayerHUD(patient)
assert(#messages==2 and messages[1].data.health==100 and messages[2].data.health==100,'treatment pushes true HP to patient and spectator')
print('HUD health server regression: post-spawn refresh and patient/spectator healing updates passed')
