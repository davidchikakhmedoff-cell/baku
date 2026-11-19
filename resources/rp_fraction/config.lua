FractionConfig = {
    dimensionBase=20000, inviteSeconds=60, proximity=5,
    healPrice=100, smsPrice=1, newsReward=150, textLimit=160,
    cooldown={radio=1,invite=5,heal=5,ticket=10,su=5,cuff=2,uncuff=2,clearwanted=2,putcar=2,arrest=5,unarrest=2,m=5,add=30,sms=3},
    policeTransport={rank=2,radius=3,maxSpeed=1,models={[596]=true,[597]=true,[598]=true}},
    ticket={min=10,max=50000,rank=2,officerPercent=60}, jail={min=1,max=120,perStar=5,radius=15,stationRange=40},
    megaphone={range=80,durationMs=10000,maxLength=100},
    cuffControls={'sprint','jump','fire','aim_weapon','vehicle_fire','vehicle_secondary_fire','enter_exit'},
    cuffPose={forward=0.22,height=-0.04,wristGap=0.07,elbowSide=0.7,elbowForward=0.15,elbowDown=0.25},
    salaryHourMs=3600000, tickMs=5000, idleLimitMs=60000,
    vehicleRespawnMs=5000, vehicleReturnFuel=30, blipVisibleDistance=250, helipadModel=3934,
    markerLabel={distance=12,zOffset=1.2,scale=1,font='default-bold',color={0,190,255,255},outlineColor={0,0,0,220}},
    wantedNoticeColor={125,195,255},
    radio={fractionColor={90,155,255},departmentColor={240,135,195},department={[1]=true,[2]=true,[3]=true}},
    armoryPickupModel=2040, -- GTA SA ammo_box_M1.
    interactionIconZOffset=0.5, -- Clothes and keys: height above the configured point.
    roofDeckModel=3095,
    salaries={500,650,800,950,1100,1300,1500,1750,2000,2500},
    release={x=1552.4,y=-1675.5,z=16.2,rotation=90,interior=0,dimension=0},
    jailCells={{x=264.28,y=77.64,z=1001.03,rotation=90}},
    policeWeapons={{id=3,name='Дубинка',ammo=1,rank=1},{id=24,name='Desert Eagle',ammo=70,rank=2},{id=29,name='MP5',ammo=180,rank=3},{id=31,name='M4',ammo=200,rank=5},{id=34,name='Снайперская винтовка',ammo=20,rank=5},{id='armor',name='Бронежилет',armor=100,rank=1}},
    mafiaWeapons={{id=5,name='Бита',ammo=1,rank=1},{id=23,name='Пистолет с глушителем',ammo=70,rank=2},{id=28,name='Uzi',ammo=180,rank=3},{id=30,name='AK-47',ammo=200,rank=5},{id=34,name='Снайперская винтовка',ammo=20,rank=5},{id='armor',name='Бронежилет',armor=100,rank=1}}
}
local function point(x,y,z,r) return {x=x,y=y,z=z,rotation=r or 0} end
local mafiaRanks={"Новичок","Боец","Проверенный","Старший боец","Авторитет","Бригадир","Советник","Правая рука","Заместитель босса","Босс"}
Fractions = {
 [1]={name="Los Santos Hospital",category="state",color={232,91,122},blip={icon=22,size=2},duty=true,
 ranks={"Интерн","Фельдшер","Врач","Старший врач","Заместитель главврача","Главный врач"},skins={274,275,276,274,275,276},
 -- User-selected stock Inside Track Betting interior; no custom shell.
 entrance=point(1172.0,-1323.3,15.4),interior=3,inside=point(830.6016,5.9404,1004.1797),exit=point(834.0016,5.9404,1004.1797),dutyPoint=point(830.6016,10.3404,1004.1797),keysPoint=point(827.0016,5.9404,1004.1797),roof={inside=point(834.0016,10.3404,1004.1797),slot=3},
 },
 [2]={name="Los Santos Police Department",category="state",color={65,130,231},blip={icon=30,size=2},duty=true,
 ranks={"Кадет","Офицер","Старший офицер","Сержант","Лейтенант","Капитан","Майор","Полковник","Заместитель шефа","Шеф полиции"},skins={280,281,281,281,281,285,285,285,283,61},femaleSkins={129,130,130,130,130,131,131,131,150,151},
 entrance=point(1554.9,-1675.5,16.2),interior=6,inside=point(246.8,65.7,1003.6),exit=point(246.5,62.6,1003.6),dutyPoint=point(253.5,68.8,1003.6),keysPoint=point(248.5,70.8,1003.6),armory=point(257.7,69.2,1003.6),jailBooking=point(264.28,77.64,1001.03),roof={inside=point(253.5,64.4,1003.6),slot=17}},
 [3]={name="Los Santos News",category="neutral",color={181,163,215},blip={icon=0,size=2},duty=true,
 ranks={"Стажёр","Журналист","Редактор","Заместитель директора","Директор"},skins={171,186,187,147,147},
 -- Four Dragons managerial suite floor/door: MTA amx scriptfiles/properties/interiors.txt.
 entrance=point(741.0,-1334.0,13.5),interior=11,inside=point(2003.1178,1018.3948,33.008,0),exit=point(2003.1178,1015.1948,33.008),dutyPoint=point(2007.0,1018.3948,33.008),keysPoint=point(2007.0,1014.7948,33.008),roof={inside=point(1999.5178,1018.3948,33.008),slot=3},
 },
 [4]={name="La Cosa Nostra",category="criminal",color={115,38,52},blip={icon=0,size=2},ranks=mafiaRanks,skins={124,124,125,125,126,126,127,127,113,113},
 entrance=point(862.08,-1245.18,14.8),interior=5,inside=point(1262.1,-785.3,1091.9),exit=point(1262.1,-788.5,1091.9),keysPoint=point(1258,-785.3,1091.9),armory=point(1265,-785.3,1091.9)},
 [5]={name="Yakuza",category="criminal",color={90,93,99},blip={icon=0,size=2},ranks=mafiaRanks,skins={117,117,118,118,120,120,121,122,123,169},
 entrance=point(1767.88,-2020.14,14.13,180),interior=1,inside=point(-2159.9,641.5,1052.4),exit=point(-2159.9,638.3,1052.4),keysPoint=point(-2163,641.5,1052.4),armory=point(-2156,641.5,1052.4)},
 [6]={name="Russian Mafia",category="criminal",color={136,102,73},blip={icon=0,size=2},ranks=mafiaRanks,skins={111,111,112,112,113,113,111,112,113,223},
 entrance=point(1022.7,-1121.2,23.9),interior=12,inside=point(2324.5,-1147.1,1050.7),exit=point(2324.5,-1150.4,1050.7),keysPoint=point(2321,-1147.1,1050.7),armory=point(2327,-1147.1,1050.7)}
}
-- A retained pre-relocation fleet_config.lua must not restore the old Yakuza site.
-- Migrate the exact former defaults and the mistaken positive-Y destination.
-- Custom sites/parking stay editable.
do
 local location=FractionLocationConfig and FractionLocationConfig[5]
 local function at(p,x,y,z)
  return type(p)=='table' and type(p.x)=='number' and type(p.y)=='number' and type(p.z)=='number'
   and math.abs(p.x-x)<0.01 and math.abs(p.y-y)<0.01 and math.abs(p.z-z)<0.01
 end
 if location and (at(location.entrance,1081,-1696.8,13.5) or at(location.entrance,1767.88,2020.14,14.13)) then
  location.entrance=point(1767.88,-2020.14,14.13,180)
  location.outsideSpawn=point(1767.88,-2021.64,14.13,180)
 end
 local entrance=location and location.entrance or Fractions[5].entrance
 if at(entrance,1767.88,-2020.14,14.13) then
  local oldX={1089,1093.5,1098}
  for _,group in ipairs(FractionFleetConfig and FractionFleetConfig[5] or {}) do
   for _,p in ipairs(group.parking or {}) do
    local slot=p.slot
    if type(slot)=='number' and slot%1==0 and slot>=1 and slot<=9 then
     local col=(slot-1)%3;local row=math.floor((slot-1)/3)
     local oldParking=at(p,oldX[col+1],-1708-row*7,13.6) and (p.rotation or 0)==0
     local wrongCityParking=at(p,1759.88+col*4.5,2010.14-row*7,14.13) and p.rotation==180
     if oldParking or wrongCityParking then
      p.x,p.y,p.z,p.rotation=1759.88+col*4.5,-2030.14-row*7,14.13,180
     end
    end
   end
  end
 end
