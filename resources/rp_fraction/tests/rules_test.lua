assert(loadfile('resources/rp_fraction/fleet_config.lua'))();assert(loadfile('resources/rp_fraction/config.lua'))();assert(loadfile('resources/rp_fraction/shared.lua'))()
local checks=0;local function check(value,message) checks=checks+1;assert(value,message) end
local counts={6,10,5,10,10,10};local vehicles={4,17,4,9,9,9}
for id,f in pairs(Fractions) do
 check(#f.ranks==counts[id],'rank count');check(#f.vehicles==vehicles[id],'fleet count')
 check(f.dimension>0 and f.dimension<=65535,'valid dimension')
 local actor={account_id=1,faction_id=id,rank=#f.ranks};local deputy={account_id=2,faction_id=id,rank=#f.ranks-1};local worker={account_id=3,faction_id=id,rank=1}
 check(FractionRules.canManage(actor,worker,'rank'),'leader can set rank')
 check(FractionRules.canManage(actor,deputy,'dismiss'),'leader can dismiss deputy')
 check(not FractionRules.canManage(actor,actor,'rank'),'self promotion denied')
 check(not FractionRules.canManage(actor,actor,'dismiss'),'self dismissal denied')
 check(not FractionRules.canManage(deputy,worker,'rank'),'deputy cannot promote')
 check(FractionRules.canManage(deputy,worker,'dismiss'),'deputy can dismiss worker')
 check(not FractionRules.canManage(deputy,actor,'dismiss'),'deputy cannot dismiss leader')
 check(not FractionRules.canManage(deputy,{account_id=4,faction_id=id,rank=deputy.rank},'dismiss'),'deputy cannot dismiss deputy')
 for rank=1,#f.ranks do check(f.skins[rank] and f.salaries[rank]>0,'skin/salary configured for every rank') end
end
check(not FractionRules.integer(0/0,1,10),'NaN rejected');check(not FractionRules.integer(2.5,1,10),'fractional rank rejected')
check(not FractionRules.integer(math.huge,1,10),'infinity rejected');check(not FractionRules.text('','160'),'empty rejected')
check(FractionRules.text('#FF0000hello\nthere')=='hello there','chat formatting and controls sanitized')
print('Fraction rules: '..checks..' checks passed')
