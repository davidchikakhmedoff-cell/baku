local function load() dofile('resources/rp_fraction/config.lua') end
local function defaults() dofile('resources/rp_fraction/fleet_config.lua') end
local function oldFleet()
 defaults()
 local f=FractionLocationConfig[5]
 f.entrance={x=1081,y=-1696.8,z=13.5,rotation=0}
 f.outsideSpawn={x=1084.5,y=-1696.8,z=13.5,rotation=0}
 for _,g in ipairs(FractionFleetConfig[5]) do for _,p in ipairs(g.parking) do
  local col=(p.slot-1)%3;local row=math.floor((p.slot-1)/3)
  p.x,p.y,p.z,p.rotation=1089+col*4.5,-1708-row*7,13.6,0
 end end
end
local function verify()
 local f=Fractions[5]
 assert(f.entrance.x==1767.88 and f.entrance.y==-2020.14 and f.entrance.z==14.13 and f.entrance.rotation==180,'actual resolved entrance must use requested warehouse')
 assert(f.outsideSpawn.y==-2021.64 and #f.vehicles==9)
 for slot,v in ipairs(f.vehicles) do
  assert(v.slot==slot and v.p.x>1750 and v.p.x<1780 and v.p.y>-2050 and v.p.y<-2025 and v.p.rotation==180,'each stable fleet slot moves to warehouse')
 end
end
local function wrongCityFleet()
 defaults()
 local f=FractionLocationConfig[5]
 f.entrance={x=1767.88,y=2020.14,z=14.13,rotation=180}
 f.outsideSpawn={x=1767.88,y=2018.64,z=14.13,rotation=180}
 for _,g in ipairs(FractionFleetConfig[5]) do for _,p in ipairs(g.parking) do
  local col=(p.slot-1)%3;local row=math.floor((p.slot-1)/3)
  p.x,p.y,p.z,p.rotation=1759.88+col*4.5,2010.14-row*7,14.13,180
 end end
end
defaults();load();verify()
oldFleet();load();verify();load();verify() -- partial update and repeat initialization
wrongCityFleet();load();verify();load();verify() -- wrong-city deployment migrates to Los Santos
oldFleet();FractionFleetConfig[5][1].parking[1].x=1800
load();assert(Fractions[5].vehicles[1].p.x==1800,'custom parking is never replaced by the default migration')
oldFleet();FractionLocationConfig[5].entrance={x=2000,y=2100,z=15,rotation=90}
load();assert(Fractions[5].entrance.x==2000 and Fractions[5].vehicles[1].p.x==1089,'custom headquarters does not trigger warehouse migration')
assert(Fractions[2].entrance.x==1554.9 and #Fractions[2].vehicles==17,'other factions unaffected')
print('Yakuza location: current and retained old configs, idempotent migration, stable fleet IDs and custom configuration preservation passed')
