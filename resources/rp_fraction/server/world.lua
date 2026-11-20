local F=Fraction
F.vehicleByKey={}
local function marker(key,fid,kind,p,interior,dimension)
 local m
 if kind=='duty' then
  m=createPickup(p.x,p.y,p.z+FractionConfig.interactionIconZOffset,3,1275,1000)
 elseif kind=='armory' then
  m=createPickup(p.x,p.y,p.z+FractionConfig.interactionIconZOffset,3,FractionConfig.armoryPickupModel,1000)
 elseif kind=='keys' then
  m=createColSphere(p.x,p.y,p.z+FractionConfig.interactionIconZOffset,1)
 else
  m=createMarker(p.x,p.y,p.z+0.7,'arrow',0.9,255,220,0,205)
 end
 setElementInterior(m,interior);setElementDimension(m,dimension)
 F.markers[key]=m;setElementData(m,'fraction:marker',{id=fid,kind=kind},true)
 return m
end
local function teleport(p,pos,interior,dimension)
 if F.safeTeleport then return F.safeTeleport(p,pos,interior,dimension) end
 if isPedInVehicle(p) then return false end
 setElementInterior(p,interior);setElementDimension(p,dimension);setElementPosition(p,pos.x,pos.y,pos.z)
 setPedRotation(p,pos.rotation or 0);setCameraTarget(p,p);return true
end
function F.repairInteriorPosition(p)
 -- Migrate saved positions from the removed hospital shell and old News roof.
 local russian=Fractions[6]
 if getElementDimension(p)==russian.dimension and getElementInterior(p)~=russian.interior then
  teleport(p,russian.inside,russian.interior,russian.dimension)
  return
 end
 local mafia=Fractions[4]
 if getElementDimension(p)==mafia.dimension then
  local x,y=getElementPosition(p)
  -- Warehouse 1 shares interior ID 1 with TransFender at a different location.
  local oldWarehouse=getElementInterior(p)==1 and math.abs(x-1405.312)<40 and math.abs(y+8.2928)<40
  if getElementInterior(p)~=mafia.interior or oldWarehouse then
   teleport(p,mafia.inside,mafia.interior,mafia.dimension)
   return
  end
 end
 local hospital=Fractions[1]
 if getElementDimension(p)==hospital.dimension then
  local x,y=getElementPosition(p)
  if getElementInterior(p)~=hospital.interior or (math.abs(x-5000)<40 and math.abs(y-5000)<40) then
   teleport(p,hospital.inside,hospital.interior,hospital.dimension)
  end
  return
 end
 local f=Fractions[3]
 if getElementDimension(p)~=f.dimension or getElementInterior(p)~=f.interior then return end
 local x,y,z=getElementPosition(p)
 if math.abs(x-f.inside.x)<35 and math.abs(y-f.inside.y)<35 and z>f.inside.z+3 then
  teleport(p,f.inside,f.interior,f.dimension)
 end
end
function F.createWorld()
 for id,f in pairs(Fractions) do
  for _,vehicle in ipairs(f.vehicles) do if vehicle.helipad then
   local p=vehicle.p
   if vehicle.roofDeck then
    for ix=-1,1 do for iy=-1,1 do createObject(FractionConfig.roofDeckModel,p.x+ix*9,p.y+iy*9,p.z-2,0,0,0) end end
   end
   local landing=createObject(FractionConfig.helipadModel,p.x,p.y,p.z-1.3,0,0,0)
   if landing then setElementDoubleSided(landing,true) end
  end end
  if f.blip then
   local b=createBlip(f.entrance.x,f.entrance.y,f.entrance.z,f.blip.icon,f.blip.size,f.color[1],f.color[2],f.color[3],255,0,f.blip.visibleDistance or FractionConfig.blipVisibleDistance)
   if b then
    F.blips[id]=b;setElementInterior(b,0);setElementDimension(b,0)
    setElementData(b,'blip:name',f.name,true);setElementData(b,'fraction:blip',id,true)
   end
  end
  marker('enter:'..id,id,'enter',f.entrance,0,0)
  marker('exit:'..id,id,'exit',f.exit,f.interior,f.dimension)
  marker('keys:'..id,id,'keys',f.keysPoint,f.interior,f.dimension)
  if f.roof and f.roof.outside then
   marker('roof:'..id,id,'roof',f.roof.inside,f.interior,f.dimension)
   marker('roofBack:'..id,id,'roofBack',f.roof.outside,0,0)
   local back=f.roof.outside
   local zone=createColSphere(back.x,back.y,back.z,f.roof.triggerRadius or 0.9)
   setElementData(zone,'fraction:marker',{id=id,kind='roofBack'},false)
  end
  if f.garage then
   marker('garage:'..id,id,'garage',f.garage.inside,f.interior,f.dimension)
   marker('garageBack:'..id,id,'garageBack',f.garage.outside,0,0)
   local pos=f.garage.outside;local zone=createColSphere(pos.x,pos.y,pos.z,f.garage.triggerRadius or 0.9)
   setElementData(zone,'fraction:marker',{id=id,kind='garageBack'},false)
  end
  if f.duty then marker('duty:'..id,id,'duty',f.dutyPoint,f.interior,f.dimension) end
  if f.armory then marker('armory:'..id,id,'armory',f.armory,f.interior,f.dimension) end
 end
