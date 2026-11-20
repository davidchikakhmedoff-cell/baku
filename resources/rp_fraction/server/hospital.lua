local F=Fraction
local offsets={{0,0},{0.95,0},{0.67175,0.67175},{0,0.95},{-0.67175,0.67175},{-0.95,0},{-0.67175,-0.67175},{0,-0.95},{0.67175,-0.67175}}
local function available(p)
 local f=Fractions[1]
 return F.account(p) and not getElementData(p,'rp:transitionPending') and not isPedDead(p) and not isPedInVehicle(p) and not F.jailed(p)
  and getElementInterior(p)==f.interior and getElementDimension(p)==f.dimension
  and F.near(p,F.markers['selfHeal:1'],2)
end
function F.hasHospitalDoctors(patient)
 for _,p in ipairs(getElementsByType('player')) do if p~=patient and F.active(p,1) then return true end end
 return false
end
function F.openSelfHeal(p)
 if not available(p) then F.notify(p,'Встаньте в маркер самолечения и дождитесь завершения перехода');return end
 if F.hasHospitalDoctors(p) then F.notify(p,'В больнице есть врачи на смене. Обратитесь к врачу');return end
 if getElementHealth(p)>=100 then F.notify(p,'Вы не нуждаетесь в лечении');return end
 triggerClientEvent(p,'fraction:menu',resourceRoot,'selfHeal',{price=FractionConfig.selfHealPrice})
end
function F.selfHeal(p)
 if not available(p) then F.notify(p,'Встаньте в маркер самолечения и дождитесь завершения перехода');return end
 if not F.throttle(p,'selfHeal') then F.notify(p,'Подождите перед повторным лечением');return end
 if F.hasHospitalDoctors(p) then F.notify(p,'В больнице есть врачи на смене. Обратитесь к врачу');return end
 if getElementHealth(p)>=100 then F.notify(p,'Вы не нуждаетесь в лечении');return end
 if not F.charge(p,FractionConfig.selfHealPrice) then F.notify(p,'Недостаточно денег для самолечения');return end
 setElementHealth(p,100)
 triggerClientEvent(p,'fraction:healthSync',resourceRoot,100)
 exports.rp_core:updatePlayerHUD(p)
 triggerClientEvent(p,'fraction:closeSelfHeal',resourceRoot)
 F.notify(p,'Вы вылечились. Списано $'..FractionConfig.selfHealPrice,true)
end
function getHospitalRespawnLocation(p)
 if not F.ready or not F.account(p) then return false end
 local f=Fractions[1];local center=f.respawnPoint
 if not center then return false end
 local first=math.random(#offsets);local best,clearance
 for step=0,#offsets-1 do
  local offset=offsets[(first+step-1)%#offsets+1]
  local pos={x=center.x+offset[1],y=center.y+offset[2],z=center.z,rotation=center.rotation or 0,
   interior=f.interior,dimension=f.dimension,health=20}
  local nearest=math.huge
  for _,other in ipairs(getElementsByType('player')) do
   if other~=p and not isPedDead(other) and getElementInterior(other)==f.interior and getElementDimension(other)==f.dimension then
    local x,y,z=getElementPosition(other)
    if math.abs(z-pos.z)<2 then nearest=math.min(nearest,(x-pos.x)^2+(y-pos.y)^2) end
   end
  end
  if not clearance or nearest>clearance then best,clearance=pos,nearest end
  if nearest>=0.65^2 then return pos end
 end
 return best
end
function completeHospitalRespawn(p)
 if not F.ready or not F.account(p) or isPedDead(p) then return false end
 local f=Fractions[1];if not f.respawnPoint or not F.safeTeleport then return false end
 local x,y,z=getElementPosition(p)
 if getElementInterior(p)~=f.interior or getElementDimension(p)~=f.dimension
  or (x-f.respawnPoint.x)^2+(y-f.respawnPoint.y)^2>4 or math.abs(z-f.respawnPoint.z)>1 then return false end
 local out=f.outsideSpawn
 return F.safeTeleport(p,{x=x,y=y,z=z,rotation=f.respawnPoint.rotation or 180},f.interior,f.dimension,
  {x=out.x,y=out.y,z=out.z,rotation=out.rotation or 0,interior=0,dimension=0},function(player)
   -- spawnPlayer/skin/streaming initialization can restore 100 HP on the client.
   -- Commit after its collision-ready acknowledgement, never on a late timer
   -- that could undo an already completed treatment.
   if F.account(player) and not isPedDead(player) and not F.jailed(player) then
    setElementHealth(player,20)
    triggerClientEvent(player,'fraction:healthSync',resourceRoot,20)
    exports.rp_core:updatePlayerHUD(player)
   end
  end)
end
