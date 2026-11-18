dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local commands={};local leader={id=1};local deputy={id=2};local worker={id=3};local newcomer={id=4}
local players={leader,deputy,worker,newcomer}
local db={[1]={account_id=1,faction_id=2,rank=10},[2]={account_id=2,faction_id=2,rank=9},[3]={account_id=3,faction_id=2,rank=1}}
Fraction={members=db,invites={},sessions={}}
local F=Fraction
F.account=function(p) return type(p)=='table' and p.id end
F.player=function(id) return players[tonumber(id)] end
F.member=function(p) return p and db[p.id] end
F.reload=function(id) return db[id] end
F.throttle=function() return true end
F.near=function() return true end
F.jailed=function() return false end
F.now=function() return 1000 end
F.name=function(p) return 'Player'..p.id end
F.notify=function() end
F.sync=function() end
F.endDuty=function() end
F.clearCuffs=function() end
F.revokeDriver=function() end
function addCommandHandler(name,fn) commands[name]=fn end
function addEvent() end
function addEventHandler() end
function getElementModel() return 0 end
function triggerClientEvent() end
function getElementsByType() return players end
function setElementModel() end
root,resourceRoot={},{}
FractionDB={query=function() return {} end}
FractionDB.change=function(sql,id,fid,skin) if db[id] then return false end;db[id]={account_id=id,faction_id=fid,rank=1};return true end
FractionDB.exec=function(sql,a,b)
 if sql:find('DELETE FROM fraction_members') then db[a]=nil
 elseif sql:find('UPDATE fraction_members SET rank') then db[b].rank=a end
 return true
end
assert(loadfile('resources/rp_fraction/server/members.lua'))()
commands.invite(leader,'invite','4');assert(F.invites[newcomer] and not db[4],'invite waits for confirmation')
F.respondInvite(newcomer,true);assert(db[4] and db[4].faction_id==2 and db[4].rank==1,'accept joins at rank 1')
commands.invite(leader,'invite','4');assert(not F.invites[newcomer],'existing member cannot be invited')
F.rank(deputy,3,5);assert(db[3].rank==1,'deputy rank change rejected')
F.rank(leader,3,10);assert(db[3].rank==1,'ordinary promotion cannot create another leader')
F.rank(leader,1,2);assert(db[1].rank==10,'leader cannot demote self')
F.rank(leader,3,4);assert(db[3].rank==4,'leader can change ordinary rank')
F.dismiss(deputy,1);assert(db[1],'deputy cannot remove leader')
F.dismiss(deputy,2);assert(db[2],'deputy cannot remove self')
F.dismiss(deputy,3);assert(not db[3],'deputy can remove ordinary worker')
F.invites[worker]={inviter=leader,faction=2,expires=999};F.respondInvite(worker,true);assert(not db[3],'expired invitation rejected')
print('Members: 11 invitation, confirmation, hierarchy and self-management checks passed')
