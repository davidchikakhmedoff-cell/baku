dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local commands,events={},{}
local officer={id=1,faction=2,rank=9,duty=true,x=1554,y=-1675,z=16,interior=0,dimension=0,stars=0,controls={}}
local suspect={id=2,x=1554,y=-1675,z=16,interior=0,dimension=0,stars=3,controls={jump=false}}
local states={}
local dispatch={}
exports={rp_core={sendCoreChatMessage=function(_,p,text,r,g,b) dispatch[#dispatch+1]={player=p,text=text,color={r,g,b}} end,getPlayerDynamicID=function(_,p) return p.id end}}
local ticketWrites,megaphones=0,0
local lastTicket
local booking=Fractions[2].jailSpawn or Fractions[2].jailBooking
local function setStars(player,level) player.stars=level;if states[player.id] then states[player.id].wanted=level end end
local function atBooking(player) player.x,player.y,player.z=booking.x,booking.y,booking.z;player.interior,player.dimension=6,Fractions[2].dimension end
Fraction={cuffs={},vehicles={},sessions={}}
local F=Fraction
F.account=function(p) return type(p)=='table' and p.id end
F.member=function(p) return p.faction and {faction_id=p.faction,rank=p.rank} end
F.player=function(id) return tonumber(id)==1 and officer or (tonumber(id)==2 and suspect or nil) end
F.active=function(p,fid,rank) return p and p.faction==fid and p.duty and p.rank>=(rank or 1) end
F.throttle=function() return true end
F.near=function() return not suspect.far end
F.notify=function() end
F.endDuty=function(p) p.duty=false end
F.now=function() return 1000 end
F.name=function(p) return 'Player'..p.id end
FractionDB={}
FractionDB.one=function(sql,id) if sql:find('last_insert_rowid',1,true) then return lastTicket end;return states[id] end
FractionDB.exec=function(sql,...)
 local a,b,c,d=...
 if sql:find('INSERT INTO fraction_tickets',1,true) then ticketWrites=ticketWrites+1;lastTicket={id=ticketWrites}
 elseif sql:find('INSERT OR IGNORE INTO fraction_state') then states[a]=states[a] or {account_id=a,wanted=0,jail_remaining=0}
 elseif sql:find('SET jail_remaining=?,jail_reason',1,true) then states[d].jail_remaining=a;states[d].jail_reason=b
 elseif sql:find('SET jail_remaining=') then states[b].jail_remaining=a
 elseif sql:find('SET wanted=') then states[b].wanted=a end
 return true
end
FractionDB.change=function(sql,id)
 assert(sql:find("SET jail_remaining=0",1,true),'guarded unarrest update')
 if states[id] and states[id].jail_remaining>0 then states[id].jail_remaining=0;states[id].jail_reason='';return true end
 return false
end
function setPedRotation(p,value) p.rotation=value end
function getElementData(p,key) return p[key] end
function setPedAnimation() error('handcuffs must not apply a whole-body animation') end
function addEvent() end
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
function triggerClientEvent(p,event) if event=='fraction:megaphone' then megaphones=megaphones+1 end end
function getElementsByType() return {officer,suspect} end
function takeAllWeapons() end
function setCameraTarget() end
function getElementType(e) return e.type or 'player' end
function getVehicleOccupant(v) return v.driver end
function getCivilianSkin() return 0 end
function spawnPlayer(p,x,y,z) p.dead=false;p.x,p.y,p.z=x,y,z end
root,resourceRoot={},{}
assert(loadfile('resources/rp_fraction/server/police.lua'))()
commands.su(officer,'su','2','6','reason');assert(suspect.stars==6,'wanted capped at 6')
assert(dispatch[1].player==officer and dispatch[1].text=='Внимание всем постам! Объявлен в розыск Player2. Уровень розыска - 6. Причина: reason.' and dispatch[1].color[2]==195,'wanted dispatch uses visible custom chat and final level')
commands.clearwanted(officer,'clearwanted','2');assert(suspect.stars==0,'deputy clears wanted')
officer.rank=2;setStars(suspect,3);commands.clearwanted(officer,'clearwanted','2');assert(suspect.stars==3,'ordinary officer cannot clear wanted')
commands.cuff(officer,'cuff','2');assert(suspect['fraction:cuffed']==true,'handcuffs synchronize arm pose flag');assert(F.cuffs[suspect] and suspect.controls.fire==false and suspect.controls.sprint==false,'cuffs disable attacks/sprint')
commands.uncuff(officer,'uncuff','2');assert(not suspect['fraction:cuffed'] and suspect.controls.enter_exit,'uncuff clears arm flag and restores vehicle entry control');assert(not F.cuffs[suspect] and suspect.controls.fire and suspect.controls.jump==false,'uncuff restores prior controls')
commands.cuff(officer,'cuff','2');F.clearCuffs(officer,true);assert(not F.cuffs[suspect],'officer quit/dismissal clears issued cuffs')
suspect.far=true;commands.cuff(officer,'cuff','2');assert(not F.cuffs[suspect],'remote cuff rejected');suspect.far=false
atBooking(officer);atBooking(suspect)
commands.arrest(officer,'arrest','2');assert(F.jailed(suspect) and suspect.stars==0 and suspect.dimension==20100,'arrest teleports and clears wanted')
assert(suspect.y==Fractions[2].jailSpawn.y and suspect.x==Fractions[2].jailSpawn.x and suspect.rotation==180,'prisoner spawns at the exact coordinates supplied by user')
local original=states[2].jail_remaining;F.arrest(suspect,10,'again');assert(states[2].jail_remaining==original,'duplicate arrest cannot extend sentence')
F.justice={};assert(F.jailed(suspect) and states[2].jail_remaining==900,'reconnect reads persisted sentence')
F.jailTick(suspect,60000);assert(states[2].jail_remaining==840,'online time decrements sentence')
F.jailTick(suspect,840000);assert(not F.jailed(suspect) and suspect.dimension==0 and suspect.x==Fractions[2].outsideSpawn.x and suspect.y==Fractions[2].outsideSpawn.y,'sentence ends in front of LSPD entrance')
setStars(suspect,2);suspect.dead=true;suspect.duty=true;source=suspect
events.onPlayerWasted(0,officer);assert(suspect.duty,'death and automatic arrest preserve shift');assert(F.jailed(suspect) and states[2].jail_remaining==600,'police kill uses five minutes per star')
events.onPlayerWasted(0,officer);assert(states[2].jail_remaining==600,'repeated death does not double arrest')
assert(applyFactionJail(suspect) and not suspect.dead,'core respawn adapter keeps sentenced players jailed')
source=officer;officer.dead=true;events.onPlayerWasted(0,nil)
assert(officer.duty,'ordinary death preserves shift')
print('Police: wanted, cuff restoration, permissions, persisted jail, release and death-arrest checks passed')

-- Every police action is exercised at all ten LSPD ranks.
local car={x=booking.x,y=booking.y,z=booking.z,interior=6,dimension=Fractions[2].dimension}
F.vehicles[car]={faction=2}
officer.dead=false
for rank=1,10 do
 officer.rank=rank;officer.duty=true;atBooking(officer)
 suspect.dead=false;suspect.vehicle=nil;atBooking(suspect)
 states[2].jail_remaining=0;setStars(suspect,0)
 commands.su(officer,'su','2','1','test');assert((suspect.stars==1)==(rank>=2),'su minimum rank 2')
 setStars(suspect,5);commands.clearwanted(officer,'clearwanted','2');assert((suspect.stars==0)==(rank>=9),'clearwanted minimum rank 9')
 F.clearCuffs(suspect);commands.cuff(officer,'cuff','2');assert((F.cuffs[suspect]~=nil)==(rank>=2),'cuff minimum rank 2');F.clearCuffs(suspect)
 local count=ticketWrites;commands.ticket(officer,'ticket','2','100','test');assert((ticketWrites>count)==(rank>=2),'ticket minimum rank 2')
 officer.vehicle=car;count=megaphones;commands.m(officer,'m','Stop');assert((megaphones>count)==(rank>=2),'megaphone minimum rank 2');officer.vehicle=nil
 setStars(suspect,1);commands.arrest(officer,'arrest','2');assert(F.jailed(suspect)==(rank>=2),'arrest minimum rank 2')
 if rank>=2 then assert(states[2].jail_remaining==300,'manual arrest also uses five minutes per star') end
end
-- The issuer may target own ID without bypassing duty, rank or station checks.
officer.rank=9;officer.duty=true;setStars(officer,0);officer.vehicle=nil
commands.su(officer,'su','1','6','self test');assert(officer.stars==6,'self wanted works and caps at six')
commands.clearwanted(officer,'clearwanted','1');assert(officer.stars==0,'self clearwanted works')
commands.cuff(officer,'cuff','1');assert(F.cuffs[officer],'self cuff works')
commands.cuff(officer,'cuff','1');assert(not F.cuffs[officer],'self uncuff works')
local count=ticketWrites;commands.ticket(officer,'ticket','1','100','self test');assert(ticketWrites==count+1,'self ticket works')
commands.su(officer,'su','1','1','self test');commands.arrest(officer,'arrest','1')
assert(F.jailed(officer) and states[1].jail_remaining==300,'self arrest works with automatic sentence')
commands.unarrest(officer,'unarrest','1');assert(not F.jailed(officer) and officer.x==Fractions[2].outsideSpawn.x,'leader/deputy can release own test arrest off duty')
print('LSPD commands: all ten ranks checked for ticket, wanted, cuffs, arrest and megaphone; self actions passed')

-- Wanted dispatch reaches every authenticated police member, regardless of shift.
local offDuty={id=3,faction=2,rank=1,duty=false}
function getElementsByType() return {officer,suspect,offDuty} end
officer.duty=true;officer.dimension,officer.interior=0,0;states[1].jail_remaining=0
setStars(suspect,0);dispatch={}
commands.su(officer,'su','2','2','Проверка')
assert(#dispatch==2 and dispatch[1].player==officer and dispatch[2].player==offDuty,'all police receive wanted notices, civilians excluded')
atBooking(officer);atBooking(suspect)
setStars(suspect,6);states[2].jail_remaining=0
commands.arrest(officer,'arrest','2','1','test')
assert(states[2].jail_remaining==1800,'six stars means thirty minutes even with old one-minute argument')
states[2].jail_remaining=0;setStars(suspect,0);officer.duty=false;officer.vehicle=car
local ticketsBefore,radioBefore=ticketWrites,megaphones
commands.su(officer,'su','2','1','test');commands.cuff(officer,'cuff','2')
commands.ticket(officer,'ticket','2','100','test');commands.arrest(officer,'arrest','2','test');commands.m(officer,'m','test')
assert(suspect.stars==0 and not F.cuffs[suspect] and not F.jailed(suspect) and ticketWrites==ticketsBefore and megaphones==radioBefore,'off-duty police actions remain blocked')

-- Arrest is possible only at the booking point, never outside or at another floor.
officer.duty=true;officer.vehicle=nil;setStars(suspect,1);states[2].jail_remaining=0
for _,position in ipairs({{1554,-1675,16,0,0},{booking.x,booking.y,1003.6,6,Fractions[2].dimension},{booking.x+6,booking.y,booking.z,6,Fractions[2].dimension}}) do
 officer.x,officer.y,officer.z,officer.interior,officer.dimension=unpack(position)
 commands.arrest(officer,'arrest','2');assert(not F.jailed(suspect),'arrest outside booking point rejected')
end
atBooking(officer);atBooking(suspect);commands.arrest(officer,'arrest','2');assert(F.jailed(suspect),'arrest succeeds without reason at booking point')
officer.rank=8;commands.unarrest(officer,'unarrest','2');assert(F.jailed(suspect),'rank eight cannot release prisoner')
officer.rank=9;commands.unarrest(officer,'unarrest','2');assert(not F.jailed(suspect) and suspect.x==Fractions[2].outsideSpawn.x,'deputy release moves prisoner outside LSPD')
commands.unarrest(officer,'unarrest','2');assert(not F.jailed(suspect),'repeated release is harmless')

-- Death arrest requires a different police killer; environmental/civilian deaths do not count.
suspect.dead=true;setStars(suspect,2);states[2].jail_remaining=0;source=suspect
events.onPlayerWasted(0,nil);assert(not F.jailed(suspect),'fall/environment death does not jail wanted player')
local civilian={id=4,faction=3,rank=5};events.onPlayerWasted(0,civilian);assert(not F.jailed(suspect),'civilian kill does not jail wanted player')
events.onPlayerWasted(0,offDuty);assert(F.jailed(suspect) and states[2].jail_remaining==600,'any police rank killing wanted player causes five-minute-per-star sentence')
source=officer;officer.dead=true;setStars(officer,2);states[1].jail_remaining=0
events.onPlayerWasted(0,officer);assert(not F.jailed(officer),'police suicide is not a police arrest')
source=suspect;states[2].jail_remaining=0;setStars(suspect,3);car.type='vehicle';car.driver=officer
events.onPlayerWasted(0,car);assert(states[2].jail_remaining==900,'police driver killing wanted player triggers prison')
states[2].jail_remaining=0;setStars(suspect,0);events.onPlayerWasted(0,offDuty);assert(not F.jailed(suspect),'no stars means no automatic prison')

-- A native wanted reset caused by spawn/death is not an authoritative pardon.
states[2].jail_remaining=0;setStars(suspect,4);suspect.stars=0
F.applyJustice(suspect);assert(suspect.stars==4,'wanted restored after GTA spawn reset')
F.justice={};suspect.stars=0;F.applyJustice(suspect);assert(suspect.stars==4,'wanted restored from database after resource restart')
F.arrest(suspect,20,'test');assert(states[2].wanted==0 and suspect.stars==0,'booking clears wanted in database and native state')

officer['fraction:cuffed']=true;source=resourceRoot;client=officer
events['fraction:syncCuffs']()
assert(officer['fraction:cuffed']==false,'resource resync clears stale cuff flag when no server cuffs exist')
