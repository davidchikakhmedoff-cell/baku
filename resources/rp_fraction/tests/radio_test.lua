dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local commands,received={},{}
local people={}
for id=1,6 do people[id]={id=id,member={faction_id=id,rank=1},logged=true,name='Player_'..id} end
people[7]={id=7,member={faction_id=2,rank=2},logged=true,name='Officer'}
people[8]={id=8,logged=true,name='Civilian'}
people[9]={id=9,member={faction_id=2,rank=1},logged=false,name='Offline'}
local now=1000
Fraction={}
local F=Fraction
F.account=function(p) return p.logged and p.id end
F.member=function(p) return p.member end
F.name=function(p) return p.name end
F.now=function() return now end
F.notify=function(p,text) p.notice=text end
F.throttle=function(p,key)
 if p.last and now-p.last<1000 then return false end
 p.last=now;return true
end
function getElementData(p,key) return p[key] end
function getElementsByType() return people end
function addCommandHandler(name,fn) commands[name]=fn end
dofile('resources/rp_fraction/server/commands.lua')
-- Use the real core delivery API: the standard MTA chat is hidden in game.
local coreResource,fractionResource={},{}
root,resourceRoot={},coreResource
function addEvent() end
function addEventHandler() end
function isElement(p) return type(p)=='table' and p.id~=nil end
function getElementType() return 'player' end
function getRealTime() return {hour=12,minute=30,timestamp=now} end
function outputChatBox() error('radio must use the visible custom chat') end
function triggerClientEvent(p,event,source,payload)
 assert(event=='chat:receive' and source==coreResource,'deliver to core client handler')
 received[p.id]={text=payload.text:gsub('^%[%d%d:%d%d%] ',''),color=payload.color,type=payload.type}
end
dofile('resources/rp_core/systems/chat/config.lua')
dofile('resources/rp_core/systems/chat/server.lua')
exports={rp_core={sendCoreChatMessage=function(_,...) return sendCoreChatMessage(...) end}}
dofile('resources/rp_fraction/server/radio.lua')
commands.r(people[2],'r','Привет')
assert(received[2] and received[7] and not received[1] and not received[9],'fraction radio reaches only authenticated members of own faction')
assert(received[2].text=='[Кадет] Player_2: Привет' and received[2].color[3]==255 and received[2].type=='radio','rank, name and blue plain text')
received={};commands.rb(people[2],'rb','spam');assert(not next(received),'shared rate limit covers IC and OOC')
now=2000;commands.rb(people[2],'rb','#FF0000OOC');assert(received[7].text=='[Кадет] Player_2 (( OOC ))','OOC brackets and stripped color codes')
received={};now=3000;commands.d(people[1],'d','Общий канал')
assert(received[1] and received[2] and received[3] and received[7] and not received[4] and not received[8] and not received[9],'department channel limited to three authenticated organizations')
assert(received[2].color[1]==240 and received[2].color[2]==135,'department pink color')
received={};now=4000;commands.db(people[3],'db','OOC')
assert(received[1].text=='['..Fractions[3].ranks[1]..'] Player_3 (( OOC ))','department OOC format')
received={};now=5000;commands.d(people[4],'d','No');assert(not next(received),'mafia cannot transmit to department')
commands.r(people[8],'r','No');assert(not next(received),'civilian cannot transmit')
people[2]['admin:muted']=true;people[2]['admin:muteExpires']=now+10
commands.r(people[2],'r','No');assert(not next(received),'native command cannot bypass mute')
people[2]['admin:muteExpires']=now-1
commands.r(people[2],'r','Allowed');assert(received[7],'expired mute does not block radio')
print('Radio: routing, authentication, organization isolation, colors, OOC, sanitization, cooldown and mute passed')

-- Exercise input through the real custom chat, exported bridge and handlers.
function getResourceFromName(name) return name=='rp_core' and coreResource or fractionResource end
function getResourceState() return 'running' end
function getResourceExportedFunctions() return {'executeFractionCommand'} end
function call(resource,name,...) local previous=sourceResource;sourceResource=coreResource;local result=executeFractionCommand(...);sourceResource=previous;return result end
function executeCommandHandler(name,p,args)
 local words={};for word in args:gmatch('%S+') do words[#words+1]=word end
 commands[name](p,name,unpack(words))
end
dofile('resources/rp_fraction/server/members.lua')
people[2]['auth:loggedIn']=true;people[2]['admin:muted']=false
for _,command in ipairs({'r','rb','d','db'}) do
 now=now+1000;received={}
 RPChat.processMessage(people[2],'/'..command..' Проверка')
 assert(received[7] and received[7].text:find('Проверка',1,true),'custom chat command '..command..' reaches visible chat')
 assert((received[1]~=nil)==(command=='d' or command=='db'),'correct audience through custom chat route')
end
assert(not sendCoreChatMessage(nil,'No'),'invalid chat recipient rejected')
print('Radio integration: all four custom chat commands reach the core client event with correct source and audience')
