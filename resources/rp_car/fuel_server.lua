-- All quantities and payment decisions live on the server, never in element data.
FuelSystem = {vehicles={}, sessions={}, recovered=false}
local F = FuelSystem
local byId, stations, visits, requests, pendingById = {}, {}, {}, {}, {}
local lastSave, nextRecovery = 0, 0
local function core() local r=getResourceFromName("rp_core");return r and getResourceState(r)=="running" end
local function query(sql, ...)
    if not core() then return false end
    return exports.rp_core:AuthDBQuery(sql, ...)
end
local function exec(sql, ...)
    return core() and exports.rp_core:AuthDBExec(sql, ...)
end
local function notify(player, message, good)
    if isElement(player) and core() then
        exports.rp_core:sendCoreNotification(player, message, good and 103 or 239, good and 196 or 83, good and 216 or 80)
    end
end
local function account(player)
    return core() and getElementData(player, "auth:loggedIn") == true and tonumber(exports.rp_core:getAuthPlayerId(player))
end
local function speed(vehicle)
    local x,y,z = getElementVelocity(vehicle)
    return math.sqrt(x*x+y*y+z*z)*180
end
local function publish(state)
    if not isElement(state.vehicle) then return end
    local value = math.floor(state.fuel*10+0.0001)/10
    if value ~= state.sent then
        state.sent = value
        setElementData(state.vehicle,"car:fuel",value,true)
    end
    if not state.capacitySent then
        state.capacitySent=true;setElementData(state.vehicle,"car:fuelCapacity",state.capacity,true)
    end
end
function F.attach(vehicle, row)
    if F.vehicles[vehicle] then return F.vehicles[vehicle] end
    local state = {vehicle=vehicle,id=row.id,capacity=FuelConfig.capacity(row.model)}
    state.fuel = FuelConfig.clamp(row.fuel,state.capacity)
    F.vehicles[vehicle],byId[row.id]=state,state
    publish(state)
    return state
end
function F.attachExternal(vehicle,key,fuel)
    if F.vehicles[vehicle] then return end
    local state={vehicle=vehicle,id=key,external=true,capacity=FuelConfig.capacity(getElementModel(vehicle))}
    state.fuel=FuelConfig.clamp(fuel,state.capacity)
    F.vehicles[vehicle],byId[key]=state,state
    publish(state)
end
function F.byIdFuel(id)
    return byId[id] and byId[id].fuel
end
function resetVehicleFuelSample(vehicle)
    F.resetSample(vehicle)
    return F.vehicles[vehicle] ~= nil
end
function F.resetSample(vehicle)
    if F.vehicles[vehicle] then F.vehicles[vehicle].sample=nil end
end
function F.get(vehicle)
    local state=F.vehicles[vehicle]
    return state and state.fuel
end
function F.canStart(vehicle)
    local state=F.vehicles[vehicle]
    if not state then return true end
    return state.fuel>0 and not pendingById[state.id] and F.recovered
end
local function persist(state)
    if not state then return true end
    local ok
    if state.external then ok=exec("UPDATE fraction_vehicle_fuel SET fuel=? WHERE vehicle_key=?",state.fuel,state.id)
    else ok=RPCarDB.exec("UPDATE personal_vehicles SET fuel = ? WHERE id = ?",state.fuel,state.id) end
    if ok then
        state.dirty=false
        if RPCarDB.vehicles[state.id] then RPCarDB.vehicles[state.id].fuel=state.fuel end
    end
    return ok
end
local function zone(vehicle)
    if getElementDimension(vehicle)~=0 or getElementInterior(vehicle)~=0 then return end
    for _,station in ipairs(stations) do
        if isElementWithinColShape(vehicle,station.col) then return station end
    end
end
local function valid(player, vehicle, station)
    local state=F.vehicles[vehicle]
    return isElement(player) and CarInteraction.ready(player) and account(player) and isElement(vehicle)
        and getPedOccupiedVehicle(player)==vehicle and getPedOccupiedVehicleSeat(player)==0
        and state and ((state.external and FactionVehicleAdapter and FactionVehicleAdapter.canAccess(player,vehicle))
        or (not state.external and RPCarDB.vehicles[state.id] and RPCarDB.vehicles[state.id].owner_account_id==account(player)))
        and zone(vehicle)==station and speed(vehicle)<1 and not getVehicleEngineState(vehicle)
