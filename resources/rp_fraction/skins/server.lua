Wardrobe={}
local W,F=Wardrobe,Fraction
local sequence=0
function W.supports(faction) return SkinConfig.factions[faction]~=nil end
function W.gender(p,m)
 m=m or F.member(p)
 if not m then return 'male' end
 if not m.gender then
  local row=FractionDB.one('SELECT gender FROM players WHERE id=?',m.account_id)
  m.gender=row and row.gender=='female' and 'female' or 'male'
 end
 return m.gender
end
function W.rows(p,m)
 m=m or F.member(p)
 return m and SkinConfig.list(m.faction_id,W.gender(p,m),m.rank) or {}
end
function W.allowed(p,model,m)
 for _,entry in ipairs(W.rows(p,m)) do if entry.model==model then return true end end
 return false
end
local function ready(p)
 local m=F.member(p);local session=F.sessions[p]
 return F.account(p) and m and W.supports(m.faction_id) and session and session.duty
  and F.active(p,m.faction_id) and not F.cuffs[p],m,session
end
local function nearMarker(p,m)
 return not isPedInVehicle(p) and F.near(p,F.markers['duty:'..m.faction_id],3)
end
function W.resolve(p,m)
 local session=F.sessions[p]
 if not session or not session.duty then return m.civilian_skin end
 if session.uniformSkin and not W.allowed(p,session.uniformSkin,m) then
  local first=W.rows(p,m)[1];session.uniformSkin=first and first.model or nil
 end
 return session.uniformSkin or m.civilian_skin
end
function W.open(p,remote)
 local valid,m,session=ready(p)
 if not valid then F.notify(p,'Гардероб доступен только сотруднику на смене');return false end
 if not remote and not nearMarker(p,m) then F.notify(p,'Подойдите к маркеру смены своей фракции');return false end
 local rows=W.rows(p,m);if #rows==0 then F.notify(p,'Для вашего ранга нет доступной формы');return false end
 sequence=sequence+1
 session.wardrobe={token=sequence,remote=remote==true,faction=m.faction_id,account=m.account_id}
 local config=SkinConfig.factions[m.faction_id]
 triggerClientEvent(p,'fraction:menu',resourceRoot,'wardrobe',{rows=rows,current=getElementModel(p),token=sequence,title=config.title,subtitle=config.subtitle})
 return true
end
function W.close(p,token)
 local session=F.sessions[p]
 if session and session.wardrobe and session.wardrobe.token==token then session.wardrobe=nil end
end
function W.wear(p,data)
 if type(data)~='table' then return end
 local valid,m,session=ready(p);local opened=session and session.wardrobe
 if not valid or not opened or data.token~=opened.token or opened.account~=m.account_id or opened.faction~=m.faction_id then F.notify(p,'Откройте гардероб у маркера смены');return end
 if not opened.remote and not nearMarker(p,m) then F.notify(p,'Подойдите к маркеру смены');return end
 local model=FractionRules.integer(data.model,0,312)
 if not model or not W.allowed(p,model,m) then F.notify(p,'Эта форма недоступна вашему рангу или полу');return end
 if getElementModel(p)~=model and not setElementModel(p,model) then F.notify(p,'Не удалось применить модель формы');return end
 session.uniformSkin=model;session.wardrobe=nil
 F.sync(p);F.notify(p,'Служебная форма надета',true)
end
function W.rankChanged(p)
 local m=F.member(p);local session=F.sessions[p]
 if not m or not W.supports(m.faction_id) or not session or not session.duty then return end
 -- Resolve invalid clothing immediately; closing the offered menu cannot
 -- retain a higher-rank uniform. Valid lower-rank selections remain intact.
 W.resolve(p,m);F.sync(p);W.open(p,true)
end
