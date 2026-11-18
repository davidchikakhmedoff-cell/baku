local F=Fraction
local function marker(key,fid,kind,p,interior,dimension)
 local m=createMarker(p.x,p.y,p.z+0.7,'arrow',0.9,255,220,0,205)
 setElementInterior(m,interior);setElementDimension(m,dimension)
 F.markers[key]=m;setElementData(m,'fraction:marker',{id=fid,kind=kind},true)
 return m
end
local function teleport(p,pos,interior,dimension)
 if isPedInVehicle(p) then return false end
 setElementInterior(p,interior);setElementDimension(p,dimension);setElementPosition(p,pos.x,pos.y,pos.z)
 setPedRotation(p,pos.rotation or 0);setCameraTarget(p,p);return true
end
function F.createWorld()
 local hospital=Fractions[1]
 local function object(model,x,y,z,rx,ry,rz,f)
  local o=createObject(model,x,y,z,rx or 0,ry or 0,rz or 0)
  if o then setElementInterior(o,f.interior);setElementDimension(o,f.dimension) end
  return o
 end
 if hospital.customHospital then
  local room=FractionConfig.hospitalRoom
  local cx,cy,cz=unpack(room.center);local tile=room.tile;local wall=tile*1.5
  for ix=-1,1 do for iy=-1,1 do object(room.floorModel,cx+ix*tile,cy+iy*tile,cz,0,0,0,hospital) end end
  for i=-1,1 do
   object(room.floorModel,cx+i*tile,cy-wall,cz+tile/2,90,0,0,hospital)
   object(room.floorModel,cx+i*tile,cy+wall,cz+tile/2,90,0,0,hospital)
   object(room.floorModel,cx-wall,cy+i*tile,cz+tile/2,0,90,0,hospital)
   object(room.floorModel,cx+wall,cy+i*tile,cz+tile/2,0,90,0,hospital)
  end
  for _,item in ipairs(room.furniture) do object(item[1],item[2],item[3],item[4],0,0,item[5],hospital) end
 end
 local helipad=hospital.vehicles[3].p
 local landing=createObject(FractionConfig.helipadModel,helipad.x,helipad.y,helipad.z-1.3,0,0,0)
 if landing then setElementDoubleSided(landing,true) end
 for id,f in pairs(Fractions) do
  marker('enter:'..id,id,'enter',f.entrance,0,0)
  marker('exit:'..id,id,'exit',f.exit,f.interior,f.dimension)
  marker('desk:'..id,id,'desk',f.desk,f.interior,f.dimension)
  if f.duty then marker('duty:'..id,id,'duty',f.dutyPoint,f.interior,f.dimension) end
  if f.armory then marker('armory:'..id,id,'armory',f.armory,f.interior,f.dimension) end
 end
end
local recent=setmetatable({}, {__mode="k"})
addEventHandler('onMarkerHit',resourceRoot,function(p,matching)
 if not matching or not F.account(p) or isPedInVehicle(p) or F.jailed(p) or not F.near(p,source,3) then return end
 local info=getElementData(source,'fraction:marker');if not info then return end
 local now=getTickCount();if recent[p] and now-recent[p]<1500 then return end;recent[p]=now
 local f=Fractions[info.id];local m=F.member(p)
 if info.kind=='enter' then
  if info.id>=4 and (not m or m.faction_id~=info.id) then F.notify(p,'Вход доступен только участникам фракции');return end
  teleport(p,f.inside,f.interior,f.dimension)
 elseif info.kind=='exit' then teleport(p,f.entrance,0,0)
 elseif not m or m.faction_id~=info.id then F.notify(p,'Вы не состоите в этой фракции')
 elseif info.kind=='duty' then triggerClientEvent(p,'fraction:menu',resourceRoot,'duty',{working=F.sessions[p] and F.sessions[p].duty or false,name=f.name})
 elseif info.kind=='armory' then
  if not F.active(p,f.id) then F.notify(p,'Начните смену');return end
  triggerClientEvent(p,'fraction:menu',resourceRoot,'armory',{weapons=f.weapons,rank=m.rank,name=f.name})
 elseif info.kind=='desk' then F.membersMenu(p) end
end)
function F.armory(p)
 local m=F.member(p);local f=m and Fractions[m.faction_id]
 if not f or not f.weapons or not F.active(p,f.id) or not F.near(p,F.markers['armory:'..f.id],3) then return end
 if F.now()<m.armory_at then F.notify(p,'Следующий комплект доступен через '..(m.armory_at-F.now())..' сек.');return end
 if not FractionDB.change('UPDATE fraction_members SET armory_at=? WHERE account_id=? AND armory_at<=?',F.now()+FractionConfig.armoryCooldown,m.account_id,F.now()) then return end
 m.armory_at=F.now()+FractionConfig.armoryCooldown
 if m.gear_issued~=1 then
  if m.duty~=1 then m.civilian_weapons=F.snapshotWeapons(p) end
  m.gear_issued=1
  FractionDB.exec('UPDATE fraction_members SET gear_issued=1,civilian_weapons=? WHERE account_id=?',m.civilian_weapons or '[]',m.account_id)
 end
 for _,weapon in ipairs(f.weapons) do if m.rank>=weapon.rank then
  local slot=getSlotFromWeapon(weapon.id);local current=getPedWeapon(p,slot)
  local ammo=current==weapon.id and getPedTotalAmmo(p,slot) or 0
  if ammo<weapon.ammo then giveWeapon(p,weapon.id,weapon.ammo-ammo,false) end
 end end
 F.notify(p,'Комплект получен. Повторная выдача ограничена по времени',true)