end
local function balanceRefresh(id)
    local rows=query("SELECT money FROM players WHERE id = ?",id)
    if not rows or not rows[1] then return end
    for _,player in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(player,"auth:playerId"))==id then
            setPlayerMoney(player,tonumber(rows[1].money))
            triggerClientEvent(player,"rp:hud:update",getResourceRootElement(getResourceFromName("rp_core")),{money=tonumber(rows[1].money)})
        end
    end
end
-- Journal and money use the SAME rp_core SQLite connection/transaction. Vehicle
-- fuel is a replayable projection, so a restart between two databases is safe.
local function settle(order)
    local fuel=order.base+order.delivered
    local saved
    if tostring(order.vehicle_id):match('^fraction:') then
        saved=exec("UPDATE fraction_vehicle_fuel SET fuel=? WHERE vehicle_key=?",fuel,order.vehicle_id)
    else saved=RPCarDB.exec("UPDATE personal_vehicles SET fuel = ? WHERE id = ?",fuel,order.vehicle_id) end
    if not saved then return false end
    if RPCarDB.vehicles[order.vehicle_id] then RPCarDB.vehicles[order.vehicle_id].fuel=fuel end
    local state=byId[order.vehicle_id]
    if state then state.fuel=fuel;persist(state);publish(state) end
    local refund=math.max(0,order.paid-math.ceil(order.delivered*order.price-0.000001))
    -- The refund trigger and settled flag are one SQLite statement, idempotent.
    if not exec("UPDATE car_fuel_orders SET charged = ?, settled = 1 WHERE id = ? AND settled = 0",order.paid-refund,order.id) then return false end
    local confirmed=query("SELECT settled FROM car_fuel_orders WHERE id = ?",order.id)
    if not confirmed or not confirmed[1] or tonumber(confirmed[1].settled)~=1 then return false end
    balanceRefresh(order.account_id)
    return true
end
local function finish(vehicle, cancelled)
    local session=F.sessions[vehicle]
    if not session or not settle(session.order) then return false end
    F.sessions[vehicle]=nil
    pendingById[session.order.vehicle_id]=nil
    if isElement(session.player) then
        triggerClientEvent(session.player,"car:fuelClosed",resourceRoot)
        notify(session.player,string.format(cancelled and "Заправка отменена. Выдано %.1f л. Потрачено $%d." or "Автомобиль заправлен на %.1f литров. Потрачено $%d",
            session.order.delivered,math.ceil(session.order.delivered*session.order.price-0.000001)),not cancelled)
    end
    return true
end
function F.detach(vehicle)
    local state=F.vehicles[vehicle]
    if state then
        if F.sessions[vehicle] then finish(vehicle,true) end
        persist(state)
        F.vehicles[vehicle]=nil;byId[state.id]=nil
    end
end
local function recover()
    if not core() or not RPCarDB.connection then return false end
    if not exec([[CREATE TABLE IF NOT EXISTS car_fuel_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
        vehicle_id INTEGER NOT NULL, base REAL NOT NULL, requested REAL NOT NULL,
        delivered REAL NOT NULL DEFAULT 0, price REAL NOT NULL, paid INTEGER NOT NULL, charged INTEGER NOT NULL DEFAULT 0,
        settled INTEGER NOT NULL DEFAULT 0)]]) then return false end
    exec("CREATE UNIQUE INDEX IF NOT EXISTS car_fuel_one_active ON car_fuel_orders(vehicle_id) WHERE settled=0")
    -- Statement triggers keep escrow atomic even with MTA's automatic SQLite batching.
    if not exec([[CREATE TRIGGER IF NOT EXISTS car_fuel_debit_check BEFORE INSERT ON car_fuel_orders
        BEGIN SELECT CASE WHEN COALESCE((SELECT money FROM players WHERE id=NEW.account_id),-1)<NEW.paid
        THEN RAISE(ABORT,'insufficient fuel funds') END; END]]) then return false end
    if not exec([[CREATE TRIGGER IF NOT EXISTS car_fuel_debit AFTER INSERT ON car_fuel_orders
        BEGIN UPDATE players SET money=money-NEW.paid WHERE id=NEW.account_id; END]]) then return false end
    if not exec([[CREATE TRIGGER IF NOT EXISTS car_fuel_refund AFTER UPDATE OF settled ON car_fuel_orders
        WHEN OLD.settled=0 AND NEW.settled=1
        BEGIN UPDATE players SET money=money+NEW.paid-NEW.charged WHERE id=NEW.account_id; END]]) then return false end
    local orders=query("SELECT * FROM car_fuel_orders WHERE settled = 0 ORDER BY id")
    if not orders then return false end
    for _,order in ipairs(orders) do if not settle(order) then return false end end
    return true
