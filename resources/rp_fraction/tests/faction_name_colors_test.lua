dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local handlers={};local p={data={}};local member
function addEvent() end
function addEventHandler(name,_,fn) handlers[name]=fn end
function setElementData(e,key,value) e.data[key]=value end
function isElement(e) return e==p end
function triggerClientEvent() end
function setElementModel() end
function getElementModel() return 7 end
FractionDB={exec=function() return true end}
dofile('resources/rp_fraction/server/main.lua')
local F=Fraction
F.account=function() return 1 end
F.member=function() return member end
F.workSkin=function() return 7 end
F.clearCuffs=function() end
F.endDuty=function() end
F.justice={}
for fid=1,6 do
 member={account_id=1,faction_id=fid,rank=1}
 F.sessions[p]={account=1,duty=false};F.sync(p)
 local criminal=Fractions[fid].category=='criminal'
 assert((p.data['rp:factionColor']~=false)==criminal,'only mafia has off-duty faction color')
 assert(table.concat(p.data['rp:nametagColor'],',')==table.concat(criminal and Fractions[fid].color or {255,255,255},','),'overhead name uses matching duty policy')
 F.sessions[p].duty=true;F.sync(p)
 assert(p.data['rp:factionColor']==Fractions[fid].color and p.data['rp:nametagColor']==Fractions[fid].color,'TAB and overhead use the same configured faction color')
 F.sessions[p].duty=false;F.sync(p)
 assert((p.data['rp:factionColor']~=false)==criminal,'ending shift restores normal color except mafia')
end
member=nil;F.sync(p);assert(p.data['rp:factionColor']==false,'dismissal clears TAB color')
member={faction_id=4};F.sync(p);F.disconnect(p,true)
assert(p.data['rp:factionColor']==false and table.concat(p.data['rp:nametagColor'],',')=='255,255,255','logout/resource stop clears both color channels')
print('Faction name colors: all six factions, shift transitions, mafia persistence, dismissal and logout passed')

local file=assert(io.open('resources/rp_core/systems/scoreboard/client.lua'));local code=file:read('*a');file:close()
local draw=assert(code:match('(local function drawScoreboard.-)\nlocal function setScoreboardVisible'))
localPlayer={};local calls={}
function getTickCount() return 0 end
function getElementData() return nil end
function tocolor(r,g,b,a) return {r,g,b,a} end
function dxDrawRectangle() end
function dxDrawText(text,_,__,___,____,color) calls[text]=color end
local prefix=[[local sw,sh=1920,1080;local visibleRows=17
local function s(v) return v end
local function crisp(v) return v end
local function drawSearch() end
local function refreshPlayers() end
local board={lastRefresh=0,online=2,scroll=0,players={
{element=localPlayer,id=1,name='OwnName',level=1,ping=10,factionColor={65,130,231}},
{element={},id=2,name='OtherName',level=1,ping=10,factionColor={232,91,122}}}}
]]
assert(loadstring(prefix..draw..'\nreturn drawScoreboard'))()()
assert(table.concat(calls.OwnName,',')=='65,130,231,255','selected own TAB row retains faction color')
assert(table.concat(calls.OtherName,',')=='232,91,122,255','other TAB rows show their faction color')
print('TAB name colors: selected own row and other faction rows render configured colors')
