local addCommandHandler = FractionCommands and FractionCommands.add or addCommandHandler
local F=Fraction
addCommandHandler('heal',function(p,_,id)
 if not F.active(p,1) or not F.throttle(p,'heal') then return end
 local target=F.player(id)
 if target==p or not F.account(target) or isPedDead(target) or not F.near(p,target) or getElementHealth(target)>=100 or F.jailed(target) then F.notify(p,'Пациент недоступен или не нуждается в лечении');return end
 if not F.charge(target,FractionConfig.healPrice) then F.notify(p,'У пациента недостаточно денег');return end
 setElementHealth(target,100);F.notify(target,'Лечение завершено. Списано $'..FractionConfig.healPrice,true);F.notify(p,'Пациент вылечен',true)
end)
addCommandHandler('sms',function(p,_,id,...)
 if not F.throttle(p,'sms') then return end
 local target=F.player(id);local text=FractionRules.text(table.concat({...},' '))
 if target==p or not F.account(target) or not text then F.notify(p,'/sms ID текст — укажите другого игрока');return end
 if not F.charge(p,FractionConfig.smsPrice) then F.notify(p,'Недостаточно денег для SMS');return end
 outputChatBox('[SMS → '..F.name(target)..' ('..tostring(exports.rp_core:getPlayerDynamicID(target))..')]: '..text,p,200,190,225)
 outputChatBox('[SMS от '..F.name(p)..' ('..tostring(exports.rp_core:getPlayerDynamicID(p))..')]: '..text,target,200,190,225)
end)
function F.newsMenu(p)
 if not F.active(p,3) then return end
 triggerClientEvent(p,'fraction:menu',resourceRoot,'news',{rows=FractionDB.query("SELECT * FROM fraction_ads WHERE status='pending' ORDER BY id LIMIT 100")})
end
addCommandHandler('add',function(p,_,...)
 local id=F.account(p);if not id then return end
 local text=FractionRules.text(table.concat({...},' '));if not text then F.notify(p,'Используйте /add текст объявления');return end
 local now=F.now();local last=FractionDB.one('SELECT submitted_at FROM fraction_ad_cooldowns WHERE account_id=?',id)
 local remaining=last and FractionConfig.cooldown.add-(now-tonumber(last.submitted_at)) or 0
 if remaining>0 then F.notify(p,'Следующее объявление можно отправить через '..math.ceil(remaining)..' сек.');return end
 local existing=FractionDB.one("SELECT id FROM fraction_ads WHERE account_id=? AND status='pending'",id)
 if existing then F.notify(p,'Ваше объявление уже находится в очереди');return end
 if not FractionDB.exec('INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(?,?,?,?,?,?)',id,F.name(p),exports.rp_core:getPlayerDynamicID(p),text,text,now) then
  F.notify(p,'Не удалось отправить объявление. Повторите позже');return
 end
 F.notify(p,'Объявление отправлено в LS News. При публикации будет списано $'..FractionConfig.newsPrice,true)
end)
addCommandHandler('news',F.newsMenu)
function F.newsProcess(p,action,id,text)
 if not F.active(p,3) or (action~='publish' and action~='reject') then return end
 local member=F.member(p);local rank=member and Fractions[3].ranks[member.rank];if not rank then return end
 id=FractionRules.integer(id,1,2147483647);if not id then return end
 local ad=FractionDB.one("SELECT * FROM fraction_ads WHERE id=? AND status='pending'",id);if not ad then F.newsMenu(p);return end
 if action=='reject' then FractionDB.change("UPDATE fraction_ads SET status='rejected',editor_id=?,editor_name=? WHERE id=? AND status='pending'",F.account(p),F.name(p),id)
 else
  text=FractionRules.text(text);if not text then return end
  local author
  for _,online in ipairs(getElementsByType('player')) do if F.account(online)==tonumber(ad.account_id) then author=online;break end end
  if not author then
   FractionDB.exec("DELETE FROM fraction_ads WHERE id=? AND status='pending'",id);F.notify(p,'Автор вышел с сервера');F.newsMenu(p);return
  end
  if (tonumber(exports.rp_core:getAuthPlayerBalance(author)) or 0)<FractionConfig.newsPrice then
   F.notify(p,'У автора недостаточно денег для публикации ($'..FractionConfig.newsPrice..')');return
  end
  -- The guarded status update and SQLite trigger debit/reward in one statement.
  local changed=FractionDB.change("UPDATE fraction_ads SET status='published',edited=?,editor_id=?,editor_name=? WHERE id=? AND status='pending'",text,F.account(p),F.name(p),id)
  if not changed then F.notify(p,'Публикация не выполнена: объявление уже обработано либо оплата недоступна');F.newsMenu(p);return end
  F.balance(tonumber(ad.account_id));if tonumber(ad.account_id)~=F.account(p) then F.balance(F.account(p)) end
  local authorName=tostring(ad.author):gsub('#%x%x%x%x%x%x','')
  local editorName=F.name(p):gsub('#%x%x%x%x%x%x','')
  local body=text:find('[.!?]$') and text or text..'.'
  local first='Объявление: '..body..' Телефон: '..tostring(ad.display_id)
  local second='Подал: '..authorName..'. Отредактировал: '..rank..' '..editorName
  for _,online in ipairs(getElementsByType('player')) do if F.account(online) then
   exports.rp_core:sendCoreChatMessage(online,first,105,210,110)
   exports.rp_core:sendCoreChatMessage(online,second,105,210,110)
  end end
  F.notify(author,'Объявление опубликовано. Списано $'..FractionConfig.newsPrice,true)
  F.notify(p,'Объявление опубликовано. Получено $'..FractionConfig.newsReward,true)
 end
 F.newsMenu(p)
end
function F.tick()
 local now=getTickCount()
 for p,s in pairs(F.sessions) do
  if F.account(p) then
   local elapsed=math.min(FractionConfig.tickMs,math.max(0,now-s.last));s.last=now
   local m=F.member(p)
   if m and F.active(p) and getPlayerIdleTime(p)<FractionConfig.idleLimitMs then
    m.salary_ms=m.salary_ms+elapsed
    FractionDB.exec('UPDATE fraction_members SET salary_ms=? WHERE account_id=?',m.salary_ms,m.account_id)
    if m.salary_ms>=FractionConfig.salaryHourMs then
     local key='salary:'..m.account_id..':'..(m.salary_cycle+1)
     if F.credit(m.account_id,Fractions[m.faction_id].salaries[m.rank],key,'salary') then
      F.reload(m.account_id);F.notify(p,'Получена почасовая зарплата',true)
     end
    end
   end
   F.jailTick(p,elapsed)
   F.syncWanted(p)
  end
 end
 for p in pairs(F.cuffs) do if isElement(p) then setPedWeaponSlot(p,0) end end
 F.fleetTick()
end
