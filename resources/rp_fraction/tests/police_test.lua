dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local commands,events={},{}
local officer={id=1,faction=2,rank=9,duty=true,x=1554,y=-1675,z=16,interior=0,dimension=0,stars=0,controls={}}
local suspect={id=2,x=1554,y=-1675,z=16,interior=0,dimension=0,stars=3,controls={jump=false}}
local states={}
Fraction={cuffs={},vehicles={},sessions={}}
local F=Fraction
F.account=function(p) return type(p)=='table' and p.id end
F.player=function(id) return tonumber(id)==2 and suspect end
F.active=function(p,fid,rank) return p and p.faction==fid and p.duty and p.rank>=(rank or 1) end
F.throttle=function() return true end
F.near=function() return not suspect.far end
F.notify=function() end
F.endDuty=function(p) p.duty=false end
F.now=function() return 1000 end
F.name=function(p) return 'Player'..p.id end
FractionDB={}
FractionDB.one=function(sql,id) return states[id] end
FractionDB.exec=function(sql,...)
 local a,b,c,d=...
 if sql:find('INSERT OR IGNORE INTO fraction_state') then states[a]=states[a] or {account_id=a,wanted=0,jail_remaining=0}
 elseif sql:find('SET jail_remaining=?,jail_reason',1,true) then states[d].jail_remaining=a;states[d].jail_reason=b
 elseif sql:find('SET jail_remaining=') then states[b].jail_remaining=a
 elseif sql:find('SET wanted=') then states[b].wanted=a end
 return true
end
function addCommandHandler(name,fn) commands[name]=fn end
function addEventHandler(name,element,fn) events[name]=fn end
function isElement(p) return type(p)=='table' end
function isPedDead(p) return p.dead end
function isPedInVehicle(p) return p.vehicle~=nil end
function getPedOccupiedVehicle(p) return p.vehicle end
function getPedOccupiedVehicleSeat() return 0 end
function getElementDimension(p) return p.dimension end
function getElementInterior(p) return p.interior end
function getElementPosition(p) return p.x,p.y,p.z end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.sqrt((x-a)^2+(y-b)^2+(z-c)^2) end
function setElementDimension(p,d) p.dimension=d end
function setElementInterior(p,i) p.interior=i end
function setElementPosition(p,x,y,z) p.x,p.y,p.z=x,y,z end
function getPlayerWantedLevel(p) return p.stars end
function setPlayerWantedLevel(p,n) p.stars=n end
function isControlEnabled(p,name) if p.controls[name]~=nil then return p.controls[name] end;return true end
function toggleControl(p,name,value) p.controls[name]=value end
function setPedWeaponSlot() end
function setElementData(p,key,value) p[key]=value end
function triggerClientEvent() end
function takeAllWeapons() end
function setCameraTarget() end
function getElementType() return 'player' end
function getCivilianSkin() return 0 end
function spawnPlayer(p,x,y,z) p.dead=false;p.x,p.y,p.z=x,y,z end
root,resourceRoot={},{}
assert(loadfile('resources/rp_fraction/server/police.lua'))()
commands.su(officer,'su','2','6','reason');assert(suspect.stars==6,'wanted capped at 6')
commands.clearwanted(officer,'clearwanted','2');assert(suspect.stars==0,'deputy clears wanted')
officer.rank=2;suspect.stars=3;commands.clearwanted(officer,'clearwanted','2');assert(suspect.stars==3,'ordinary officer cannot clear wanted')
commands.cuff(officer,'cuff','2');assert(F.cuffs[suspect] and suspect.controls.fire==false and suspect.controls.sprint==false,'cuffs disable attacks/sprint')
commands.cuff(officer,'cuff','2');assert(not F.cuffs[suspect] and suspect.controls.fire and suspect.controls.jump==false,'uncuff restores prior controls')
commands.cuff(officer,'cuff','2');F.clearCuffs(officer,true);assert(not F.cuffs[suspect],'officer quit/dismissal clears issued cuffs')
suspect.far=true;commands.cuff(officer,'cuff','2');assert(not F.cuffs[suspect],'remote cuff rejected');suspect.far=false
commands.arrest(officer,'arrest','2','2','reason');assert(F.jailed(suspect) and suspect.stars==0 and suspect.dimension==20100,'arrest teleports and clears wanted')
local original=states[2].jail_remaining;F.arrest(suspect,10,'again');assert(states[2].jail_remaining==original,'duplicate arrest cannot extend sentence')
F.justice={};assert(F.jailed(suspect) and states[2].jail_remaining==120,'reconnect reads persisted sentence')
F.jailTick(suspect,60000);assert(states[2].jail_remaining==60,'online time decrements sentence')
F.jailTick(suspect,60000);assert(not F.jailed(suspect) and suspect.dimension==0,'sentence ends at release point')
suspect.stars=2;suspect.dead=true;source=suspect
events.onPlayerWasted(0,officer);assert(F.jailed(suspect) and states[2].jail_remaining==240,'police kill uses two minutes per star')
events.onPlayerWasted(0,officer);assert(states[2].jail_remaining==240,'repeated death does not double arrest')
assert(applyFactionJail(suspect) and not suspect.dead,'core respawn adapter keeps sentenced players jailed')
print('Police: wanted, cuff restoration, permissions, persisted jail, release and death-arrest checks passed')
