-- Full custom-chat -> exported bridge -> real command -> real founder role.
dofile('resources/rp_core/systems/admin/config.lua')
dofile('resources/rp_core/systems/chat/config.lua')
dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
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
Fraction={members=db,invites={},sessions={}}
local F=Fraction
F.account=function(p) return p and p['auth:loggedIn'] and p.id end
F.player=function(id) return byDynamic[tonumber(id)] end
F.member=function(p) return p and db[p.id] end
F.reload=function(id) return db[id] end
F.sync=function() end;F.revokeDriver=function() end
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
RPChat.processMessage(owner,'/setleader 15 0');assert(writes==0,'invalid faction ID rejected')
RPChat.processMessage(owner,'/SETLEADER 15 1')
assert(db[87].rank==6 and db[87].faction_id==1 and db[88].rank==5,'chat appoints live player by dynamic ID and demotes former leader')
local before=executed
RPChat.processMessage(owner,'/restart rp_core')
assert(executed==before and notifications[#notifications].text=='Неизвестная команда.','bridge cannot execute arbitrary server commands')
sourceResource={};assert(not executeFractionCommand(owner,'setleader','15 1'),'foreign resource cannot use authenticated chat bridge')
print('Leader/chat: real custom chat routing, dynamic IDs, founder-only access, transfer, validation and bridge isolation passed')
