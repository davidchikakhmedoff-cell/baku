Fraction={members={},sessions={},invites={},cuffs={},vehicles={},markers={},blips={},cooldowns={},ready=false}
local F=Fraction
function F.now() return getRealTime().timestamp end
function F.account(p)
 if not F.ready or not FractionDB.available() or not isElement(p) or getElementType(p)~='player' or getElementData(p,'auth:loggedIn')~=true then return false end
 return tonumber(exports.rp_core:getAuthPlayerId(p))
end
function F.player(id) if F.ready and FractionDB.available() then return exports.rp_core:getPlayerByDynamicID(tonumber(id)) end end
function F.name(p) return getElementData(p,'rp:name') or getPlayerName(p) end
function F.notify(p,text,good)
 if isElement(p) and FractionDB.available() then exports.rp_core:sendCoreNotification(p,text,good and 103 or 239,good and 196 or 100,good and 216 or 100) end
end
function F.member(p) local id=F.account(p) or (F.sessions[p] and F.sessions[p].account);return id and F.members[id] end
function F.definition(p) local m=F.member(p);return m and Fractions[m.faction_id] end
function F.active(p,id,rank)
 local m=F.member(p);local f=m and Fractions[m.faction_id]
 return F.account(p) and m and (not id or m.faction_id==id) and m.rank>=(rank or 1) and not isPedDead(p) and not F.jailed(p)
  and (not f.duty or (F.sessions[p] and F.sessions[p].duty))
end
function F.near(a,b,distance)
 if not isElement(a) or not isElement(b) or getElementInterior(a)~=getElementInterior(b) or getElementDimension(a)~=getElementDimension(b) then return false end
 local x,y,z=getElementPosition(a);local xx,yy,zz=getElementPosition(b)
 return getDistanceBetweenPoints3D(x,y,z,xx,yy,zz)<=(distance or FractionConfig.proximity)
end
function F.throttle(p,action)
 local id=F.account(p);if not id then return false end
 F.cooldowns[p]=F.cooldowns[p] or {};local now=getTickCount();local last=F.cooldowns[p][action]
 if last and now-last<(FractionConfig.cooldown[action] or 1)*1000 then return false end
 F.cooldowns[p][action]=now;return true
end
function F.balance(id)
 local row=FractionDB.one('SELECT money FROM players WHERE id=?',id)
 for _,p in ipairs(getElementsByType('player')) do if F.account(p)==id and row then
  setPlayerMoney(p,tonumber(row.money) or 0)
  triggerClientEvent(p,'rp:hud:update',getResourceRootElement(getResourceFromName('rp_core')),{money=tonumber(row.money) or 0})
 end end
end
function F.charge(p,amount) return exports.rp_core:takeAuthPlayerMoney(p,amount)==true end
function F.credit(id,amount,key,kind)
 local changed=FractionDB.change('INSERT OR IGNORE INTO fraction_rewards(id,account_id,amount,kind) VALUES(?,?,?,?)',key,id,amount,kind or 'reward')
 if changed then F.balance(id) end;return changed
end
function F.reload(id)
 local m=FractionDB.one('SELECT * FROM fraction_members WHERE account_id=?',id)
 if m then for _,key in ipairs({'account_id','faction_id','rank','civilian_skin','salary_ms','salary_cycle','armory_at','duty','gear_issued'}) do m[key]=tonumber(m[key]) or 0 end end
 if m then
  local payouts=FractionDB.one("SELECT COUNT(*) AS n FROM fraction_rewards WHERE account_id=? AND kind='salary'",id)
  if payouts and m.salary_cycle<tonumber(payouts.n) then m.salary_cycle=tonumber(payouts.n);FractionDB.exec('UPDATE fraction_members SET salary_cycle=? WHERE account_id=?',m.salary_cycle,id) end
 end
 F.members[id]=m;return m