end
FractionFleetWarnings={}
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
local function integer(value,min,max) return finite(value) and value%1==0 and value>=min and value<=max end
local function fleetWarning(id,name,text)
 FractionFleetWarnings[#FractionFleetWarnings+1]='fleet_config.lua: '..Fractions[id].name..' / '..tostring(name)..': '..text
end
local function configureFleet(id,f)
 f.vehicles={};local used={}
 if type(FractionFleetConfig)~='table' then fleetWarning(id,'config','fleet_config.lua не загружен');return end
 for groupIndex,group in ipairs(FractionFleetConfig[id] or {}) do
  local name=type(group)=='table' and (group.name or groupIndex) or groupIndex
  if type(group)~='table' or type(group.parking)~='table' or not integer(group.model,400,611) or not integer(group.rank,1,#f.ranks) then
   fleetWarning(id,name,'проверьте model, rank и список parking')
  else
   local count=group.count==nil and #group.parking or group.count
   if not integer(count,0,2147483647) then fleetWarning(id,name,'count должен быть целым неотрицательным числом');count=0 end
   if count>#group.parking then fleetWarning(id,name,'count больше числа parking; добавьте места. Используется '..#group.parking);count=#group.parking end
   local color
   if group.color~=nil then
    local valid=type(group.color)=='table' and #group.color==6
    if valid then for i=1,6 do if not integer(group.color[i],0,255) then valid=false;break end end end
    if valid then color=group.color else fleetWarning(id,name,'color должен содержать 6 целых RGB-значений от 0 до 255') end
   end
   for index,p in ipairs(group.parking) do
    if type(p)~='table' or not integer(p.slot,1,2147483647) or used[p.slot] or not finite(p.x) or not finite(p.y) or not finite(p.z) or not finite(p.rotation or 0) then
     fleetWarning(id,name,'некорректное место parking #'..index..' или повторяющийся slot')
    else
     used[p.slot]=true
     if index<=count then f.vehicles[#f.vehicles+1]={slot=p.slot,model=group.model,rank=group.rank,color=color,p=point(p.x,p.y,p.z,p.rotation),helipad=group.helipad==true,roofDeck=group.roofDeck==true} end
    end
   end
  end
 end
end
for id,f in pairs(Fractions) do
 if id==1 then f.vehicleColor={245,245,245,232,91,122}
 elseif id==2 then f.vehicleColor={0,0,0,245,245,245}
 elseif id==3 then f.vehicleColor={181,163,215,245,245,245}
 elseif id==5 then f.vehicleColor={35,5,12,0,0,0}
 else f.vehicleColor={f.color[1],f.color[2],f.color[3],f.color[1],f.color[2],f.color[3]} end
 f.id=id;f.dimension=FractionConfig.dimensionBase+id;f.salaries=f.salaries or {}
 for rank=1,#f.ranks do f.salaries[rank]=f.salaries[rank] or FractionConfig.salaries[rank] end
 if SkinConfig and SkinConfig.factions[id] then
  f.femaleSkins={}
  for rank=1,#f.ranks do
   local male=SkinConfig.list(id,'male',rank);local female=SkinConfig.list(id,'female',rank)
   f.skins[rank]=male[#male] and male[#male].model or f.skins[rank]
   f.femaleSkins[rank]=female[#female] and female[#female].model or f.skins[rank]
  end
 end
 configureFleet(id,f)
 if f.roof then for _,v in ipairs(f.vehicles) do if v.slot==f.roof.slot then
  f.roof.outside=point(v.p.x+5.5,v.p.y,v.p.z,90)
 end end end
 f.weapons=id==2 and FractionConfig.policeWeapons or (f.category=="criminal" and FractionConfig.mafiaWeapons or nil)
end

for id,location in pairs(FractionLocationConfig or {}) do
 local f=Fractions[id]
 if f then for key,value in pairs(location) do f[key]=value end end
end
