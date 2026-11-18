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
 if not F.throttle(p,'add') then return end
 local text=FractionRules.text(table.concat({...},' '));if not text then return end
 local id=F.account(p)
 local existing=FractionDB.one("SELECT id FROM fraction_ads WHERE account_id=? AND status='pending'",id)
 if existing then F.notify(p,'Ваше объявление уже находится в очереди');return end
 FractionDB.exec('INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(?,?,?,?,?,?)',id,F.name(p),exports.rp_core:getPlayerDynamicID(p),text,text,F.now())
 F.notify(p,'Объявление отправлено в LS News',true)
end)
addCommandHandler('news',F.newsMenu)
function F.newsProcess(p,action,id,text)
 if not F.active(p,3) then return end
 id=FractionRules.integer(id,1,2147483647);if not id then return end
 local ad=FractionDB.one("SELECT * FROM fraction_ads WHERE id=? AND status='pending'",id);if not ad then F.newsMenu(p);return end
 if action=='reject' then FractionDB.change("UPDATE fraction_ads SET status='rejected',editor_id=?,editor_name=? WHERE id=? AND status='pending'",F.account(p),F.name(p),id)
 else
  text=FractionRules.text(text);if not text then return end
  local changed=FractionDB.change("UPDATE fraction_ads SET status='published',edited=?,editor_id=?,editor_name=? WHERE id=? AND status='pending'",text,F.account(p),F.name(p),id)
  if changed then
   F.balance(F.account(p))
   outputChatBox('[LS NEWS] Автор: '..ad.author..' [ID: '..ad.display_id..'] | Редактор: '..F.name(p)..' | '..text,root,105,210,110)
  end
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
  end
 end
 for p in pairs(F.cuffs) do if isElement(p) then setPedWeaponSlot(p,0) end end
 F.fleetTick()
end
