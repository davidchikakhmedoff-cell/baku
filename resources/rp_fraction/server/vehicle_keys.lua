local F=Fraction
F.keyHolders={};F.playerKeys={};F.keyMenus={};F.returningVehicles={}
function F.setFleetIssued(vehicle,issued)
 if not isElement(vehicle) then return end
 setVehicleDamageProof(vehicle,not issued)
 setElementData(vehicle,'fraction:issued',issued==true,true)
 if not issued then fixVehicle(vehicle) end
end
local function keyFor(fid,slot) return 'fraction:'..fid..':'..slot end
local function holderName(holder)
 return holder and isElement(holder.player) and F.name(holder.player) or 'Игрок вышел'
end
local function configuration(fid,slot)
 for index,cfg in ipairs(Fractions[fid].vehicles) do if cfg.slot==slot then return cfg,index end end
end
local function atKeys(p)
 local m=F.member(p)
 return m and F.active(p,m.faction_id) and not isPedInVehicle(p) and F.near(p,F.markers['keys:'..m.faction_id],3)
end
function F.hasVehicleKey(p,key)
 local holder=F.keyHolders[key]
 return holder and holder.player==p and holder.account==F.account(p) and F.playerKeys[p]==key or false
end
local function vehicleName(cfg)
 local custom=FractionCarConfig and FractionCarConfig.models[cfg.model]
 return custom and custom.name or getVehicleNameFromModel(cfg.model) or tostring(cfg.model)
end
function F.keysMenu(p)
 if not atKeys(p) then F.notify(p,'Начните смену и подойдите к маркеру ключей');return end
 local m=F.member(p);local rows={}
 for _,cfg in ipairs(Fractions[m.faction_id].vehicles) do
  local key=keyFor(m.faction_id,cfg.slot);local holder=F.keyHolders[key]
  local vehicle=F.vehicleByKey[key];local spec=vehicle and F.vehicles[vehicle]
  rows[#rows+1]={slot=cfg.slot,name=vehicleName(cfg)..' №'..cfg.slot,rank=cfg.rank,
   holder=holder and holderName(holder) or false,mine=F.hasVehicleKey(p,key),
   available=vehicle and isElement(vehicle) and spec and not spec.destroyAt and not F.returningVehicles[key] or false}
 end
 F.keyMenus[p]=m.faction_id
 triggerClientEvent(p,'fraction:menu',resourceRoot,'keys',{rows=rows,name=Fractions[m.faction_id].name,hasKey=F.playerKeys[p]~=nil})
end
function F.refreshKeyMenus(fid)
 for p,id in pairs(F.keyMenus) do if not fid or id==fid then
  if isElement(p) and atKeys(p) then F.keysMenu(p)
  else F.keyMenus[p]=nil;if isElement(p) then triggerClientEvent(p,'fraction:closeKeys',resourceRoot) end end
 end end
end
function F.takeVehicleKeys(p,slot)
 if not atKeys(p) then F.notify(p,'Получить ключи можно только у маркера своей фракции на смене');return end
 slot=FractionRules.integer(slot,1,2147483647);if not slot then return end
 local m=F.member(p);local cfg,index=configuration(m.faction_id,slot)
 if not cfg then return end
 local key=keyFor(m.faction_id,slot)
 if F.playerKeys[p] then F.notify(p,'Сначала сдайте ключи от предыдущего транспорта');return end
 if m.rank<cfg.rank then F.notify(p,'Для этого транспорта требуется '..cfg.rank..' ранг');return end
 if F.cuffs[p] then F.notify(p,'Нельзя получить ключи в наручниках');return end
 if F.keyHolders[key] then F.notify(p,'Ключи уже у '..holderName(F.keyHolders[key]));F.keysMenu(p);return end
 local v=F.vehicleByKey[key];local spec=v and F.vehicles[v]
 if not isElement(v) or not spec or spec.destroyAt or F.returningVehicles[key] then F.notify(p,'Транспорт пока недоступен или возвращается на парковку');return end
 F.keyHolders[key]={player=p,account=F.account(p),faction=m.faction_id,index=index}
 F.playerKeys[p]=key
 F.setFleetIssued(v,true)
 F.notify(p,'Вы взяли ключи от '..vehicleName(cfg)..'.',true)
 F.keyMenus[p]=nil;triggerClientEvent(p,'fraction:closeKeys',resourceRoot)
 F.refreshKeyMenus(m.faction_id)
end
local function release(p,key)
 local holder=F.keyHolders[key]
 F.playerKeys[p]=nil;F.keyHolders[key]=nil
 return holder
end
function F.evacuateFleetVehicle(v,fid)
 -- Remove occupants before retiring the car; keep their current world/interior.
 for _,passenger in pairs(getVehicleOccupants(v)) do
  removePedFromVehicle(passenger)
  if not isPedDead(passenger) then
   F.notify(passenger,'Служебный транспорт возвращён на парковку. Вы высажены на месте.')
  end
 end
end
function F.processVehicleReturns()
 if F.stopping or not FractionDependencies.ready() then return end
 for key,state in pairs(F.returningVehicles) do
  if not state.retired then
   local v=F.vehicleByKey[key]
   if not isElement(v) then state.retired=true
   else
    F.evacuateFleetVehicle(v,state.faction)
    setVehicleEngineState(v,false);setVehicleLocked(v,true);setElementFrozen(v,true)
    F.retireFleetVehicle(v);state.retired=true
   end
  end
  if state.retired then
   F.missing[key]=nil
   F.spawnFleetSlot(state.faction,state.index)
   if F.vehicleByKey[key] then F.returningVehicles[key]=nil end
  end
 end
end
function F.returnVehicleKeys(p,automatic)
 local key=F.playerKeys[p];if not key then return false end
 if not automatic and not atKeys(p) then F.notify(p,'Сдать ключи можно у маркера своей фракции');return false end
 local holder=release(p,key);if not holder then return false end
 F.keyMenus[p]=nil
 if not F.stopping then
  F.returningVehicles[key]={faction=holder.faction,index=holder.index,retired=false}
  F.processVehicleReturns()
  F.refreshKeyMenus(holder.faction)
  if not automatic then
   local cfg=Fractions[holder.faction].vehicles[holder.index]
   F.notify(p,'Ключи от '..vehicleName(cfg)..' сданы',true);F.keysMenu(p)
  end
 end
 return true
end
function F.vehicleKeysLost(key)
 local holder=F.keyHolders[key]
 if holder then
  release(holder.player,key)
  F.notify(holder.player,'Служебный транспорт уничтожен. Ключи сданы автоматически')
 end
 F.returningVehicles[key]=nil
 if holder then F.refreshKeyMenus(holder.faction) end
end
function F.vehicleKeysTick()
 for key,holder in pairs(F.keyHolders) do
  local v=F.vehicleByKey[key];local spec=v and F.vehicles[v]
  if not isElement(holder.player) or F.account(holder.player)~=holder.account or not spec or not F.active(holder.player,holder.faction,spec.rank) then F.returnVehicleKeys(holder.player,true) end
 end
 F.processVehicleReturns();F.refreshKeyMenus()
end

addEventHandler('onVehicleDamage',root,function()
 local spec=F.vehicles[source]
 if spec and not spec.destroyAt and not F.keyHolders[spec.key] and getElementHealth(source)>0 then F.setFleetIssued(source,false) end
end)
addEventHandler('onElementDataChange',root,function(key)
 local spec=F.vehicles[source]
 if client and spec and key=='fraction:issued' then
  local expected=F.keyHolders[spec.key]~=nil
  if getElementData(source,key)~=expected then setElementData(source,key,expected,true) end
 end
end)
