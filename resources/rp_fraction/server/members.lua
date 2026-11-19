local F=Fraction
function F.membersMenu(p)
 local m=F.member(p);if not m then return end
 if m.rank<#Fractions[m.faction_id].ranks-1 then F.notify(p,'Список состава доступен лидеру и заместителям');return end
 local rows=FractionDB.query('SELECT m.*,p.rp_name FROM fraction_members m JOIN players p ON p.id=m.account_id WHERE faction_id=? ORDER BY rank DESC',m.faction_id)
 triggerClientEvent(p,'fraction:menu',resourceRoot,'members',{rows=rows,faction=m.faction_id,rank=m.rank})
end
local function invite(p,id)
 if not F.throttle(p,'invite') then return end
 local m=F.member(p);local f=m and Fractions[m.faction_id];local target=F.player(id)
 if not f or m.rank<#f.ranks-1 or target==p or not F.account(target) or not F.near(p,target) or F.member(target) or F.jailed(target) then F.notify(p,'Приглашение недоступно: проверьте ранг, дистанцию и фракцию игрока');return end
 F.invites[target]={inviter=p,faction=m.faction_id,expires=F.now()+FractionConfig.inviteSeconds}
 F.respondInvite(target,true)
end
function F.respondInvite(p,accept)
 local invitation=F.invites[p];F.invites[p]=nil
 if not invitation or not accept then return end
 local actor=F.member(invitation.inviter);local f=Fractions[invitation.faction]
 if F.now()>invitation.expires or not actor or actor.faction_id~=invitation.faction or actor.rank<#f.ranks-1 or not F.near(p,invitation.inviter) or F.member(p) or not F.account(p) or F.jailed(p) then return end
 local id=F.account(p)
 if not FractionDB.change('INSERT OR IGNORE INTO fraction_members(account_id,faction_id,rank,civilian_skin) VALUES(?,?,1,?)',id,f.id,getElementModel(p)) then return end
 F.reload(id);F.sync(p);F.notify(p,'Вы вступили в '..f.name,true);F.notify(invitation.inviter,'Игрок принят во фракцию',true)
end
function F.dismiss(p,targetId)
 local actor=F.member(p);targetId=FractionRules.integer(targetId,1,2147483647)
 local target=targetId and F.reload(targetId)
 if not FractionRules.canManage(actor,target,'dismiss') then F.notify(p,'Недостаточно полномочий для увольнения');return end
 for _,online in ipairs(getElementsByType('player')) do if F.account(online)==targetId then F.endDuty(online);if Fractions[target.faction_id].category=='criminal' then setElementModel(online,target.civilian_skin) end;F.clearCuffs(online,true) end end
 FractionDB.exec('DELETE FROM fraction_members WHERE account_id=?',targetId);F.members[targetId]=nil
 for _,online in ipairs(getElementsByType('player')) do if F.account(online)==targetId then F.sync(online);F.revokeDriver(online);F.notify(online,'Вы уволены из фракции') end end
 F.membersMenu(p)
