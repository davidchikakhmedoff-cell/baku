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
FractionDB={one=function() return {gender='male'} end,available=function() return true end,exec=function() return true end}
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

-- Mafia equipment cleanup and membership synchronization must never replace clothing.
for _,fid in ipairs({4,5,6}) do
 p.logged=true;p.model=46
 local mafia={account_id=1,faction_id=fid,rank=1,civilian_skin=7,civilian_weapons='[]',duty=0,gear_issued=1}
 F.members[1]=mafia;F.sessions[p]={account=1,duty=false}
 F.sync(p)
 assert(p.model==46 and getCivilianSkin(p)==46,'mafia sync and account save preserve current skin')
 mafia.rank=#Fractions[fid].ranks;F.sync(p)
 assert(p.model==46,'mafia promotion does not apply a rank skin')
 F.endDuty(p)
 assert(p.model==46 and mafia.gear_issued==0,'mafia equipment cleanup preserves current clothing')
 local savedSkin
 FractionDB.exec=function(sql,value)
  if sql:find('UPDATE fraction_members SET civilian_skin=',1,true) then savedSkin=value end
  return true
 end
 F.disconnect(p,true)
 assert(p.model==46 and savedSkin==46 and not F.sessions[p],'mafia resource stop preserves and saves current skin')
end
print('Mafia clothing: all three factions preserve current skin through sync, promotion, equipment cleanup and restart')

-- News retains normal clothing during a real shift transition and account save.
p.logged=true;p.model=46
F.members[1]={account_id=1,faction_id=3,rank=1,civilian_skin=7,civilian_weapons='[]',duty=0,gear_issued=0}
F.sessions[p]={account=1,duty=false};F.markers['duty:3']={}
F.near=function() return true end
F.jailed=function() return false end
F.notify=function() end
F.snapshotWeapons=function() return '[]' end
function isPedInVehicle() return false end
FractionDB.change=function() return true end
F.toggleDuty(p)
assert(F.sessions[p].duty and F.members[1].duty==1 and p.model==46,'News shift starts without assigning a uniform')
p.model=12;F.sync(p)
assert(getCivilianSkin(p)==12,'saving account while News is on shift uses current normal skin')
source=p;handlers.onPlayerSpawn()
assert(p.model==12 and F.sessions[p].duty,'News death/respawn preserves shift without changing clothing')
F.toggleDuty(p)
assert(not F.sessions[p].duty and p.model==12,'ending News shift does not restore a stale clothing snapshot')
F.sessions[p].duty=true;F.members[1].duty=1
F.disconnect(p,true)
assert(p.model==12,'News restart/disconnect retains personal clothing')
print('News clothing: actual start/end shift, respawn, save and restart preserve own skin')