end
local function gate(player)
    if not isElement(player) then return false end
    local now=getTickCount()
    if requests[player] and now-requests[player]<400 then return false end
    requests[player]=now
    return F.recovered
end
addEvent("car:fuelOpen",true)
addEventHandler("car:fuelOpen",resourceRoot,function()
    if not client or not gate(client) then return end
    local vehicle=getPedOccupiedVehicle(client)
    local station=vehicle and zone(vehicle)
    if not station or not F.vehicles[vehicle] then return end
    if getVehicleEngineState(vehicle) then notify(client,"Выключите двигатель перед заправкой");return end
    if not valid(client,vehicle,station) then notify(client,"Заправка доступна владельцу за рулём остановленного автомобиля");return end
    if F.sessions[vehicle] then return end
    local state=F.vehicles[vehicle]
    triggerClientEvent(client,"car:fuelMenu",resourceRoot,vehicle,{fuel=state.fuel,capacity=state.capacity,price=station.price,name=station.name,station={x=station.x,y=station.y,z=station.z,radius=station.radius}})
end)
addEvent("car:fuelBuy",true)
addEventHandler("car:fuelBuy",resourceRoot,function(litres)
    if not client or not gate(client) then return end
    local vehicle=getPedOccupiedVehicle(client)
    local state=vehicle and F.vehicles[vehicle]
    local station=vehicle and zone(vehicle)
    if not state or not station or not valid(client,vehicle,station) or F.sessions[vehicle] then return end
    if type(litres)~="number" or litres~=litres or litres<=0 or litres==math.huge or litres>state.capacity-state.fuel+0.000001 then return end
    litres=math.min(litres,state.capacity-state.fuel)
    local paid=math.ceil(litres*station.price-0.000001)
    if paid<1 then return end
    local id=account(client)
    local rows=query("SELECT money FROM players WHERE id = ?",id)
    if not rows or not rows[1] then return end
    -- The current online balance is canonical in rp_core too.
    if getPlayerMoney(client)<paid then notify(client,"Недостаточно средств");return end
    if not persist(state) then return end
    local active=query("SELECT id FROM car_fuel_orders WHERE vehicle_id = ? AND settled = 0",state.id)
    if not active or #active>0 then return end
    local ok=exec("INSERT INTO car_fuel_orders (account_id,vehicle_id,base,requested,price,paid) VALUES (?,?,?,?,?,?)",id,state.id,state.fuel,litres,station.price,paid)
    -- Read back to flush SQLite's queue and detect trigger/constraint failures.
    local inserted=ok and query("SELECT * FROM car_fuel_orders WHERE id = last_insert_rowid() AND account_id = ? AND vehicle_id = ? AND settled = 0",id,state.id)
    if not inserted or not inserted[1] then notify(client,"Оплата не выполнена. Проверьте баланс и попробуйте снова");return end
    balanceRefresh(id)
    pendingById[state.id]=true
    F.sessions[vehicle]={player=client,station=station,last=getTickCount(),order={id=inserted[1].id,account_id=id,vehicle_id=state.id,base=state.fuel,requested=litres,delivered=0,price=station.price,paid=paid}}
    triggerClientEvent(client,"car:fuelProgress",resourceRoot,0,litres,state.fuel)
end)
addEvent("car:fuelCancel",true)
addEventHandler("car:fuelCancel",resourceRoot,function()
    if not client then return end
    for vehicle,session in pairs(F.sessions) do if session.player==client then finish(vehicle,true);return end end
end)
local function sample(state, now)
    local vehicle=state.vehicle
    local x,y,z=getElementPosition(vehicle)
    local dimension,interior=getElementDimension(vehicle),getElementInterior(vehicle)
    local velocity=speed(vehicle)
    local previous=state.sample
    if previous and previous.dimension==dimension and previous.interior==interior and getVehicleEngineState(vehicle) and not F.sessions[vehicle] then
        local distance=getDistanceBetweenPoints3D(x,y,z,previous.x,previous.y,previous.z)
        local used=FuelConfig.used(distance,velocity,now-previous.tick,previous.speed)
        if used>0 then state.fuel=math.max(0,state.fuel-used);state.dirty=true;publish(state) end
    end
    state.sample={x=x,y=y,z=z,dimension=dimension,interior=interior,tick=now,speed=velocity}
    if not F.canStart(vehicle) and getVehicleEngineState(vehicle) then
        setVehicleEngineState(vehicle,false)
        if RPCarDB.vehicles[state.id] then RPCarDB.vehicles[state.id].engine_on=0 end
        if not state.external then RPCarDB.exec("UPDATE personal_vehicles SET engine_on = 0 WHERE id = ?",state.id) end
        setElementData(vehicle,"car:engineOn",false,true)
        setElementData(vehicle,"rp_car:engineOn",false,true)
        local driver=getVehicleOccupant(vehicle,0)
        if state.fuel<=0 and driver then notify(driver,"В автомобиле закончилось топливо") end
        persist(state)
    end
