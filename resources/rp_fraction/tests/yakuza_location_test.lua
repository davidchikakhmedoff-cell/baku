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
local function verify(customParking)
 local f=Fractions[5]
 assert(f.entrance.x==1767.88 and f.entrance.y==-2020.14 and f.entrance.z==14.13 and f.entrance.rotation==180,'actual resolved entrance must use requested warehouse')
 assert(f.outsideSpawn.y==-2021.64 and #f.vehicles==9)
 for slot,v in ipairs(f.vehicles) do
  assert(v.slot==slot,'fleet identity preserved')
  if customParking then
   local x=slot==9 and 1807.7 or 1808.7
   local z=slot<=5 and 13.25 or (slot<=8 and 13.12 or 13.22)
   assert(v.p.x==x and v.p.y==-2021.5-(slot-1)*3.5 and v.p.z==z and v.p.rotation==90,'user uploaded parking must be retained exactly')
  else
   assert(v.p.x>1750 and v.p.x<1780 and v.p.y>-2050 and v.p.y<-2025 and v.p.rotation==180,'legacy parking migrates to warehouse')
  end
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
defaults();load();verify(true)
assert(table.concat(Fractions[5].vehicleColor,',')=='35,5,12,0,0,0','all Yakuza vehicles use burgundy primary and black secondary')
for index=1,5 do assert(Fractions[5].vehicles[index].model==421,'five Yakuza sedans use new model 421') end
assert(Fractions[5].vehicles[6].model==404 and Fractions[5].vehicles[9].model==409,'Toyota 404 replaces three SUVs while limousine stays unchanged')
for slot=6,8 do assert(table.concat(Fractions[5].vehicles[slot].color,',')=='35,5,12,0,0,0','Toyota group matches the shared dark burgundy color') end
assert(not Fractions[5].vehicles[1].color and not Fractions[5].vehicles[9].color,'Lexus and limousine keep the faction default color')
oldFleet();load();verify();load();verify() -- partial update and repeat initialization
wrongCityFleet();load();verify();load();verify() -- wrong-city deployment migrates to Los Santos
oldFleet();FractionFleetConfig[5][1].parking[1].x=1800
load();assert(Fractions[5].vehicles[1].p.x==1800,'custom parking is never replaced by the default migration')
oldFleet();FractionLocationConfig[5].entrance={x=2000,y=2100,z=15,rotation=90}
load();assert(Fractions[5].entrance.x==2000 and Fractions[5].vehicles[1].p.x==1089,'custom headquarters does not trigger warehouse migration')
assert(Fractions[2].entrance.x==1554.9 and #Fractions[2].vehicles==17,'other factions unaffected')
print('Yakuza location: current and retained old configs, idempotent migration, stable fleet IDs and custom configuration preservation passed')
