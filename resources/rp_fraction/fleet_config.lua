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
                { slot=1, x=1535, y=-1678, z=13.4, rotation=0 },
                { slot=2, x=1539, y=-1678, z=13.4, rotation=0 },
                { slot=3, x=1543, y=-1678, z=13.4, rotation=0 },
                { slot=4, x=1547, y=-1678, z=13.4, rotation=0 },
                { slot=5, x=1551, y=-1678, z=13.4, rotation=0 },
                { slot=6, x=1535, y=-1685, z=13.4, rotation=0 },
                { slot=7, x=1539, y=-1685, z=13.4, rotation=0 },
                { slot=8, x=1543, y=-1685, z=13.4, rotation=0 },
                { slot=9, x=1547, y=-1685, z=13.4, rotation=0 },
                { slot=10, x=1551, y=-1685, z=13.4, rotation=0 },
            },
        },
        {
            name = "Полицейские мотоциклы",
            model = 523,
            rank = 3,
            count = 3,
            parking = {
                { slot=11, x=1594, y=-1710, z=5.8, rotation=0 },
                { slot=12, x=1598, y=-1710, z=5.8, rotation=0 },
                { slot=13, x=1602, y=-1710, z=5.8, rotation=0 },
            },
        },
        {
            name = "Enforcer",
            model = 427,
            rank = 6,
            count = 1,
            parking = {
                { slot=14, x=1596, y=-1700, z=6.1, rotation=90 },
            },
        },
        {
            name = "Police Ranger",
            model = 599,
            rank = 4,
            count = 2,
            parking = {
                { slot=15, x=1585, y=-1698, z=6.1, rotation=90 },
                { slot=16, x=1590, y=-1698, z=6.1, rotation=90 },
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