end
local function tick()
    local now=getTickCount()
    if not F.recovered then
        if now<nextRecovery then return end
        nextRecovery=now+5000
        F.recovered=recover()
        if not F.recovered then
            outputDebugString("[RPCar Fuel] Waiting for SQLite/economy journal recovery; refuelling disabled.",2)
            return
        end
    end
    if not core() then return end
    for vehicle in pairs(F.sessions) do
        if not F.vehicles[vehicle] or not isElement(vehicle) then finish(vehicle,true) end
    end
    for vehicle,state in pairs(F.vehicles) do
        if isElement(vehicle) then
            sample(state,now)
            local session=F.sessions[vehicle]
            if session then
                if not valid(session.player,vehicle,session.station) then finish(vehicle,true)
                else
                    local order=session.order
                    local delivered=math.min(order.requested,order.delivered+FuelConfig.litresPerSecond*math.min(now-session.last,1000)/1000)
                    if exec("UPDATE car_fuel_orders SET delivered = ? WHERE id = ? AND settled = 0",delivered,order.id) then
                        local committed=query("SELECT delivered FROM car_fuel_orders WHERE id = ?",order.id)
                        if not committed or not committed[1] or math.abs(tonumber(committed[1].delivered)-delivered)>0.000001 then return end
                        order.delivered=delivered;state.fuel=order.base+delivered;persist(state);publish(state)
                        triggerClientEvent(session.player,"car:fuelProgress",resourceRoot,delivered,order.requested,state.fuel)
                        if delivered>=order.requested then finish(vehicle,false) end
                    end
                    session.last=now
                end
            end
            if now-lastSave>=FuelConfig.saveMs and state.dirty then persist(state) end
            local driver=getVehicleOccupant(vehicle,0)
            if driver then
                local station=zone(vehicle)
                local visit=visits[driver]
                if not station then visits[driver]=nil
                else
                    if not visit or visit.station~=station or visit.vehicle~=vehicle then
                        visit={station=station,vehicle=vehicle};visits[driver]=visit
                        if speed(vehicle)>=1 then notify(driver,"АЗС: остановите автомобиль, чтобы заправиться",true) end
                    end
                    if not visit.ready and speed(vehicle)<1 then visit.ready=true;notify(driver,"Нажмите E, чтобы заправить автомобиль",true) end
                end
            end
        end
    end
    if now-lastSave>=FuelConfig.saveMs then lastSave=now end
end
addEventHandler("onResourceStart",resourceRoot,function()
    for _,config in ipairs(FuelConfig.stations) do
        local station={name=config.name,price=config.price or FuelConfig.price,x=config.x,y=config.y,z=config.z,radius=config.radius}
        station.col=createColSphere(config.x,config.y,config.z,config.radius)
        createBlip(config.x,config.y,config.z,51,2,255,255,255,255,0,350)
        stations[#stations+1]=station
    end
    F.recovered=recover()
    setTimer(tick,FuelConfig.tickMs,0)
end)
addEventHandler("onElementDestroy",root,function() if F.vehicles[source] then F.detach(source) end end)
addEventHandler("onVehicleExit",root,function(player,seat) if seat==0 then finish(source,true);visits[player]=nil end end)
addEventHandler("onPlayerQuit",root,function()
    for vehicle,session in pairs(F.sessions) do if session.player==source then finish(vehicle,true) end end
    visits[source],requests[source]=nil,nil
end)
addEventHandler("onResourceStop",resourceRoot,function()
    for vehicle in pairs(F.sessions) do finish(vehicle,true) end
    for _,state in pairs(F.vehicles) do persist(state) end
end)
-- Client element-data writes never feed consumption, payments or persistence.
addEventHandler("onElementDataChange",root,function(key)
    local state=F.vehicles[source]
    if client and state and (key=="car:fuel" or key=="car:fuelCapacity") then
        state.sent=nil;state.capacitySent=nil;publish(state)
    end
end)
