FractionConfig = {
    dimensionBase=20000, adminLevel=10, inviteSeconds=60, proximity=5,
    healPrice=100, smsPrice=1, newsReward=150, textLimit=160,
    cooldown={invite=5,heal=5,ticket=10,su=5,cuff=2,arrest=5,m=5,add=30,sms=3},
    ticket={min=10,max=50000,rank=2}, jail={min=1,max=120,perStar=2,radius=15,stationRange=40},
    megaphone={range=80,durationMs=10000,maxLength=100},
    cuffControls={'sprint','jump','fire','aim_weapon','vehicle_fire','vehicle_secondary_fire','enter_exit'},
    hospitalRoom={floorModel=3095,center={5000,5000,999.5},tile=9,
      furniture={{1997,4995,5005,1000,90},{1997,4999,5005,1000,90},{1997,5003,5005,1000,90},{1997,5007,5005,1000,90},
      {2184,4994,4995,1000,0},{1671,4994,4996,1000.5,180}}},
    salaryHourMs=3600000, tickMs=5000, idleLimitMs=60000,
    armoryCooldown=600, vehicleRespawnMs=60000, labelDistance=30, helipadModel=3934,
    salaries={500,650,800,950,1100,1300,1500,1750,2000,2500},
    release={x=1544.5,y=-1675.5,z=13.6,rotation=90,interior=0,dimension=0},
    jailCells={{x=264.5,y=77.5,z=1001.1},{x=264.5,y=81.0,z=1001.1},{x=264.5,y=85,z=1001.1}},
    policeWeapons={{id=3,ammo=1,rank=1},{id=24,ammo=70,rank=2},{id=29,ammo=180,rank=3},{id=31,ammo=200,rank=5},{id=34,ammo=20,rank=5}},
    mafiaWeapons={{id=5,ammo=1,rank=1},{id=23,ammo=70,rank=2},{id=28,ammo=180,rank=3},{id=30,ammo=200,rank=5},{id=34,ammo=20,rank=5}}
}
local function point(x,y,z,r) return {x=x,y=y,z=z,rotation=r or 0} end
local mafiaRanks={"Новичок","Боец","Проверенный","Старший боец","Авторитет","Бригадир","Советник","Правая рука","Заместитель босса","Босс"}
Fractions = {
 [1]={name="Los Santos Hospital",category="state",color={232,91,122},duty=true,
 ranks={"Интерн","Фельдшер","Врач","Старший врач","Заместитель главврача","Главный врач"},skins={274,275,276,274,275,276},
 entrance=point(1172.0,-1323.3,15.4),customHospital=true,interior=1,inside=point(5000,4992,1001.2),exit=point(5000,4989,1001.2),dutyPoint=point(5005,4992,1001.2),desk=point(4995,4992,1001.2),
 vehicles={{model=416,rank=1,p=point(1180,-1338,13.7,270)},{model=416,rank=1,p=point(1180,-1344,13.7,270)},
 {model=487,rank=5,p=point(1165,-1375,14.2,0)},{model=405,rank=3,p=point(1180,-1350,13.6,270)}}},
 [2]={name="Los Santos Police Department",category="state",color={65,130,231},duty=true,
 ranks={"Кадет","Офицер","Старший офицер","Сержант","Лейтенант","Капитан","Майор","Полковник","Заместитель шефа","Шеф полиции"},skins={280,280,281,281,282,282,283,283,288,288},
 entrance=point(1554.9,-1675.5,16.2),interior=6,inside=point(246.8,65.7,1003.6),exit=point(246.5,62.6,1003.6),dutyPoint=point(253.5,68.8,1003.6),desk=point(248.5,70.8,1003.6),armory=point(257.7,69.2,1003.6),vehicles={}},
 [3]={name="Los Santos News",category="neutral",color={181,163,215},duty=true,
 ranks={"Стажёр","Журналист","Редактор","Заместитель директора","Директор"},skins={171,186,187,147,147},
 entrance=point(741.0,-1334.0,13.5),interior=11,inside=point(2011.6,1017.0,39.1),exit=point(2011.6,1014.5,39.1),dutyPoint=point(2015,1017,39.1),desk=point(2008,1017,39.1),
 vehicles={{model=582,rank=2,p=point(751,-1355,13.6,0)},{model=582,rank=2,p=point(756,-1355,13.6,0)},{model=487,rank=4,p=point(738,-1355,14.0,0)},{model=405,rank=3,p=point(761,-1355,13.6,0)}}},
 [4]={name="La Cosa Nostra",category="criminal",color={115,38,52},ranks=mafiaRanks,skins={124,124,125,125,126,126,127,127,113,113},
 entrance=point(1459.1,-1010.6,26.8),interior=5,inside=point(1262.1,-785.3,1091.9),exit=point(1262.1,-788.5,1091.9),desk=point(1258,-785.3,1091.9),armory=point(1265,-785.3,1091.9),fleet=point(1468,-1027,23.8,90)},
 [5]={name="Yakuza",category="criminal",color={90,93,99},ranks=mafiaRanks,skins={117,117,118,118,120,120,121,122,123,169},
 entrance=point(1081.0,-1696.8,13.5),interior=1,inside=point(-2159.9,641.5,1052.4),exit=point(-2159.9,638.3,1052.4),desk=point(-2163,641.5,1052.4),armory=point(-2156,641.5,1052.4),fleet=point(1089,-1708,13.6,0)},
 [6]={name="Russian Mafia",category="criminal",color={136,102,73},ranks=mafiaRanks,skins={111,111,112,112,113,113,111,112,113,223},
 entrance=point(1022.7,-1121.2,23.9),interior=12,inside=point(2324.5,-1147.1,1050.7),exit=point(2324.5,-1150.4,1050.7),desk=point(2321,-1147.1,1050.7),armory=point(2327,-1147.1,1050.7),fleet=point(1019,-1140,23.9,180)}
}
-- Stock LSPD parking/garage and roof. Never put surface cars on the roof.
for i=1,10 do Fractions[2].vehicles[#Fractions[2].vehicles+1]={model=596,rank=2,p=point(1535+(i-1)%5*4,-1678-math.floor((i-1)/5)*7,13.4,0)} end
for i=1,3 do Fractions[2].vehicles[#Fractions[2].vehicles+1]={model=523,rank=3,p=point(1590+i*4,-1710,5.8,0)} end
Fractions[2].vehicles[#Fractions[2].vehicles+1]={model=427,rank=6,p=point(1596,-1700,6.1,90)}
for i=1,2 do Fractions[2].vehicles[#Fractions[2].vehicles+1]={model=599,rank=4,p=point(1580+i*5,-1698,6.1,90)} end
Fractions[2].vehicles[#Fractions[2].vehicles+1]={model=497,rank=9,p=point(1568,-1694,28.6,90)}
for id,f in pairs(Fractions) do
 if id==1 then f.vehicleColor={245,245,245,232,91,122}
 elseif id==2 then f.vehicleColor={0,0,0,245,245,245}
 elseif id==3 then f.vehicleColor={181,163,215,245,245,245}
 else f.vehicleColor={f.color[1],f.color[2],f.color[3],f.color[1],f.color[2],f.color[3]} end
 f.id=id;f.dimension=FractionConfig.dimensionBase+id;f.salaries=f.salaries or {}
 for rank=1,#f.ranks do f.salaries[rank]=f.salaries[rank] or FractionConfig.salaries[rank] end
 if f.category=="criminal" then
  f.vehicles={}
  for i=1,9 do
   f.vehicles[i]={model=i<=5 and 409 or (i<=8 and 579 or 409),rank=i<=5 and 2 or (i<=8 and 4 or 5),
    p=point(f.fleet.x+((i-1)%3)*4.5,f.fleet.y-math.floor((i-1)/3)*7,f.fleet.z,f.fleet.rotation)}
   if i<=5 then f.vehicles[i].model=405 end
  end
 end
 f.weapons=id==2 and FractionConfig.policeWeapons or (f.category=="criminal" and FractionConfig.mafiaWeapons or nil)
end
