-- АВТОПАРКИ ФРАКЦИЙ. После изменения выполните: restart rp_fraction
-- count: сколько машин группы создавать; 0 отключает группу.
-- Для увеличения количества добавьте парковочные места в parking и увеличьте count.
-- model: ID модели GTA SA; rank: минимальный ранг водителя.
-- x/y/z: мировые координаты места, rotation: поворот машины в градусах.
-- slot: постоянный номер машины ВНУТРИ ФРАКЦИИ. Не меняйте его у существующей
-- машины и не повторяйте в другой группе: по нему сохраняется её топливо.
-- Чтобы добавить новую машину, скопируйте строку parking с новым свободным slot.
-- helipad=true: создать посадочную площадку под каждой машиной этой группы.

FractionFleetConfig = {
    -- 1. Los Santos Hospital
    [1] = {
        {
            name = "Кареты скорой помощи",
            model = 416,
            rank = 1,
            count = 2,
            parking = {
                { slot=1, x=1180, y=-1338, z=13.7, rotation=270 },
                { slot=2, x=1180, y=-1344, z=13.7, rotation=270 },
            },
        },
        {
            name = "Вертолёты Maverick",
            model = 487,
            rank = 5,
            count = 1,
            helipad = true,
            roofDeck = true,
            parking = {
                { slot=3, x=1176, y=-1326, z=26.5, rotation=0 },
            },
        },
        {
            name = "Седаны",
            model = 405,
            rank = 3,
            count = 1,
            parking = {
                { slot=4, x=1180, y=-1350, z=13.6, rotation=270 },
            },
        },
    },
    -- 2. Los Santos Police Department
    [2] = {
        {
            name = "Патрульные автомобили",
            model = 596,
            rank = 2,
            count = 10,
            parking = {
                { slot=1, x=1595.5, y=-1710, z=5.8, rotation=0 },
                { slot=2, x=1591.5, y=-1710, z=5.8, rotation=0 },
                { slot=3, x=1587.5, y=-1710, z=5.8, rotation=0 },
                { slot=4, x=1583.5, y=-1710, z=5.8, rotation=0 },
                { slot=5, x=1578.5, y=-1710, z=5.8, rotation=0 },
                { slot=6, x=1574.5, y=-1710, z=5.8, rotation=0 },
                { slot=7, x=1570.5, y=-1710, z=5.8, rotation=0 },
                { slot=8, x=1566.5, y=-1710, z=5.8, rotation=0 },
                { slot=9, x=1562.5, y=-1710, z=5.8, rotation=0 },
                { slot=10, x=1559, y=-1710, z=5.8, rotation=0 },
            },
        },
        {
            name = "Полицейские мотоциклы",
            model = 523,
            rank = 3,
            count = 3,
            parking = {
                { slot=11, x=1545, y=-1684.5, z=5.8, rotation=90 },
                { slot=12, x=1545, y=-1680.5, z=5.8, rotation=90 },
                { slot=13, x=1545, y=-1676.5, z=5.8, rotation=90 },
            },
        },
        {
            name = "Enforcer",
            model = 427,
            rank = 6,
            count = 1,
            parking = {
                { slot=14, x=1545, y=-1672, z=5.8, rotation=90 },
            },
        },
        {
            name = "Police Ranger",
            model = 599,
            rank = 4,
            count = 2,
            parking = {
                { slot=15, x=1545, y=-1668, z=5.8, rotation=90 },
                { slot=16, x=1545, y=-1663, z=5.8, rotation=90 },
            },
        },
        {
            name = "Полицейские вертолёты",
            model = 497,
            rank = 9,
            count = 1,
            parking = {
                { slot=17, x=1568, y=-1694, z=28.6, rotation=90 },
            },
        },
    },
    -- 3. Los Santos News
    [3] = {
        {
            name = "Фургоны News Van",
            model = 582,
            rank = 2,
            count = 2,
            parking = {
                { slot=1, x=751, y=-1355, z=13.6, rotation=0 },
                { slot=2, x=756, y=-1355, z=13.6, rotation=0 },
            },
        },
        {
            name = "Вертолёты Maverick",
            model = 487,
            rank = 4,
            count = 1,
            helipad = true,
            roofDeck = true,
            parking = {
                { slot=3, x=741, y=-1348, z=24, rotation=0 },
            },
        },
        {
            name = "Седаны",
            model = 405,
            rank = 3,
            count = 1,
            parking = {
                { slot=4, x=761, y=-1355, z=13.6, rotation=0 },
            },
        },
    },
    -- 4. La Cosa Nostra
    [4] = {
        {
            name = "Седаны",
            model = 405,
            rank = 2,
            count = 5,
            parking = {
                { slot=1, x=1468, y=-1027, z=23.8, rotation=90 },
                { slot=2, x=1472.5, y=-1027, z=23.8, rotation=90 },
                { slot=3, x=1477, y=-1027, z=23.8, rotation=90 },
                { slot=4, x=1468, y=-1034, z=23.8, rotation=90 },
                { slot=5, x=1472.5, y=-1034, z=23.8, rotation=90 },
            },
        },
        {
            name = "Внедорожники",
            model = 579,
            rank = 4,
            count = 3,
            parking = {
                { slot=6, x=1477, y=-1034, z=23.8, rotation=90 },
                { slot=7, x=1468, y=-1041, z=23.8, rotation=90 },
                { slot=8, x=1472.5, y=-1041, z=23.8, rotation=90 },
            },
        },
        {
            name = "Лимузины",
            model = 409,
            rank = 5,
            count = 1,
            parking = {
                { slot=9, x=1477, y=-1041, z=23.8, rotation=90 },
            },
        },
    },
    -- 5. Yakuza
    [5] = {
        {
            name = "Седаны",
            model = 405,
            rank = 2,
            count = 5,
            parking = {
                { slot=1, x=1089, y=-1708, z=13.6, rotation=0 },
                { slot=2, x=1093.5, y=-1708, z=13.6, rotation=0 },
                { slot=3, x=1098, y=-1708, z=13.6, rotation=0 },
                { slot=4, x=1089, y=-1715, z=13.6, rotation=0 },
                { slot=5, x=1093.5, y=-1715, z=13.6, rotation=0 },
            },
        },
        {
            name = "Внедорожники",
            model = 579,
            rank = 4,
            count = 3,
            parking = {
                { slot=6, x=1098, y=-1715, z=13.6, rotation=0 },
                { slot=7, x=1089, y=-1722, z=13.6, rotation=0 },
                { slot=8, x=1093.5, y=-1722, z=13.6, rotation=0 },
            },
        },
        {
            name = "Лимузины",
            model = 409,
            rank = 5,
            count = 1,
            parking = {
                { slot=9, x=1098, y=-1722, z=13.6, rotation=0 },
            },
        },
    },
    -- 6. Russian Mafia
    [6] = {
        {
            name = "Седаны",
            model = 405,
            rank = 2,
            count = 5,
            parking = {
                { slot=1, x=1019, y=-1140, z=23.9, rotation=180 },
                { slot=2, x=1023.5, y=-1140, z=23.9, rotation=180 },
                { slot=3, x=1028, y=-1140, z=23.9, rotation=180 },
                { slot=4, x=1019, y=-1147, z=23.9, rotation=180 },
                { slot=5, x=1023.5, y=-1147, z=23.9, rotation=180 },
            },
        },
        {
            name = "Внедорожники",
            model = 579,
            rank = 4,
            count = 3,
            parking = {
                { slot=6, x=1028, y=-1147, z=23.9, rotation=180 },
                { slot=7, x=1019, y=-1154, z=23.9, rotation=180 },
                { slot=8, x=1023.5, y=-1154, z=23.9, rotation=180 },
            },
        },
        {
            name = "Лимузины",
            model = 409,
            rank = 5,
            count = 1,
            parking = {
                { slot=9, x=1028, y=-1154, z=23.9, rotation=180 },
            },
        },
    },
}