end
function F.workSkin(p,m)
 m=m or F.member(p);local f=m and Fractions[m.faction_id]
 if not f then return getElementModel(p) end
 if Wardrobe and Wardrobe.supports(m.faction_id) then return Wardrobe.resolve(p,m) end
 if f.femaleSkins then
  if not m.gender then
   local row=FractionDB.one('SELECT gender FROM players WHERE id=?',m.account_id)
   m.gender=row and row.gender=='female' and 'female' or 'male'
  end
  if m.gender=='female' then return f.femaleSkins[m.rank] end
 end
 return f.skins[m.rank]
end
function F.sync(p)
 local m=F.member(p);local f=m and Fractions[m.faction_id]
 setElementData(p,'rp:nametagColor',f and f.color or {255,255,255},true)
 setElementData(p,'rp:faction',f and f.name or false,true)
 if f and f.duty and not f.keepOwnSkin and F.sessions[p] and F.sessions[p].duty then setElementModel(p,F.workSkin(p,m)) end
 triggerClientEvent(p,'fraction:state',resourceRoot,m and {id=m.faction_id,rank=m.rank,duty=F.sessions[p] and F.sessions[p].duty or false} or false)
end
function F.snapshotWeapons(p)
 local result={};for slot=0,12 do local id=getPedWeapon(p,slot);local ammo=getPedTotalAmmo(p,slot)
  if id>0 and ammo>0 then result[#result+1]={id,ammo} end
 end;return toJSON(result,true)
end
function F.restoreWeapons(p,json)
 takeAllWeapons(p)
 for _,entry in ipairs(fromJSON(json or '[]') or {}) do if tonumber(entry[1]) and tonumber(entry[2]) then giveWeapon(p,entry[1],entry[2],false) end end
end
function getCivilianSkin(p)
 local m=F.member(p);local s=F.sessions[p]
 return m and Fractions[m.faction_id].category~="criminal" and not Fractions[m.faction_id].keepOwnSkin and ((s and s.duty) or m.duty==1) and m.civilian_skin or getElementModel(p)
end
function getCivilianWeapons(p)
    local m=F.member(p);local s=F.sessions[p]
    if not m or not ((s and s.duty) or m.duty==1 or m.gear_issued==1) then return false end
    local weapons={};for _,entry in ipairs(fromJSON(m.civilian_weapons or '[]') or {}) do weapons[#weapons+1]={weapon=entry[1],ammo=entry[2]} end
    return toJSON(weapons,true)
end
function F.endDuty(p)
 local m=F.member(p);local s=F.sessions[p]
 if s then s.uniformSkin=nil;s.wardrobe=nil end
 if F.returnVehicleKeys then F.returnVehicleKeys(p,true) end
 if not m then return end
 if (s and s.duty) or m.duty==1 or m.gear_issued==1 then
  if Fractions[m.faction_id].category~='criminal' and not Fractions[m.faction_id].keepOwnSkin then setElementModel(p,m.civilian_skin) end
  F.restoreWeapons(p,m.civilian_weapons)
  FractionDB.exec('UPDATE fraction_members SET duty=0,gear_issued=0 WHERE account_id=?',m.account_id);m.duty=0;m.gear_issued=0
 end
 if s then s.duty=false end
 F.clearCuffs(p,true);F.revokeDriver(p)
 F.sync(p)
end
function F.toggleDuty(p)
 local m=F.member(p);local f=m and Fractions[m.faction_id];if not f or not f.duty or F.jailed(p) then return end
 local marker=F.markers['duty:'..m.faction_id]
 if not marker or not F.near(p,marker,3) or isPedInVehicle(p) then return end
 local s=F.sessions[p];if not s then return end
 if s.duty then F.endDuty(p);F.notify(p,'Смена завершена',true)
 else
  m.civilian_skin=getElementModel(p);m.civilian_weapons=F.snapshotWeapons(p)
  if not FractionDB.change('UPDATE fraction_members SET duty=1,civilian_skin=?,civilian_weapons=? WHERE account_id=?',m.civilian_skin,m.civilian_weapons,m.account_id) then return end
  s.duty=true;m.duty=1;s.uniformSkin=nil;s.wardrobe=nil
  F.sync(p);F.notify(p,'Вы начали смену',true)
  if Wardrobe and Wardrobe.supports(m.faction_id) then Wardrobe.open(p) end
 end
end
function F.load(p)
 local id=F.account(p);if not id or not F.ready or F.sessions[p] then return end
 local m=F.reload(id)
 F.sessions[p]={account=id,duty=false,last=getTickCount(),weapons=false}
 if m and (m.duty==1 or m.gear_issued==1) then F.endDuty(p) end
 F.sync(p);F.repairInteriorPosition(p);F.applyJustice(p)
end
function F.disconnect(p,resourceStopping)
 F.clearCuffs(p,true)
 if F.keyMenus then F.keyMenus[p]=nil end
 local id=F.account(p) or (F.sessions[p] and F.sessions[p].account)
 if id then
  local state=F.justice[id]
  if state then FractionDB.exec('UPDATE fraction_state SET wanted=?,jail_remaining=? WHERE account_id=?',tonumber(state.wanted) or 0,tonumber(state.jail_remaining) or 0,id) end
  F.endDuty(p)
  local m=F.member(p)
  if m then
   FractionDB.exec('UPDATE fraction_members SET civilian_skin=? WHERE account_id=?',getElementModel(p),id)
  end
  if not resourceStopping then FractionDB.exec("DELETE FROM fraction_ads WHERE account_id=? AND status='pending'",id) end
 end
 F.sessions[p],F.invites[p],F.cooldowns[p]=nil,nil,nil
 if id then F.justice[id]=nil;F.members[id]=nil end
 for target,invite in pairs(F.invites) do if invite.inviter==p then F.invites[target]=nil end end
end
addEvent('auth:spawned',true)
addEventHandler('auth:spawned',root,function(p)
 if client and client~=p then return end
 if isElement(p) then F.load(p) end
end)
addEventHandler('onPlayerSpawn',root,function()
 local session=F.sessions[source]
 if session and session.duty then F.sync(source) end
 if session then F.applyJustice(source) end
end)
addEventHandler('onPlayerQuit',root,function() F.disconnect(source) end,true,'high+20')
addEventHandler('onElementDataChange',root,function(key)
 if key=='auth:loggedIn' and getElementType(source)=='player' and not getElementData(source,key) then F.disconnect(source) end
end)
function F.tryStart()
 if F.ready then return true end
 if not FractionDependencies.ready() then return false end
 for _,warning in ipairs(FractionFleetWarnings or {}) do outputDebugString('[Fraction] '..warning,2) end
 FractionDB.init();F.ready=true;F.createWorld();F.spawnFleet()
 local yakuza=Fractions[5]
 if yakuza then
  local entry=yakuza.entrance
  outputDebugString(string.format('[Fraction] Yakuza loaded: entrance=%.2f, %.2f, %.2f; rotation=%.0f; vehicles=%d',entry.x,entry.y,entry.z,entry.rotation or 0,#yakuza.vehicles),3)
 end
 for _,p in ipairs(getElementsByType('player')) do if F.account(p) then F.load(p) end end
 setTimer(F.tick,FractionConfig.tickMs,0)
 setTimer(function()
  for p in pairs(F.cuffs) do if isElement(p) then setPedWeaponSlot(p,0) end end
  for vehicle in pairs(F.vehicles) do local driver=isElement(vehicle) and getVehicleOccupant(vehicle,0);if driver then F.revokeDriver(driver) end end
 end,500,0)
 return true
end
addEventHandler('onResourceStart',resourceRoot,function()
 if F.tryStart() then return end
 local retry
 retry=setTimer(function() if F.tryStart() then killTimer(retry) end end,5000,0)
end)
addEventHandler('onResourceStop',resourceRoot,function()
 F.stopping=true
 for p in pairs(F.sessions) do if isElement(p) then F.disconnect(p,true) end end
 for _,p in ipairs(getElementsByType('player')) do setElementData(p,'rp:faction',false,true);setElementData(p,'rp:nametagColor',{255,255,255},true) end
 local cars=getResourceFromName('rp_car')
 if cars and FractionDependencies.hasExports('rp_car',{'unregisterFactionVehicle'}) then
  for vehicle in pairs(F.vehicles) do if isElement(vehicle) then exports.rp_car:unregisterFactionVehicle(vehicle) end end
 end
end)
