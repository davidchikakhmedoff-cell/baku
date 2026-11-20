-- Canonical names shared by dealership UI, personal cars and faction keys.
-- These entries name models; they do not add offers/prices to the dealership.
VehicleModelNames = {
    [421] = "LEXUX LS 400 XF10",
    [404] = "TOYOTA SEQUOIA",
    [546] = "FORD CROWN VICTORIA",
    [479] = "HUMMER H2",
    [400] = "MERCEDES BENZ ML63 W164",
    [602] = "ASTON MARTIN DB9",
    [480] = "BMW F12",
    [451] = "BMW I8",
    [550] = "FORD TAURUS",
    [413] = "MERCEDES SPRINTER",
    [458] = "SKODA OCTAVIA UNIVERSAL",
    [445] = "VOLKSWAGEN PASSAT CC",
    [416] = "AMBULANCE",
    [582] = "NEWS CAR",
    [405] = "BMW E60",
    [436] = "MERCEDES CLK 55",
    [477] = "MERCEDES C63 COUPE"
}

-- Prices below are provisional and can be changed per offer.
-- Keep dealership/offer IDs stable: the first five European offers retain their IDs.
local function point(x,y,z,rotation)
    return {x=x,y=y,z=z,rotation=rotation or 0,interior=0,dimension=0}
end
local function offer(id,model,price,maxSpeed,x,y,z,rotation,name)
    return {id=id,model=model,customName=assert(name or VehicleModelNames[model]),price=price,maxSpeed=maxSpeed,
        position=point(x,y,z,rotation)}
end
Dealerships = {
    {
        id=1, region="europe", name="Автосалон европейских автомобилей",
        blipIcon=55,blipSize=2,blipColor={79,195,247,255},blipVisibleDistance=250,
        playerSpawn=point(562.2,-1292.8,17.2,0),
        purchasedVehicleSpawn=point(562.12,-1246.21,16.77,300),
        cancelExitPosition=point(562.2,-1292.8,17.2,0),
        vehicles={
            offer(1,560,540000,270,564.5,-1291.2,17.1,0,"BMW M5 F90"), -- BMW M5 F90
            offer(2,579,500000,220,560.5,-1290.7,17.09,0,"BMW X5M E70"), -- BMW X5M E70
            offer(3,529,430000,250,556.5,-1291,17.12,0,"BMW M5 F10"), -- BMW M5 F10
            offer(4,547,160000,190,552.5,-1291,17.1,0,"BMW M3 E46"), -- BMW M3 E46
            offer(5,411,670000,300,566,-1281,16.85,102,"AUDI R8"), -- AUDI R8
            offer(6,405,220000,250,548.5,-1291,17.1,0), -- BMW E60
            offer(7,436,190000,240,544.5,-1291,17.1,0), -- MERCEDES CLK 55
            offer(8,477,460000,280,540.5,-1291,17.1,0), -- MERCEDES C63 COUPE
            offer(9,400,360000,250,536.5,-1291,17.1,0), -- MERCEDES BENZ ML63 W164
            offer(11,602,650000,300,564.3,-1273,16.8,102), -- ASTON MARTIN DB9
            offer(12,480,420000,260,532.5,-1291,17.1,0), -- BMW F12
            offer(13,451,800000,280,565,-1277,16.95,102), -- BMW I8
            offer(14,458,110000,210,528.5,-1291,17.1,0), -- SKODA OCTAVIA UNIVERSAL
            offer(15,445,170000,230,524.5,-1291,17.1,0), -- VOLKSWAGEN PASSAT CC
        }
    },
    {
        id=2, region="america", name="Автосалон американских автомобилей",
        blipIcon=55,blipSize=2,blipColor={79,195,247,255},blipVisibleDistance=250,
        playerSpawn=point(2126.56,1398.25,10.81,0),
        purchasedVehicleSpawn=point(2135.56,1398.25,10.81,180),
        cancelExitPosition=point(2126.56,1398.25,10.81,180),
        vehicles={
            offer(1,550,180000,220,2100.7,1398.1,10.45,180), -- FORD TAURUS
            offer(2,546,150000,210,2103.95,1397.8,10.5,180), -- FORD CROWN VICTORIA
            offer(3,479,320000,180,2107.1,1398,11.03,180), -- HUMMER H2
        }
    },
    {
        id=3, region="russia", name="Автосалон российских автомобилей",
        blipIcon=55,blipSize=2,blipColor={79,195,247,255},blipVisibleDistance=250,
        playerSpawn=point(-1957.25,296.4,35.47,180), -- Wang Cars, San Fierro
        purchasedVehicleSpawn=point(-1946,274,35.47,180),
        cancelExitPosition=point(-1957.25,296.4,35.47,180),
        -- No Russian replacement models have been uploaded yet.
        vehicles={}
    },
    {
        id=4, region="asia", name="Автосалон азиатских автомобилей",
        blipIcon=55,blipSize=2,blipColor={79,195,247,255},blipVisibleDistance=250,
        playerSpawn=point(-1658.6,1206,7.25,270), -- Otto's Autos, San Fierro
        purchasedVehicleSpawn=point(-1651,1207.5,7.25,180),
        cancelExitPosition=point(-1658.6,1206,7.25,270),
        vehicles={
            offer(1,421,140000,230,-1655,1215,13.36,80), -- LEXUX LS 400 XF10 (configured name)
            offer(2,404,290000,210,-1653,1211,13.52,80), -- TOYOTA SEQUOIA
        }
    }
}

function getDealershipById(id)
    id = tonumber(id)
    for _, dealership in ipairs(Dealerships or {}) do
        if tonumber(dealership.id) == id then return dealership end
    end
    return false
end

function getDealershipVehicle(dealershipId, vehicleId)
    local dealership = getDealershipById(dealershipId)
    if not dealership then return false end
    vehicleId = tonumber(vehicleId)
    for _, vehicle in ipairs(dealership.vehicles or {}) do
        if tonumber(vehicle.id) == vehicleId then return vehicle, dealership end
    end
    return false
end
