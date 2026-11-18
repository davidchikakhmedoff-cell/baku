-- Full custom-chat -> exported bridge -> real command -> real founder role.
dofile('resources/rp_core/systems/admin/config.lua')
dofile('resources/rp_core/systems/chat/config.lua')
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
root,resourceRoot={},{}
local coreResource,fractionResource={},{}
local owner={id=901,['auth:loggedIn']=true,['auth:rpName']='Founder_Test'}
local staff={id=902,['auth:loggedIn']=true,['auth:rpName']='Staff_Test'}
local target={id=87,['auth:loggedIn']=true,['auth:rpName']='Target_Test'}
local former={id=88,['auth:loggedIn']=true,['auth:rpName']='Former_Test'}
local other={id=89,['auth:loggedIn']=true,['auth:rpName']='Other_Test'}
local players={owner,staff,target,former,other}
local byDynamic={[1]=owner,[2]=staff,[15]=target,[16]=former,[17]=other}
local commands,notifications={},{}
function addEvent() end
function addEventHandler() end
function addCommandHandler(name,fn) commands[name]=fn end
function isElement(p) return type(p)=='table' and p.id~=nil end
function getElementType() return 'player' end
function getElementData(p,key) return p[key] end
function getPlayerName(p) return p['auth:rpName'] end
function getElementsByType() return players end
function getResourceFromName(name) return name=='rp_core' and coreResource or name=='rp_fraction' and fractionResource end
function getResourceState() return 'running' end
function getResourceExportedFunctions() return {'executeFractionCommand'} end
function getElementModel() return 7 end
function triggerClientEvent() end
dofile('resources/rp_core/systems/admin/server.lua')
AdminCore.configLoaded=true;AdminCore.admins={Founder_Test=10,Staff_Test=5}
assert(isCoreFounder(owner) and not isCoreFounder(staff),'existing core owner role is authoritative')
local db={[88]={account_id=88,faction_id=1,rank=6},[89]={account_id=89,faction_id=2,rank=1}}
local writes=0
Fraction={members={[88]=db[88],[89]=db[89]},invites={},sessions={}}
local F=Fraction
F.account=function(p) return p and p['auth:loggedIn'] and p.id end
F.player=function(id) return byDynamic[tonumber(id)] end
F.member=function(p) return p and F.members[p.id] end
F.reload=function(id) F.members[id]=db[id];return db[id] end
F.sync=function(p) p.faction=db[p.id] and db[p.id].faction_id or false end
F.revokeDriver=function(p) p.driverRevoked=not F.member(p) end
F.endDuty=function(p) p.working=false;p.serviceGear=false end
function setElementModel(p,model) p.model=model end
F.name=getPlayerName
F.notify=function(p,text) notifications[#notifications+1]={player=p,text=text} end
FractionDB={query=function() return {} end}
FractionDB.one=function(sql,a,b)
 if sql:find('SELECT account_id',1,true) then for _,m in pairs(db) do if m.faction_id==a and m.rank==b then return {account_id=m.account_id} end end
 elseif sql:find('SELECT skin',1,true) then return {skin=7} end
end
FractionDB.exec=function(sql,a,b,c)
 writes=writes+1
 if sql:find('INSERT OR IGNORE',1,true) then db[a]=db[a] or {account_id=a,faction_id=b,rank=1,civilian_skin=c}
 elseif sql:find('UPDATE fraction_members SET rank',1,true) then db[b].rank=a
 else error(sql) end
 return true
end
FractionDB.change=function(sql,id,fid,rank)
 assert(sql=='DELETE FROM fraction_members WHERE account_id=? AND faction_id=? AND rank=?')
 local row=db[id]
 if not row or row.faction_id~=fid or row.rank~=rank then return false end
 writes=writes+1;db[id]=nil;return true
end
exports={rp_core={isCoreFounder=function(self,p) return isCoreFounder(p) end}}
dofile('resources/rp_fraction/server/members.lua')
assert(commands.setleader and not commands.setfractionleader,'new command registered and old account-ID command removed')
local executed=0
function executeCommandHandler(command,p,args)
 executed=executed+1;local tokens={};for arg in args:gmatch('%S+') do tokens[#tokens+1]=arg end
 assert(commands[command],'routed command must have a real handler');commands[command](p,command,unpack(tokens));return true
end
function call(resource,method,...)
 assert(resource==fractionResource and method=='executeFractionCommand')
 local old=sourceResource;sourceResource=coreResource;local handled=executeFractionCommand(...);sourceResource=old;return handled
end
dofile('resources/rp_core/systems/chat/server.lua')
RPChat.sendSystem=function(p,text) notifications[#notifications+1]={player=p,text=text} end
for _,level in ipairs({0,1,3,5,9}) do
 AdminCore.admins.Staff_Test=level
 RPChat.processMessage(staff,'/setleader 15 1')
 assert(writes==0 and notifications[#notifications].text:find('основателю',1,true),'all lower admin levels denied without unknown-command error')
end
RPChat.processMessage(owner,'/setleader 87 1');assert(writes==0,'permanent account ID cannot be mistaken for dynamic ID')
RPChat.processMessage(owner,'/setleader 17 1');assert(writes==0 and db[89].faction_id==2,'member of another faction rejected')
RPChat.processMessage(owner,'/setleader 15 -1');assert(writes==0,'negative faction ID rejected')
RPChat.processMessage(owner,'/setleader 15 7');assert(writes==0,'out-of-range faction ID rejected')
RPChat.processMessage(owner,'/setleader 15 0');assert(writes==0,'non-member cannot be removed as leader')
RPChat.processMessage(owner,'/SETLEADER 15 1')
assert(db[87].rank==6 and db[87].faction_id==1 and db[88].rank==5,'chat appoints live player by dynamic ID and demotes former leader')
local beforeRemoval=writes
RPChat.processMessage(owner,'/setleader 16 0')
assert(writes==beforeRemoval and db[88].rank==5,'zero does not dismiss a deputy')
for _,level in ipairs({0,1,3,5,9}) do
 AdminCore.admins.Staff_Test=level
 RPChat.processMessage(staff,'/setleader 15 0')
 assert(writes==beforeRemoval and db[87].rank==6,'lower admins cannot remove a leader with zero')
end
target.working=true;target.serviceGear=true
RPChat.processMessage(owner,'/setleader 15 0')
assert(not db[87] and not F.members[87],'leader membership deleted from persistent storage and cache')
assert(not target.working and not target.serviceGear and not target.faction and target.driverRevoked,'removal ends duty/kit, clears faction state and revokes driver access')
local afterRemoval=writes
RPChat.processMessage(owner,'/setleader 15 0');assert(writes==afterRemoval,'repeating removal is harmless')
RPChat.processMessage(owner,'/setleader 15 1');assert(db[87].rank==6,'removed leader can be appointed again')
db[89]={account_id=89,faction_id=4,rank=10,civilian_skin=12};F.reload(89);other.model=113
RPChat.processMessage(owner,'/setleader 17 0')
assert(not db[89] and not F.members[89] and other.model==12 and other.driverRevoked,'criminal leader removal restores civilian skin and revokes access')
db[901]={account_id=901,faction_id=2,rank=10,civilian_skin=7};F.reload(901)
RPChat.processMessage(owner,'/setleader 1 0')
assert(not db[901] and isCoreFounder(owner),'founder may remove own leadership through the administrative command')
local before=executed
RPChat.processMessage(owner,'/restart rp_core')
assert(executed==before and notifications[#notifications].text=='Неизвестная команда.','bridge cannot execute arbitrary server commands')
sourceResource={};assert(not executeFractionCommand(owner,'setleader','15 1'),'foreign resource cannot use authenticated chat bridge')
print('Leader/chat: routing, founder-only appointment/removal, persistent deletion, duty/gear, civilian skin, access, validation and bridge isolation passed')