end
function canDriveFactionVehicle(p,v)
 local spec=F.vehicles[v]
 return spec and F.active(p,spec.faction,spec.rank) and not F.cuffs[p] and not F.jailed(p) or false
end
function F.revokeDriver(p)
 local v=getPedOccupiedVehicle(p)
 if v and F.vehicles[v] and getPedOccupiedVehicleSeat(p)==0 and not canDriveFactionVehicle(p,v) then
  setVehicleEngineState(v,false);removePedFromVehicle(p)
 end
end
local function spawnVehicle(fid,index)
 local f=Fractions[fid];local cfg=f.vehicles[index];local key='fraction:'..fid..':'..index
 if F.missing[key] and getTickCount()<F.missing[key].at then return end
 for vehicle,spec in pairs(F.vehicles) do if spec.key==key then return end end
 local pos=cfg.p
 -- Never respawn into an occupied parking space; retry from the single fleet timer.
 for _,v in ipairs(getElementsByType('vehicle')) do
  local x,y,z=getElementPosition(v)
  if getElementDimension(v)==0 and getElementInterior(v)==0 and getDistanceBetweenPoints3D(x,y,z,pos.x,pos.y,pos.z)<3 then return end
 end
 local vehicle=createVehicle(cfg.model,pos.x,pos.y,pos.z,0,0,pos.rotation or 0)
 if not vehicle then return end
 F.vehicles[vehicle]={faction=fid,index=index,rank=cfg.rank,key=key}
 setVehicleColor(vehicle,unpack(f.vehicleColor))
 setVehicleEngineState(vehicle,false);setVehicleLocked(vehicle,false)
 setElementData(vehicle,'fraction:vehicle',fid,true);setElementData(vehicle,'fraction:minRank',cfg.rank,true)
 local saved=FractionDB.one('SELECT fuel FROM fraction_vehicle_fuel WHERE vehicle_key=?',key)
 if not saved then FractionDB.exec('INSERT OR IGNORE INTO fraction_vehicle_fuel(vehicle_key,fuel) VALUES(?,30)',key);saved={fuel=30} end
 if not exports.rp_car:registerFactionVehicle(vehicle,key,tonumber(saved.fuel)) then
  F.vehicles[vehicle]=nil;destroyElement(vehicle);outputDebugString('[Fraction] rp_car adapter unavailable',1)
 end
end
F.missing={}
function F.spawnFleet()
 for fid,f in pairs(Fractions) do for index in ipairs(f.vehicles) do spawnVehicle(fid,index) end end
end
addEventHandler('onVehicleStartEnter',root,function(p,seat)
 local spec=F.vehicles[source]
 if spec and seat==0 and not canDriveFactionVehicle(p,source) then
  cancelEvent();F.notify(p,'Для управления требуется '..spec.rank..' ранг '..Fractions[spec.faction].name..' и рабочий статус')
 end
end,true,'high+10')
addEventHandler('onVehicleEnter',root,function(p,seat) if seat==0 then F.revokeDriver(p) end end)
addEventHandler('onVehicleExplode',root,function()
 local spec=F.vehicles[source];if spec then
  spec.destroyAt=getTickCount()+FractionConfig.vehicleRespawnMs
  F.missing[spec.key]={faction=spec.faction,index=spec.index,at=spec.destroyAt}
 end
end)
addEventHandler('onElementDestroy',root,function()
 local spec=F.vehicles[source];if not spec then return end
 F.missing[spec.key]={faction=spec.faction,index=spec.index,at=getTickCount()+FractionConfig.vehicleRespawnMs};F.vehicles[source]=nil
end)
function F.fleetTick()
 for v,spec in pairs(F.vehicles) do
  if spec.destroyAt and getTickCount()>=spec.destroyAt then
   local occupied=false;for _ in pairs(getVehicleOccupants(v)) do occupied=true end
   if not occupied then exports.rp_car:unregisterFactionVehicle(v);F.vehicles[v]=nil;destroyElement(v) end
  end
 end
 for key,spec in pairs(F.missing) do if getTickCount()>=spec.at then spawnVehicle(spec.faction,spec.index) end end
 for v,spec in pairs(F.vehicles) do if not spec.destroyAt then F.missing[spec.key]=nil end end
 -- Covers missing slots at startup and seat changes/warps that bypass StartEnter.
 F.spawnFleet()
 for _,p in ipairs(getElementsByType('player')) do F.revokeDriver(p) end
end