end
function F.rank(p,targetId,rank)
 local actor=F.member(p);targetId=FractionRules.integer(targetId,1,2147483647)
 local target=targetId and F.reload(targetId);local f=actor and Fractions[actor.faction_id]
 rank=f and FractionRules.integer(rank,1,#f.ranks-1)
 if not rank or not FractionRules.canManage(actor,target,'rank') then F.notify(p,'Изменение ранга запрещено');return end
 for _,online in ipairs(getElementsByType('player')) do if F.account(online)==targetId then F.endDuty(online) end end
 FractionDB.exec('UPDATE fraction_members SET rank=? WHERE account_id=?',rank,targetId);F.reload(targetId)
 for _,online in ipairs(getElementsByType('player')) do if F.account(online)==targetId then
  F.sync(online);if F.sessions[online] and F.sessions[online].duty then setElementModel(online,f.skins[rank]) end;F.revokeDriver(online)
 end end
 F.membersMenu(p)
end
addCommandHandler('invite',function(p,_,id) invite(p,id) end)
addCommandHandler('acceptfraction',function(p) F.respondInvite(p,true) end)
addCommandHandler('declinefraction',function(p) F.respondInvite(p,false) end)
addCommandHandler('uninvite',function(p,_,id) local target=F.player(id);if target then F.dismiss(p,F.account(target)) end end)
addCommandHandler('giverank',function(p,_,id,rank) local target=F.player(id);if target then F.rank(p,F.account(target),rank) end end)
addCommandHandler('members',F.membersMenu)
addCommandHandler('f',function(p,_,...)
 local text=FractionRules.text(table.concat({...},' '));local m=F.member(p)
 if not m or not text or not F.throttle(p,'f') then return end
 for _,other in ipairs(getElementsByType('player')) do local member=F.member(other);if member and member.faction_id==m.faction_id then
  outputChatBox('[F] '..Fractions[m.faction_id].ranks[m.rank]..' '..F.name(p)..': '..text,other,unpack(Fractions[m.faction_id].color))
 end end
end)
-- Founder-only appointment/removal, using the existing live dynamic player ID.
addCommandHandler('setleader',function(p,_,id,fid)
 if not F.account(p) then return end
 if exports.rp_core:isCoreFounder(p)~=true then F.notify(p,'Команда доступна только основателю сервера');return end
 local dynamicId=FractionRules.integer(id,1,2147483647);fid=FractionRules.integer(fid,0,6)
 if not fid or not dynamicId then F.notify(p,'Использование: /setleader ID_ИГРОКА ID_ФРАКЦИИ (1–6, 0 — снять лидера)');return end
 local target=F.player(dynamicId);local targetId=target and F.account(target)
 if not targetId then F.notify(p,'Авторизованный игрок с таким ID не найден');return end
 local existing=F.reload(targetId)
 if fid==0 then
  local definition=existing and Fractions[existing.faction_id]
  if not definition or existing.rank~=#definition.ranks then F.notify(p,'Игрок не является лидером фракции');return end
  F.endDuty(target)
  if not FractionDB.change('DELETE FROM fraction_members WHERE account_id=? AND faction_id=? AND rank=?',targetId,existing.faction_id,existing.rank) then
   F.notify(p,'Не удалось сохранить снятие лидера');return
  end
  F.members[targetId]=nil
  if definition.category=='criminal' then setElementModel(target,existing.civilian_skin) end
  F.sync(target);F.revokeDriver(target)
  F.notify(p,'Лидер '..definition.name..' снят и уволен: '..F.name(target),true)
  if target~=p then F.notify(target,'Вы сняты с должности лидера и уволены из '..definition.name) end
  return
 end
 if existing and existing.faction_id~=fid then F.notify(p,'Сначала увольте игрока из другой фракции');return end
 local top=#Fractions[fid].ranks
 -- Demote the previous leader before promoting; the unique index forbids two leaders.
 local current=FractionDB.one('SELECT account_id FROM fraction_members WHERE faction_id=? AND rank=?',fid,top)
 if current and tonumber(current.account_id)~=targetId then FractionDB.exec('UPDATE fraction_members SET rank=? WHERE account_id=?',top-1,current.account_id);F.reload(tonumber(current.account_id)) end
 local account=FractionDB.one('SELECT skin FROM players WHERE id=?',targetId)
 FractionDB.exec('INSERT OR IGNORE INTO fraction_members(account_id,faction_id,rank,civilian_skin) VALUES(?,?,1,?)',targetId,fid,account and tonumber(account.skin) or 0)
 FractionDB.exec('UPDATE fraction_members SET rank=? WHERE account_id=? AND faction_id=?',top,targetId,fid);F.reload(targetId)
 for _,online in ipairs(getElementsByType('player')) do if F.member(online) then F.sync(online);F.revokeDriver(online) end end
 F.notify(p,'Лидер '..Fractions[fid].name..' назначен: '..F.name(target),true)
 if target~=p then F.notify(target,'Вы назначены лидером '..Fractions[fid].name,true) end
end)

-- The project's custom chat does not execute native command handlers itself.
-- Accept only our known commands, and only from that authenticated core route.
local chatCommands={invite=true,acceptfraction=true,declinefraction=true,uninvite=true,giverank=true,members=true,f=true,r=true,rb=true,d=true,db=true,setleader=true,
 heal=true,sms=true,add=true,news=true,ticket=true,tickets=true,payticket=true,su=true,clearwanted=true,cuff=true,uncuff=true,arrest=true,unarrest=true,m=true}
function executeFractionCommand(p,command,args)
 if sourceResource~=getResourceFromName('rp_core') or not chatCommands[command] then return false end
 if not F.account(p) then F.notify(p,'Система фракций ещё не готова. Дождитесь загрузки зависимостей');return true end
 if command=='arrest' then
  F.commandArrest(p,type(args)=='string' and args:match('^%s*(%S+)') or nil)
 elseif executeCommandHandler(command,p,type(args)=='string' and args or '')==false then
  F.notify(p,'Не удалось выполнить /'..command..'. Проверьте обновление rp_fraction')
 end
 return true
end
addEvent('fraction:action',true)
addEventHandler('fraction:action',resourceRoot,function(action,data)
 local p=client;if not p or source~=resourceRoot or not F.account(p) or type(action)~='string' then return end
 if action=='keysClose' then F.keyMenus[p]=nil;return end
 if not F.throttle(p,'ui') then return end
 data=type(data)=='table' and data or {}
 if action=='accept' then F.respondInvite(p,true)
 elseif action=='decline' then F.respondInvite(p,false)
 elseif action=='duty' then F.toggleDuty(p)
 elseif action=='members' then F.membersMenu(p)
 elseif action=='keysTake' then F.takeVehicleKeys(p,data.slot)
 elseif action=='keysReturn' then F.returnVehicleKeys(p,false)
 elseif action=='keysRefresh' then F.keysMenu(p)
 elseif action=='armory' and type(data.weapons)=='table' then F.armory(p,data.weapons)
 elseif action=='news' then F.newsMenu(p)
 elseif action=='publish' or action=='reject' then F.newsProcess(p,action,data.id,data.text)
 elseif action=='payticket' then F.payTicket(p,data.id) end
end)
