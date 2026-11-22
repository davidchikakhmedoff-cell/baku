dofile('resources/rp_fraction/skins/config.lua');dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local p={id=7,kind='player',['auth:loggedIn']=true}
local leader={id=8,kind='player',['auth:loggedIn']=true}
local records,accounts,menus,events={}, {},{},{}
local clock=10000
local function copy(row) local result={};for k,v in pairs(row or {}) do result[k]=v end;return result end
function isElement(e) return type(e)=='table' and e.kind~=nil end
function getElementType(e) return e.kind end
function getElementData(e,k) return e[k] end
function setElementData(e,k,v) e[k]=v end
function getElementModel(e) return e.model end
function setElementModel(e,id) if e.model==id then return false end;e.model=id;return true end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementInterior(e) return e.interior end
function getElementDimension(e) return e.dimension end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function isPedInVehicle(e) return e.vehicle~=nil end
function getPedOccupiedVehicle(e) return e.vehicle end
function isPedDead(e) return e.dead or false end
function getPlayerName(e) return 'Player'..e.id end
function getElementsByType() return {p,leader} end
function getTickCount() return clock end
function getRealTime() return {timestamp=1000} end
function addEvent() end
function addEventHandler(name,_,fn) events[name]=fn end
function addCommandHandler() end
dofile('resources/rp_fraction/server/commands.lua')
function triggerClientEvent(target,event,source,kind,data)
 if event=='fraction:menu' then menus[target]={kind=kind,data=data} end
end
function takeAllWeapons(e) e.gear=false end
function getPedWeapon() return 0 end
function getPedTotalAmmo() return 0 end
function toJSON() return '[]' end
function fromJSON() return {} end
function getResourceFromName() return {} end
exports={rp_core={getAuthPlayerId=function(_,e) return e.id end,sendCoreNotification=function(_,e,text) e.notice=text end}}
FractionDB={available=function() return true end,
 one=function(sql,id)
  if sql:find('SELECT gender',1,true) then return accounts[id] end
  if sql:find('SELECT * FROM fraction_members',1,true) then return records[id] and copy(records[id]) end
  if sql:find('COUNT(*)',1,true) then return {n=0} end
 end,
 query=function() return {} end,
 exec=function(sql,a,b)
  assert(not sql:find('UPDATE players',1,true),'wardrobe must never overwrite civilian account model')
  if sql:find('DELETE FROM fraction_members',1,true) then records[a]=nil
  elseif sql:find('SET rank=?',1,true) then records[b].rank=a
  elseif sql:find('SET duty=0',1,true) then records[a].duty=0;records[a].gear_issued=0
  elseif sql:find('SET gear_issued=0',1,true) then records[a].gear_issued=0
  elseif sql:find('SET civilian_skin=?',1,true) then records[b].civilian_skin=a end
  return true
 end,
 change=function(sql,skin,weapons,id)
  records[id].duty=1;records[id].civilian_skin=skin;records[id].civilian_weapons=weapons;return true
 end
}
dofile('resources/rp_fraction/server/main.lua');dofile('resources/rp_fraction/skins/server.lua');dofile('resources/rp_fraction/server/members.lua')
local F,W=Fraction,Wardrobe
F.ready=true;F.justice={};F.jailed=function(e) return e.jailed or false end
F.repairInteriorPosition=function() end;F.applyJustice=function() end
F.clearCuffs=function() end;F.revokeDriver=function() end;F.returnVehicleKeys=function() end
FractionDependencies={hasExports=function() return false end}
local point=Fractions[2].dutyPoint
F.markers['duty:2']={kind='pickup',x=point.x,y=point.y,z=point.z,interior=6,dimension=Fractions[2].dimension}
local function setup(gender,rank)
 F.members={};F.sessions={};F.cooldowns={};F.cuffs={};F.stopping=false;menus={}
 records[7]={account_id=7,faction_id=2,rank=rank,civilian_skin=9,duty=0,gear_issued=0,salary_ms=123,salary_cycle=0,civilian_weapons='[]',armory_at=0}
 records[8]={account_id=8,faction_id=2,rank=10,civilian_skin=7,duty=0,gear_issued=0,salary_ms=0,salary_cycle=0,civilian_weapons='[]',armory_at=0}
 accounts[7]={gender=gender};accounts[8]={gender='male'}
 for _,e in ipairs({p,leader}) do e.x,e.y,e.z=point.x,point.y,point.z;e.interior,e.dimension=6,Fractions[2].dimension;e.model=e==p and 9 or 7;e.vehicle=nil;e.jailed=false;e.dead=false end
 F.load(p);F.load(leader);F.toggleDuty(p)
 assert(F.sessions[p].duty and p.model==9 and records[7].civilian_skin==9,'starting shift opens wardrobe without changing appearance')
 assert(menus[p].kind=='wardrobe','wardrobe opens automatically after start work')
 return menus[p].data