end
local recent=setmetatable({}, {__mode="k"})
local function markerHit(p,matching)
 if getElementData(p,'rp:transitionPending') then return end
 if not matching or not F.account(p) or isPedInVehicle(p) or F.jailed(p) or not F.near(p,source,3) then return end
 local info=getElementData(source,'fraction:marker');if not info then return end
 -- Arrow markers have their own collision volume. Apply the same small entry
 -- radius to both the visible marker and its auxiliary colshape.
 if info.kind=='garageBack' or info.kind=='roofBack' then
  local entrance=info.kind=='garageBack' and Fractions[info.id].garage or Fractions[info.id].roof
  local pos=entrance.outside
  local x,y,z=getElementPosition(p);local radius=entrance.triggerRadius or 0.9
  if (x-pos.x)^2+(y-pos.y)^2>radius^2 or math.abs(z-pos.z)>1.5 then return end
 end
 local now=getTickCount();if recent[p] and now-recent[p]<1500 then return end;recent[p]=now
 local f=Fractions[info.id];local m=F.member(p)
 if info.kind=='enter' then
  teleport(p,f.inside,f.interior,f.dimension)
 elseif info.kind=='exit' then teleport(p,f.outsideSpawn or f.entrance,0,0)
 elseif info.kind=='roofBack' then teleport(p,f.roof.returnSpawn or f.inside,f.interior,f.dimension)
 elseif info.kind=='garageBack' then teleport(p,f.garage.returnSpawn or f.inside,f.interior,f.dimension)
 elseif not m or m.faction_id~=info.id then F.notify(p,'Вы не состоите в этой фракции')
 elseif info.kind=='garage' then F.safeGarageTeleport(p,f.garage.arrival,0,0,f.garage.returnSpawn or f.inside)
 elseif info.kind=='roof' then
  local out=f.roof.outside
  teleport(p,f.roof.arrival or {x=out.x+3.5,y=out.y,z=out.z,rotation=180},0,0)
 elseif info.kind=='keys' then F.keysMenu(p)
 elseif info.kind=='duty' then triggerClientEvent(p,'fraction:menu',resourceRoot,'duty',{working=F.sessions[p] and F.sessions[p].duty or false,name=f.name,wardrobe=Wardrobe and Wardrobe.supports(info.id) or false})
 elseif info.kind=='armory' then
  if not F.active(p,f.id) then F.notify(p,'Начните смену');return end
  triggerClientEvent(p,'fraction:menu',resourceRoot,'armory',{weapons=f.weapons,rank=m.rank,name=f.name})
 end