-- МАРКЕРЫ И ТОЧКИ ПОЯВЛЕНИЯ. ID разделов совпадают с ID фракций.
-- entrance/exit — маркеры входа/выхода; inside/outsideSpawn — точки появления.
-- keysPoint/dutyPoint/armory — ключи/смена/оружейная в интерьере.
-- jailSpawn — появление арестованного и центр зоны команды у КПЗ.
-- jailBooking — размеры зоны; отдельного центра нет, чтобы точки не расходились.
-- radius — горизонтальный радиус; height — допустимая разница высоты этажа.
-- roof/garage: inside — маркер внутри, outside — маркер снаружи,
-- arrival — появление снаружи, returnSpawn — появление после возврата внутрь.
-- triggerRadius — радиус входа с крыши/гаража, по умолчанию 0.9 метра.
-- interior/dimension относятся к внутренним точкам; снаружи всегда 0/0.
-- Точки появления размещайте в стороне от маркеров, чтобы не было обратного телепорта.
FractionLocationConfig = {
    -- Los Santos Hospital
    [1] = {
        interior=3, dimension=20001,
        entrance={x=1172.0000,y=-1323.3000,z=15.4000,rotation=0.00},
        inside={x=830.6016,y=5.9404,z=1004.1797,rotation=0.00},
        exit={x=834.0016,y=5.9404,z=1004.1797,rotation=0.00},
        keysPoint={x=827.0016,y=5.9404,z=1004.1797,rotation=0.00},
        dutyPoint={x=830.6016,y=10.3404,z=1004.1797,rotation=0.00},
        outsideSpawn={x=1175.5000,y=-1323.3000,z=15.4000,rotation=0.00},
        roof={triggerRadius=0.9, slot=3, inside={x=834.0016,y=10.3404,z=1004.1797,rotation=0.00}, outside={x=1181.5000,y=-1326.0000,z=26.5000,rotation=90.00},
            arrival={x=1185.0000,y=-1326.0000,z=26.5000,rotation=0.00}, returnSpawn={x=830.6016,y=5.9404,z=1004.1797,rotation=0.00}},
    },
    -- Los Santos Police Department
    [2] = {
        interior=6, dimension=20002,
        entrance={x=1554.9000,y=-1675.5000,z=16.2000,rotation=0.00},
        inside={x=246.8000,y=64.000,z=1003.6000,rotation=0.00},
        exit={x=246.8000,y=62.6000,z=1003.6000,rotation=0.00},
        keysPoint={x=239.4000,y=73.6000,z=1004.6000,rotation=0.00},
        dutyPoint={x=254.5000,y=77.0800,z=1003.3000,rotation=0.00},
        armory={x=256.000,y=74.3000,z=1003.1000,rotation=0.00},
        jailSpawn={x=264.28,y=79.94,z=1001.03,rotation=180},
        jailBooking={radius=5,height=1.2},
        outsideSpawn={x=1552.4000,y=-1675.5000,z=16.2000,rotation=90.00},
        roof={triggerRadius=0.5, slot=17, inside={x=243.0500,y=66.4000,z=1003.6000,rotation=0.00}, outside={x=1565.0700,y=-1684.9000,z=28.4000,rotation=90.00},
            arrival={x=1565.0700,y=-1687.0000,z=28.4000,rotation=180.00}, returnSpawn={x=244.5000,y=66.4000,z=1003.6000,rotation=270.00}},
        garage={
            triggerRadius=0.9,
            inside={x=246.4,y=87.5,z=1003.6},
            outside={x=1568.7,y=-1690.2,z=5.9},
            -- Перед маркером со стороны парковки, в 2 метрах от него, лицом к парковке.
            arrival={x=1568.7,y=-1692.2,z=5.9,rotation=180.00},
            returnSpawn={x=246.4,y=86.0,z=1003.6000,rotation=180.00},
        },
    },
    -- Los Santos News
    [3] = {
        interior=11, dimension=20003,
        entrance={x=741.0000,y=-1334.0000,z=13.5000,rotation=0.00},
        inside={x=2003.1178,y=1018.3948,z=33.0080,rotation=0.00},
        exit={x=2003.1178,y=1015.1948,z=33.0080,rotation=0.00},
        keysPoint={x=2007.0000,y=1014.7948,z=33.0080,rotation=0.00},
        dutyPoint={x=2007.0000,y=1018.3948,z=33.0080,rotation=0.00},
        outsideSpawn={x=744.5000,y=-1334.0000,z=13.5000,rotation=0.00},
        roof={triggerRadius=0.9, slot=3, inside={x=1999.5178,y=1018.3948,z=33.0080,rotation=0.00}, outside={x=746.5000,y=-1348.0000,z=24.0000,rotation=90.00},
            arrival={x=750.0000,y=-1348.0000,z=24.0000,rotation=0.00}, returnSpawn={x=2003.1178,y=1018.3948,z=33.0080,rotation=0.00}},
    },
    -- La Cosa Nostra
    [4] = {
        interior=5, dimension=20004,
        entrance={x=1459.1000,y=-1010.6000,z=26.8000,rotation=0.00},
        inside={x=1262.1000,y=-785.3000,z=1091.9000,rotation=0.00},
        exit={x=1262.1000,y=-788.5000,z=1091.9000,rotation=0.00},
        keysPoint={x=1258.0000,y=-785.3000,z=1091.9000,rotation=0.00},
        armory={x=1265.0000,y=-785.3000,z=1091.9000,rotation=0.00},
        outsideSpawn={x=1462.6000,y=-1010.6000,z=26.8000,rotation=0.00},
    },
    -- Yakuza
    [5] = {
        interior=1, dimension=20005,
        entrance={x=1081.0000,y=-1696.8000,z=13.5000,rotation=0.00},
        inside={x=-2159.9000,y=641.5000,z=1052.4000,rotation=0.00},
        exit={x=-2159.9000,y=638.3000,z=1052.4000,rotation=0.00},
        keysPoint={x=-2163.0000,y=641.5000,z=1052.4000,rotation=0.00},
        armory={x=-2156.0000,y=641.5000,z=1052.4000,rotation=0.00},
        outsideSpawn={x=1084.5000,y=-1696.8000,z=13.5000,rotation=0.00},
    },
    -- Russian Mafia
    [6] = {
        interior=12, dimension=20006,
        entrance={x=1022.7000,y=-1121.2000,z=23.9000,rotation=0.00},
        inside={x=2324.5000,y=-1147.1000,z=1050.7000,rotation=0.00},
        exit={x=2324.5000,y=-1150.4000,z=1050.7000,rotation=0.00},
        keysPoint={x=2321.0000,y=-1147.1000,z=1050.7000,rotation=0.00},
        armory={x=2327.0000,y=-1147.1000,z=1050.7000,rotation=0.00},
        outsideSpawn={x=1026.2000,y=-1121.2000,z=23.9000,rotation=0.00},
    },
}
