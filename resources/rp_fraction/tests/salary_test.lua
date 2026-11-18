dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua');dofile('resources/rp_fraction/shared.lua')
local p={};local now,idle,active=0,0,true
local member={account_id=1,faction_id=2,rank=2,salary_ms=3595000,salary_cycle=0}
local paid,keys=0,{}
Fraction={sessions={[p]={last=0}},cuffs={}}
Fraction.account=function() return 1 end
Fraction.active=function() return active end
Fraction.member=function() return member end
Fraction.reload=function() return member end
Fraction.notify=function() end
Fraction.jailTick=function() end
Fraction.fleetTick=function() end
Fraction.credit=function(id,amount,key)
 if keys[key] then return false end
 keys[key]=true;paid=paid+amount;member.salary_ms=member.salary_ms-FractionConfig.salaryHourMs;member.salary_cycle=member.salary_cycle+1;return true
end
FractionDB={exec=function() return true end}
function addCommandHandler() end
function getTickCount() return now end
function getPlayerIdleTime() return idle end
function isElement() return true end
function setPedWeaponSlot() end
assert(loadfile('resources/rp_fraction/server/services.lua'))()
now=5000;Fraction.tick();assert(paid==650 and member.salary_ms==0 and member.salary_cycle==1,'one active hour pays rank salary')
Fraction.tick();assert(paid==650,'same tick cannot pay twice')
now=10000;idle=60001;Fraction.tick();assert(member.salary_ms==0,'AFK time excluded')
idle=0;active=false;now=15000;Fraction.tick();assert(member.salary_ms==0,'off duty excluded')
active=true;now=20000;Fraction.tick();assert(member.salary_ms==5000,'eligible time accrues')
Fraction.sessions={};now=100000;Fraction.tick();assert(member.salary_ms==5000,'offline time excluded')
Fraction.sessions[p]={last=now};now=105000;Fraction.tick();assert(member.salary_ms==10000,'reconnect retains remainder')
print('Salary: hour threshold, duplicate prevention, AFK, duty, offline and reconnect checks passed')
