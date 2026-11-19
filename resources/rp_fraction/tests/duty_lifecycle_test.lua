dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local handlers={}
local p={model=7}
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function isElement(e) return e==p end
function getElementType() return 'player' end
function getElementData(p,key) return key=='auth:loggedIn' and p.logged~=false end
function setElementData() end
function setElementModel(e,model) e.model=model end
function getElementModel(e) return e.model end
function triggerClientEvent() end
function getPlayerName() return 'Officer' end
function takeAllWeapons() end
function fromJSON() return {} end
function getElementsByType() return {p} end
function getPlayerWantedLevel() return 0 end
exports={rp_core={getAuthPlayerId=function() return 1 end}}
FractionDB={available=function() return true end,exec=function() return true end}
dofile('resources/rp_fraction/server/main.lua')
local F=Fraction
F.ready=true
F.members[1]={account_id=1,faction_id=2,rank=2,civilian_skin=7,civilian_weapons='[]',duty=1,gear_issued=1}
F.sessions[p]={account=1,duty=true}
F.justice={}
F.clearCuffs=function() end
F.revokeDriver=function() end
F.state=function() return nil end
F.applyJustice=function() end
F.justice[1]={wanted=4,jail_remaining=0}
local savedWanted
FractionDB.exec=function(sql,wanted) if sql:find('UPDATE fraction_state SET wanted=',1,true) then savedWanted=wanted end;return true end
local returned=false
F.returnVehicleKeys=function() returned=true end
source=p;handlers.onPlayerSpawn()
assert(p.model==Fractions[2].skins[2] and F.sessions[p].duty and F.members[1].duty==1,'respawn restores working skin and preserves shift')
local member=F.members[1]
p.logged=false;handlers.onPlayerQuit()
assert(savedWanted==4,'disconnect saves authoritative wanted even if native stars reset to zero')
assert(not F.sessions[p] and member.duty==0 and member.gear_issued==0 and p.model==7 and returned,'disconnect ends shift, clears equipment, returns keys and restores civilian skin')
print('Duty lifecycle: working respawn and disconnect cleanup passed')
