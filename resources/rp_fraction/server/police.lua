local F=Fraction
F.justice={}
function F.state(p)
 local id=F.account(p);if not id then return false end
 if not F.justice[id] then
  FractionDB.exec('INSERT OR IGNORE INTO fraction_state(account_id) VALUES(?)',id)
  F.justice[id]=FractionDB.one('SELECT * FROM fraction_state WHERE account_id=?',id)
 end
 return F.justice[id]
end
function F.jailed(p) local s=F.state(p);return s and tonumber(s.jail_remaining)>0 or false end
local cuffControls=FractionConfig.cuffControls
function F.clearCuffs(p,issuerLeaving)
 local state=F.cuffs[p]
 if state then
  for name,enabled in pairs(state.controls) do if isElement(p) and not getElementData(p,'admin:frozen') then toggleControl(p,name,enabled) end end
  if isElement(p) then setPedAnimation(p,false) end
  F.cuffs[p]=nil
  if isElement(p) then setElementData(p,'fraction:cuffed',false,true);triggerClientEvent(p,'fraction:cuff',resourceRoot,false,state.controls) end
 end
 if issuerLeaving then
  local clear={};for target,cuff in pairs(F.cuffs) do if cuff.issuer==p then clear[#clear+1]=target end end
  for _,target in ipairs(clear) do F.clearCuffs(target) end
 end
end
local function policeTarget(p,id,action,rank)
 if not F.active(p,2,rank or 2) then F.notify(p,'Нужен '..(rank or 2)..' ранг LSPD и активная смена. В КПЗ полицейские действия недоступны');return end
 local target=F.player(id)
 if not F.account(target) or isPedDead(target) or not F.near(p,target) then F.notify(p,'Игрок должен находиться рядом и быть жив');return end
 if not F.throttle(p,action) then F.notify(p,'Подождите перед повторным использованием команды');return end
 return target
end
local function wanted(p,value)
 local s=F.state(p);if not s then return end
 value=math.max(0,math.min(6,value));s.wanted=value
 FractionDB.exec('UPDATE fraction_state SET wanted=? WHERE account_id=?',value,F.account(p));setPlayerWantedLevel(p,value)
end
addCommandHandler('ticket',function(p,_,id,amount,...)
 amount=FractionRules.integer(amount,FractionConfig.ticket.min,FractionConfig.ticket.max)
 local reason=FractionRules.text(table.concat({...},' '))
 if not amount or not reason then F.notify(p,'/ticket ID сумма причина — сумма от $'..FractionConfig.ticket.min..' до $'..FractionConfig.ticket.max);return end
 local target=policeTarget(p,id,'ticket',FractionConfig.ticket.rank)
 if not target then return end
 if not FractionDB.exec('INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(?,?,?,?,?)',F.account(target),F.account(p),amount,reason,F.now()) then
  F.notify(p,'Не удалось сохранить штраф');return
 end
 local ticket=FractionDB.one('SELECT id FROM fraction_tickets WHERE id=last_insert_rowid() AND account_id=? AND officer_id=?',F.account(target),F.account(p))
 if not ticket then F.notify(p,'Не удалось получить номер штрафа. Проверьте /tickets');return end
 F.notify(target,'Выписан штраф $'..amount..': '..reason..'. Неоплаченные штрафы: /tickets')
 if p~=target then F.notify(p,'Штраф выписан',true) end
 triggerClientEvent(target,'fraction:menu',resourceRoot,'ticket',{id=tonumber(ticket.id),amount=amount,reason=reason})
end)

function F.tickets(p)
 if not F.account(p) then return end
 triggerClientEvent(p,'fraction:menu',resourceRoot,'tickets',{rows=FractionDB.query('SELECT * FROM fraction_tickets WHERE account_id=? AND paid=0 ORDER BY id',F.account(p))})
end
function F.payTicket(p,id)
 id=FractionRules.integer(id,1,2147483647);if not id or not F.account(p) then return end
 local row=FractionDB.one('SELECT * FROM fraction_tickets WHERE id=? AND account_id=? AND paid=0',id,F.account(p))
 if not row or exports.rp_core:getAuthPlayerBalance(p)<tonumber(row.amount) then F.notify(p,'Штраф не найден или недостаточно средств');return end
 if FractionDB.change('UPDATE fraction_tickets SET paid=1 WHERE id=? AND account_id=? AND paid=0',id,F.account(p)) then
  F.balance(F.account(p));F.notify(p,'Штраф оплачен',true)
  triggerClientEvent(p,'fraction:ticketPaid',resourceRoot,id)
  local officer=tonumber(row.officer_id)
  if officer~=F.account(p) then
   F.balance(officer)
   for _,online in ipairs(getElementsByType('player')) do if F.account(online)==officer then
    local reward=math.floor(tonumber(row.amount)*FractionConfig.ticket.officerPercent/100)
    F.notify(online,'Штраф оплачен. Вы получили $'..reward,true)
   end end
  end
 end
end
addCommandHandler('tickets',F.tickets)
addCommandHandler('payticket',function(p,_,id) F.payTicket(p,id) end)
addCommandHandler('su',function(p,_,id,level,...)
 local target=policeTarget(p,id,'su',2);level=FractionRules.integer(level,1,6)
 local reason=FractionRules.text(table.concat({...},' '));if not target or not level or not reason then return end
 wanted(target,math.min(6,getPlayerWantedLevel(target)+level));F.notify(target,'Вы объявлены в розыск: '..reason)
 local color=FractionConfig.wantedNoticeColor
 local name=F.name(target):gsub('#%x%x%x%x%x%x','')
 local message='Внимание всем постам! Объявлен в розыск '..name..'. Уровень розыска - '..getPlayerWantedLevel(target)..'. Причина: '..reason
 if not message:find('[.!?]$') then message=message..'.' end
 for _,other in ipairs(getElementsByType('player')) do
  local member=F.account(other) and F.member(other)
  if member and member.faction_id==2 then exports.rp_core:sendCoreChatMessage(other,message,color[1],color[2],color[3]) end
 end
end)
addCommandHandler('clearwanted',function(p,_,id)
 local target=policeTarget(p,id,'su',9);if not target then return end
 wanted(target,0);F.notify(target,'Розыск снят',true)
end)
addCommandHandler('cuff',function(p,_,id)
 local target=policeTarget(p,id,'cuff',2);if not target or F.jailed(target) or isPedInVehicle(target) then return end
 if F.cuffs[target] then F.clearCuffs(target);F.notify(target,'Наручники сняты',true)
 else
  local controls={};for _,control in ipairs(cuffControls) do controls[control]=isControlEnabled(target,control);toggleControl(target,control,false) end
  F.cuffs[target]={issuer=p,controls=controls};setPedWeaponSlot(target,0);setElementData(target,'fraction:cuffed',true,true)
  setPedAnimation(target,'POLICE','crm_drgbst_01',-1,true,false,true,false)
  triggerClientEvent(target,'fraction:cuff',resourceRoot,true,controls);F.notify(target,'На вас надеты наручники')
 end
end)
addCommandHandler('uncuff',function(p,_,id)
 local target=policeTarget(p,id,'uncuff',2)
 if not target then return end
 if not F.cuffs[target] then F.notify(p,'На игроке нет наручников');return end
 F.clearCuffs(target);F.notify(target,'Наручники сняты',true)
 if p~=target then F.notify(p,'Вы сняли наручники с игрока',true) end
end)
function F.applyJail(p,spawn)
 local s=F.state(p);if not s or tonumber(s.jail_remaining)<=0 then return false end
 local cell=FractionConfig.jailCells[(F.account(p)%#FractionConfig.jailCells)+1]
 if isPedInVehicle(p) then removePedFromVehicle(p) end
 if spawn and isPedDead(p) then spawnPlayer(p,cell.x,cell.y,cell.z,0,getCivilianSkin(p),6,FractionConfig.dimensionBase+100) end
 setElementInterior(p,6);setElementDimension(p,FractionConfig.dimensionBase+100);setElementPosition(p,cell.x,cell.y,cell.z)
 setCameraTarget(p,p);takeAllWeapons(p);wanted(p,0)
 return true
end
function applyFactionJail(p) return F.applyJail(p,true) end
function F.applyJustice(p)
 local s=F.state(p);if not s then return end
 if not F.applyJail(p,false) then setPlayerWantedLevel(p,tonumber(s.wanted) or 0) end
end
function F.arrest(target,minutes,reason,keepDuty)
 local s=F.state(target);if not s or tonumber(s.jail_remaining)>0 then return false end
 s.jail_remaining=minutes*60;s.jail_reason=reason
 FractionDB.exec('UPDATE fraction_state SET jail_remaining=?,jail_reason=?,last_jail=? WHERE account_id=?',s.jail_remaining,reason,F.now(),F.account(target))
 F.clearCuffs(target)
 if not keepDuty then F.endDuty(target) end
 wanted(target,0);F.applyJail(target,false)
 F.notify(target,'КПЗ: '..minutes..' мин.');return true
end
function F.atJailBooking(p)
 local f=Fractions[2];local point=f.jailBooking
 if getElementInterior(p)~=f.interior or getElementDimension(p)~=f.dimension then return false end
 local x,y,z=getElementPosition(p)
 return math.abs(z-point.z)<=1.2 and getDistanceBetweenPoints3D(x,y,z,point.x,point.y,point.z)<=(point.radius or 3)
end
addCommandHandler('arrest',function(p,_,id)
 local target=policeTarget(p,id,'arrest',2)
 if not target then return end
 if not F.atJailBooking(p) then F.notify(p,'Оформить арест можно только перед КПЗ LSPD');return end
 local stars=getPlayerWantedLevel(target)
 if stars<1 then F.notify(p,'/arrest ID — у игрока должен быть розыск');return end
 F.arrest(target,math.min(FractionConfig.jail.max,stars*FractionConfig.jail.perStar),'Арест по уровню розыска')
end)
local function releasePosition(p)
 local pos=Fractions[2].outsideSpawn or FractionConfig.release
 F.clearCuffs(p,true)
 if isPedInVehicle(p) then removePedFromVehicle(p) end
 if isPedDead(p) then spawnPlayer(p,pos.x,pos.y,pos.z,pos.rotation or 90,getCivilianSkin(p),0,0) end
 setElementInterior(p,0);setElementDimension(p,0);setElementPosition(p,pos.x,pos.y,pos.z)
 setPedRotation(p,pos.rotation or 90);setCameraTarget(p,p)
end
addCommandHandler('unarrest',function(p,_,id)
 local member=F.member(p)
 if not F.account(p) or not member or member.faction_id~=2 or member.rank<#Fractions[2].ranks-1 then F.notify(p,'Освобождение доступно только лидеру и заместителю LSPD');return end
 if not F.throttle(p,'unarrest') then return end
 local target=F.player(id);local state=F.account(target) and F.state(target)
 if not state or tonumber(state.jail_remaining)<=0 then F.notify(p,'Игрок не находится в КПЗ');return end
 if not FractionDB.change("UPDATE fraction_state SET jail_remaining=0,jail_reason='' WHERE account_id=? AND jail_remaining>0",F.account(target)) then F.notify(p,'Не удалось освободить игрока');return end
 state.jail_remaining=0;state.jail_reason=''
 releasePosition(target)
 F.notify(target,'Вы освобождены из КПЗ',true)
 if p~=target then F.notify(p,'Заключённый освобождён',true) end
end)

function F.jailTick(p,elapsed)
 local s=F.state(p);if not s or tonumber(s.jail_remaining)<=0 then return end
 s.jail_remaining=math.max(0,s.jail_remaining-elapsed/1000)
 FractionDB.exec('UPDATE fraction_state SET jail_remaining=? WHERE account_id=?',s.jail_remaining,F.account(p))
 if s.jail_remaining<=0 then
  releasePosition(p)
  F.notify(p,'Срок заключения завершён',true)
 else
  local cell=FractionConfig.jailCells[1];local x,y,z=getElementPosition(p)
  if getElementDimension(p)~=FractionConfig.dimensionBase+100 or getElementInterior(p)~=6 or getDistanceBetweenPoints3D(x,y,z,cell.x,cell.y,cell.z)>FractionConfig.jail.radius then F.applyJail(p,false) end
 end
end
addCommandHandler('m',function(p,_,...)
 if not F.active(p,2,2) or not F.throttle(p,'m') then return end
 local vehicle=getPedOccupiedVehicle(p);local spec=vehicle and F.vehicles[vehicle]
 local text=FractionRules.text(table.concat({...},' '),FractionConfig.megaphone.maxLength)
 if not text or not spec or spec.faction~=2 then return end
 local x,y,z=getElementPosition(vehicle)
 for _,other in ipairs(getElementsByType('player')) do
  if getElementDimension(other)==getElementDimension(vehicle) and getElementInterior(other)==getElementInterior(vehicle) then
   local xx,yy,zz=getElementPosition(other)
   if getDistanceBetweenPoints3D(x,y,z,xx,yy,zz)<FractionConfig.megaphone.range then triggerClientEvent(other,'fraction:megaphone',resourceRoot,vehicle,text) end
  end
 end
end)
addEventHandler('onPlayerWasted',root,function(ammo,killer)
 local victim=source;F.clearCuffs(victim,true)
 local stars=getPlayerWantedLevel(victim)
 local police=killer
 if isElement(killer) and getElementType(killer)=='vehicle' then police=getVehicleOccupant(killer,0) end
 local member=isElement(police) and F.account(police) and F.member(police)
 if stars>0 and police~=victim and member and member.faction_id==2 and not F.jailed(victim) then
  F.arrest(victim,math.min(FractionConfig.jail.max,stars*FractionConfig.jail.perStar),'Задержание при гибели от полиции',true)
 end
 if F.returnVehicleKeys then F.returnVehicleKeys(victim,true) end
end,true,'high+10')

addEvent('fraction:syncCuffs',true)
addEventHandler('fraction:syncCuffs',resourceRoot,function()
 if source~=resourceRoot or not client or not F.account(client) or not F.throttle(client,'cuffSync') then return end
 local state=F.cuffs[client];local controls={}
 if state then controls=state.controls
 else for _,name in ipairs(cuffControls) do controls[name]=isControlEnabled(client,name) end end
 triggerClientEvent(client,'fraction:cuff',resourceRoot,state~=nil,controls)
end)