end
addEventHandler('onMarkerHit',resourceRoot,markerHit)
addEventHandler('onColShapeHit',resourceRoot,markerHit)
addEventHandler('onPickupHit',resourceRoot,function(p,matching)
 local info=getElementData(source,'fraction:marker')
 if info and (info.kind=='duty' or info.kind=='armory') then cancelEvent();markerHit(p,matching~=false) end
end)
addEventHandler('onPickupUse',resourceRoot,function()
 if getElementData(source,'fraction:marker') then cancelEvent() end
end)
function F.armory(p,selection)
 local m=F.member(p);local f=m and Fractions[m.faction_id]
 if not f or not f.weapons or not F.active(p,f.id) or not F.near(p,F.markers['armory:'..f.id],3) then return end
 local chosen={}
 if selection~=nil then
  if type(selection)~='table' or #selection==0 or #selection>#f.weapons then return end
  for _,id in ipairs(selection) do
   local found=false
   for _,w in ipairs(f.weapons) do if id==w.id and m.rank>=w.rank then found=true end end
   if not found then F.notify(p,'Ваш ранг не позволяет получить это оружие');return end
   chosen[id]=true
  end
 else for _,w in ipairs(f.weapons) do chosen[w.id]=true end end
 if m.gear_issued~=1 then
  if m.duty~=1 then m.civilian_weapons=F.snapshotWeapons(p) end
  m.gear_issued=1
  FractionDB.exec('UPDATE fraction_members SET gear_issued=1,civilian_weapons=? WHERE account_id=?',m.civilian_weapons or '[]',m.account_id)
 end
 local issued={}
 for _,weapon in ipairs(f.weapons) do if chosen[weapon.id] and m.rank>=weapon.rank then
  local granted=false
  if weapon.armor then
   if getPedArmor(p)<weapon.armor then setPedArmor(p,weapon.armor);granted=true end
  else
   local slot=getSlotFromWeapon(weapon.id);local current=getPedWeapon(p,slot)
   local ammo=current==weapon.id and getPedTotalAmmo(p,slot) or 0
   if ammo<weapon.ammo then giveWeapon(p,weapon.id,weapon.ammo-ammo,false);granted=true end
  end
  if granted then issued[#issued+1]=weapon.name or getWeaponNameFromID(weapon.id) end
 end end
 triggerClientEvent(p,'fraction:closeArmory',resourceRoot)
 F.notify(p,#issued>0 and ('Вы взяли '..table.concat(issued,', ')..'.') or 'Выбранные предметы уже получены',true)
end
function canDriveFactionVehicle(p,v)
 local spec=F.vehicles[v]
 return spec and F.active(p,spec.faction,spec.rank) and not F.cuffs[p] and not F.jailed(p) and F.hasVehicleKey(p,spec.key) or false
end
local function canOccupyDriverSeat(p)
 return F.account(p) and not isPedDead(p) and not F.cuffs[p] and not F.jailed(p)
end
function F.revokeDriver(p)
 local v=getPedOccupiedVehicle(p)
 if v and F.vehicles[v] and getPedOccupiedVehicleSeat(p)==0 and not canOccupyDriverSeat(p) then
  setVehicleEngineState(v,false);removePedFromVehicle(p)
 end
end
local function spawnVehicle(fid,index)
 if FractionDependencies.blocked then return false end
 local f=Fractions[fid];local cfg=f.vehicles[index];local key='fraction:'..fid..':'..(cfg.slot or index)
 if F.missing[key] and getTickCount()<F.missing[key].at then return end
 for vehicle,spec in pairs(F.vehicles) do if spec.key==key then return end end
 local pos=cfg.p
 -- Never respawn into an occupied parking space; retry from the single fleet timer.
 for _,v in ipairs(getElementsByType('vehicle')) do
  local x,y,z=getElementPosition(v)
  if getElementDimension(v)==0 and getElementInterior(v)==0 and getDistanceBetweenPoints3D(x,y,z,pos.x,pos.y,pos.z)<3 then return end
 end
 local saved=FractionDB.one('SELECT fuel FROM fraction_vehicle_fuel WHERE vehicle_key=?',key)
 if not saved then FractionDB.exec('INSERT OR IGNORE INTO fraction_vehicle_fuel(vehicle_key,fuel) VALUES(?,30)',key);saved={fuel=30} end
 -- Detach the old car first; its final save must precede this refill.
 -- Startup loads retain stored fuel, parking returns and wreck replacements refill.
 if (F.returningVehicles and F.returningVehicles[key]) or F.missing[key] then
  local fuel=FractionConfig.vehicleReturnFuel
  if not FractionDB.exec('UPDATE fraction_vehicle_fuel SET fuel=? WHERE vehicle_key=?',fuel,key) then return false end
  saved={fuel=fuel}
 end
 local vehicle=createVehicle(cfg.model,pos.x,pos.y,pos.z,0,0,pos.rotation or 0)
 if not vehicle then return end
 F.vehicles[vehicle]={faction=fid,index=index,rank=cfg.rank,key=key}
 F.vehicleByKey[key]=vehicle
 setVehicleColor(vehicle,unpack(cfg.color or f.vehicleColor))
 setVehicleEngineState(vehicle,false);setVehicleLocked(vehicle,true)
 setVehicleDamageProof(vehicle,true);setElementData(vehicle,'fraction:issued',false,true)
 setElementData(vehicle,'fraction:vehicle',fid,true);setElementData(vehicle,'fraction:minRank',cfg.rank,true)
 local ok,registered=pcall(function() return exports.rp_car:registerFactionVehicle(vehicle,key,tonumber(saved.fuel)) end)
 if not ok or registered~=true then
  F.vehicles[vehicle]=nil;F.vehicleByKey[key]=nil;destroyElement(vehicle);FractionDependencies.rejectVehicleAdapter()
  return false
 end
end
F.spawnFleetSlot=spawnVehicle
function F.retireFleetVehicle(vehicle)
 local spec=F.vehicles[vehicle];if not spec then return end
 exports.rp_car:unregisterFactionVehicle(vehicle)
 F.vehicles[vehicle]=nil;F.vehicleByKey[spec.key]=nil;destroyElement(vehicle)
end
F.missing={}
function F.spawnFleet()
 if not FractionDependencies.ready() then return end
 for fid,f in pairs(Fractions) do for index in ipairs(f.vehicles) do
  if spawnVehicle(fid,index)==false then return end
 end end
end
addEventHandler('onVehicleStartEnter',root,function(p,seat)
 local spec=F.vehicles[source]
 if spec and seat==0 and (isVehicleLocked(source) or not canOccupyDriverSeat(p)) then
  cancelEvent()
 end
end,true,'high+10')
addEventHandler('onVehicleEnter',root,function(p,seat) if seat==0 then F.revokeDriver(p) end end)
addEventHandler('onVehicleExplode',root,function()
 local spec=F.vehicles[source];if spec then
  if spec.destroyAt then return end
  spec.destroyAt=getTickCount()+FractionConfig.vehicleRespawnMs
  setTimer(function(vehicle,expected)
   local current=F.vehicles[vehicle]
   if current and current.destroyAt==expected and not F.stopping then F.fleetTick() end
  end,FractionConfig.vehicleRespawnMs,1,source,spec.destroyAt)
  F.missing[spec.key]={faction=spec.faction,index=spec.index,at=spec.destroyAt}
  if F.vehicleKeysLost then F.vehicleKeysLost(spec.key) end
 end
end)
addEventHandler('onElementDestroy',root,function()
 local spec=F.vehicles[source];if not spec then return end
 F.missing[spec.key]={faction=spec.faction,index=spec.index,at=getTickCount()+FractionConfig.vehicleRespawnMs};F.vehicles[source]=nil;F.vehicleByKey[spec.key]=nil
 if F.vehicleKeysLost then F.vehicleKeysLost(spec.key) end
end)
function F.fleetTick()
 if not FractionDependencies.ready() then return end
 if F.vehicleKeysTick then F.vehicleKeysTick() end
 for v,spec in pairs(F.vehicles) do
  if spec.destroyAt and getTickCount()>=spec.destroyAt then
   if F.evacuateFleetVehicle then F.evacuateFleetVehicle(v,spec.faction) end
   F.retireFleetVehicle(v)
  end
 end
 for key,spec in pairs(F.missing) do if getTickCount()>=spec.at then spawnVehicle(spec.faction,spec.index) end end
 for v,spec in pairs(F.vehicles) do if not spec.destroyAt then F.missing[spec.key]=nil end end
 -- Covers missing slots at startup and seat changes/warps that bypass StartEnter.
 F.spawnFleet()
 for _,p in ipairs(getElementsByType('player')) do F.revokeDriver(p) end
end
