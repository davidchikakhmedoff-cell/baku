TuningShops = {
    {
        id = 1,
        type = "all",
        name = "Тюнинг-ателье Лос-Сантос",
        marker = { x = 1041.42, y = -1028.32, z = 31.10, size = 3.2, interior = 0, dimension = 0 },
        blip = { x = 1041.42, y = -1028.32, z = 32.10, icon = 27, size = 2, color = {79, 195, 247, 255}, visibleDistance = 250 },
        enterPoint = { x = 1041.42, y = -1028.32, z = 31.10, rotation = 0, interior = 0, dimension = 0 },
        exitPoint = { x = 1041.42, y = -1035.10, z = 31.75, rotation = 180, interior = 0, dimension = 0 },
        distance = 5
    },
    {
        id = 2,
        type = "all",
        name = "Тюнинг-ателье Сан-Фиерро",
        marker = { x = -1936.18, y = 245.03, z = 33.46, size = 3.2, interior = 0, dimension = 0 },
        blip = { x = -1936.18, y = 245.03, z = 34.46, icon = 27, size = 2, color = {79, 195, 247, 255}, visibleDistance = 250 },
        enterPoint = { x = -1936.18, y = 245.03, z = 33.46, rotation = 90, interior = 0, dimension = 0 },
        exitPoint = { x = -1944.15, y = 245.03, z = 34.32, rotation = 270, interior = 0, dimension = 0 },
        distance = 5
    },
    {
        id = 3,
        type = "all",
        name = "Тюнинг-ателье Лас-Вентурас",
        marker = { x = 2386.66, y = 1043.60, z = 9.82, size = 3.2, interior = 0, dimension = 0 },
        blip = { x = 2386.66, y = 1043.60, z = 10.82, icon = 27, size = 2, color = {79, 195, 247, 255}, visibleDistance = 250 },
        enterPoint = { x = 2386.66, y = 1043.60, z = 9.82, rotation = 0, interior = 0, dimension = 0 },
        exitPoint = { x = 2386.66, y = 1035.90, z = 10.67, rotation = 180, interior = 0, dimension = 0 },
        distance = 5
    }
}

TestTuningShop = {
    position = { x = 548.80, y = -1275.30, z = 16.90, size = 3.2, interior = 0, dimension = 0 },
    returnPosition = { x = 548.80, y = -1281.20, z = 16.90, rotation = 180, interior = 0, dimension = 0 }
}

TuningShops[#TuningShops + 1] = {
    id = 99,
    type = "all",
    name = "Тестовое тюнинг-ателье",
    marker = {
        x = TestTuningShop.position.x,
        y = TestTuningShop.position.y,
        z = TestTuningShop.position.z,
        size = TestTuningShop.position.size,
        interior = TestTuningShop.position.interior,
        dimension = TestTuningShop.position.dimension
    },
    blip = { x = TestTuningShop.position.x, y = TestTuningShop.position.y, z = TestTuningShop.position.z + 1, icon = 27, size = 2, color = {79, 195, 247, 255}, visibleDistance = 250 },
    enterPoint = { x = TestTuningShop.position.x, y = TestTuningShop.position.y, z = TestTuningShop.position.z, rotation = 0, interior = 0, dimension = 0 },
    exitPoint = {
        x = TestTuningShop.returnPosition.x,
        y = TestTuningShop.returnPosition.y,
        z = TestTuningShop.returnPosition.z,
        rotation = TestTuningShop.returnPosition.rotation,
        interior = TestTuningShop.returnPosition.interior,
        dimension = TestTuningShop.returnPosition.dimension
    },
    distance = 5
}

function getTuningShopById(id)
    id = tonumber(id)
    for _, shop in ipairs(TuningShops or {}) do
        if tonumber(shop.id) == id then return shop end
    end
    return false
end
