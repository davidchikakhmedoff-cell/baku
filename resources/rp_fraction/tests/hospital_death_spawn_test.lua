-- Exercise the real rp_core death callback, including the existing prison priority.
local file=assert(io.open('resources/rp_core/systems/auth/server.lua'));local code=file:read('*a');file:close()
local fn=assert(code:match('(local function respawnAtHospital.-\nend)'))
local custom={x=1479.2773,y=1509.4697,z=1183.5667,rotation=0,interior=1,dimension=20001,health=20}
local jail,missing=false,false
local spawned,saved,prepared=0,0,0
local p={model=152,hp=0}
AuthConfig={hospital={x=1177.9,y=-1323.4,z=14.1,rotation=270,skin=0,interior=0,dimension=0,health=20}}
function isElement(e) return e==p end
function getPlayerId() return 1 end
function getElementModel(e) return e.model end
function factionValue(e,method)
 if method=='applyFactionJail' then return jail end
 if method=='getHospitalRespawnLocation' then return not missing and custom or nil end
 if method=='completeHospitalRespawn' then prepared=prepared+1;return true end
end
function spawnAt(e,data) spawned=spawned+1;e.position=data end
function setElementHealth(e,hp) e.hp=hp end
function setPedArmor(e,armor) e.armor=armor end
function fadeCamera() end
function setCameraTarget() end
function savePlayerState(e) saved=saved+1;assert(e.hp==20,'persisted HP must be 20') end
local respawn=assert(loadstring(fn..'\nreturn respawnAtHospital'))()
respawn(p)
assert(p.position.x==custom.x and p.position.dimension==20001 and p.hp==20 and p.armor==0 and prepared==1 and saved==1,'core death callback uses fraction hospital with low HP and collision loading')
jail=true;respawn(p);assert(spawned==1 and saved==1,'prisoners retain the existing jail respawn')
jail=false;missing=true;respawn(p)
assert(p.position.dimension==0 and p.hp==20 and prepared==1,'unavailable fraction resource uses safe street fallback at 20 HP')
print('Core death integration: custom hospital export, 20 HP persistence, jail priority and unavailable-resource fallback passed')
