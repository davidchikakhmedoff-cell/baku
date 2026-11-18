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
function outputChatBox(text,p,r,g,b,colorCoded) received[p.id]={text=text,color={r,g,b},codes=colorCoded} end
dofile('resources/rp_fraction/server/radio.lua')
commands.r(people[2],'r','Привет')
assert(received[2] and received[7] and not received[1] and not received[9],'fraction radio reaches only authenticated members of own faction')
assert(received[2].text=='[Кадет] Player_2: Привет' and received[2].color[3]==255 and received[2].codes==false,'rank, name and blue plain text')
received={};commands.rb(people[2],'rb','spam');assert(not next(received),'shared rate limit covers IC and OOC')
now=2000;commands.rb(people[2],'rb','#FF0000OOC');assert(received[7].text=='(( [Кадет] Player_2: OOC ))','OOC brackets and stripped color codes')
received={};now=3000;commands.d(people[1],'d','Общий канал')
assert(received[1] and received[2] and received[3] and received[7] and not received[4] and not received[8] and not received[9],'department channel limited to three authenticated organizations')
assert(received[2].color[1]==240 and received[2].color[2]==135,'department pink color')
received={};now=4000;commands.db(people[3],'db','OOC')
assert(received[1].text:sub(1,2)=='((','department OOC format')
received={};now=5000;commands.d(people[4],'d','No');assert(not next(received),'mafia cannot transmit to department')
commands.r(people[8],'r','No');assert(not next(received),'civilian cannot transmit')
people[2]['admin:muted']=true;people[2]['admin:muteExpires']=now+10
commands.r(people[2],'r','No');assert(not next(received),'native command cannot bypass mute')
people[2]['admin:muteExpires']=now-1
commands.r(people[2],'r','Allowed');assert(received[7],'expired mute does not block radio')
print('Radio: routing, authentication, organization isolation, colors, OOC, sanitization, cooldown and mute passed')