end
local cases={
 {'male',1,{280}},{'female',1,{129}},{'male',3,{280,281}},{'female',5,{129,130}},
 {'male',7,{280,281,285}},{'female',8,{129,130,131}},
 {'male',9,{280,281,285,283}},{'female',9,{129,130,131,150}},
 {'male',10,{280,281,285,283,61}},{'female',10,{129,130,131,150,151}}
}
for _,case in ipairs(cases) do
 local data=setup(case[1],case[2]);assert(#data.rows==#case[3])
 for i,id in ipairs(case[3]) do assert(data.rows[i].model==id,'cumulative unique model list by gender/rank') end
end
local data=setup('male',3)
W.close(p,data.token);assert(F.sessions[p].duty and p.model==9,'close without choice keeps shift and civilian appearance')
W.open(p);data=menus[p].data
W.wear(p,{token=data.token-1,model=281});assert(p.model==9,'stale/forged token rejected')
for _,id in ipairs({285,130,151,299,-1,1.5}) do W.wear(p,{token=data.token,model=id});assert(p.model==9,'restricted/other-gender/unlisted model rejected') end
-- Apply through the real remote-event dispatcher, including immediate click.
source,client=resourceRoot,p;events['fraction:action']('wardrobeWear',{token=data.token,model=281})
assert(p.model==281 and F.sessions[p].uniformSkin==281 and getCivilianSkin(p)==9,'selected uniform separate from saved civilian model')
W.open(p);data=menus[p].data;assert(data.current==281,'reopen selects current outfit')
W.wear(p,{token=data.token,model=280});assert(p.model==280 and records[7].civilian_skin==9,'free repeated changes never resnapshot uniform as civilian')
-- Server rechecks proximity and ignores client attempts to grant remote access.
W.open(p);data=menus[p].data;p.x=p.x+20
W.wear(p,{token=data.token,model=281,remote=true});assert(p.model==280,'out-of-range event cannot grant itself remote permission')
p.x=point.x;F.endDuty(p);W.wear(p,{token=data.token,model=281});assert(p.model==9 and not F.sessions[p].duty,'off-duty cannot reuse token')
data=setup('male',7);W.wear(p,{token=data.token,model=285})
-- Actual rank-management path must preserve shift and salary progress.
F.members[7].gear_issued=1;records[7].gear_issued=1;p.gear=true
F.rank(leader,7,3)
assert(F.sessions[p].duty and F.member(p).rank==3 and F.member(p).salary_ms==123,'demotion preserves shift and salary progress')
assert(p.model==280 and not p.gear,'invalid high-rank form replaced with minimum and old service gear removed')
data=menus[p].data;assert(menus[p].kind=='wardrobe' and #data.rows==2,'demotion offers only currently allowed forms')
W.close(p,data.token);assert(p.model==280,'closing demotion offer keeps safe minimum uniform')
W.open(p);data=menus[p].data;W.wear(p,{token=data.token,model=281})
F.rank(leader,7,7);assert(p.model==281 and #menus[p].data.rows==3,'promotion unlocks new form without replacing valid selection')
-- Old close packets cannot cancel the newly offered wardrobe.
local newToken=menus[p].data.token;W.close(p,data.token);assert(F.sessions[p].wardrobe.token==newToken,'old close does not cancel a new session')
F.sync(p);assert(p.model==281 and getCivilianSkin(p)==9,'respawn/state sync restores selected form without account pollution')
F.dismiss(leader,7);assert(p.model==9 and not records[7] and not F.sessions[p].duty,'dismissal restores civilian form and removes wardrobe access')
W.wear(p,{token=newToken,model=285});assert(p.model==9,'dismissed player cannot reuse wardrobe event')
data=setup('female',10);W.wear(p,{token=data.token,model=151});F.disconnect(p)
assert(p.model==9 and records[7].duty==0,'disconnect ends shift and restores civilian skin')
F.load(p);assert(p.model==9 and not F.sessions[p].duty,'reconnect loads ordinary appearance')
data=setup('female',8);W.wear(p,{token=data.token,model=131});events.onResourceStop()
assert(p.model==9 and records[7].duty==0,'resource stop restores ordinary appearance')
-- Adding entries is configuration-only and duplicate models remain unique.
local groups=SkinConfig.factions[2].groups
groups[#groups+1]={minRank=4,male={{model=284,name='Дополнительная форма'},{model=280,name='Дубликат'}}}
local entries=SkinConfig.list(2,'male',4);assert(#entries==3 and entries[3].model==284 and entries[1].minRank==1,'config-only extension and duplicate elimination')
groups[#groups]=nil
print('Wardrobe: ten gender/rank cases, lifecycle, real event/rank paths, tokens, authorization, civilian preservation and configuration passed')
