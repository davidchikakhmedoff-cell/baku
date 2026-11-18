FractionRules={}
function FractionRules.canManage(actor,target,action)
 if not actor or not target or actor.faction_id~=target.faction_id or actor.account_id==target.account_id then return false end
 local f=Fractions[actor.faction_id];if not f then return false end
 if action=="rank" then return actor.rank==#f.ranks and target.rank<#f.ranks end
 return actor.rank>=#f.ranks-1 and target.rank<actor.rank
end
function FractionRules.integer(value,min,max)
 value=tonumber(value)
 if not value or value~=value or value%1~=0 or value<min or value>max then return false end
 return value
end
function FractionRules.text(value,max)
 if type(value)~="string" then return false end
 value=value:gsub("#%x%x%x%x%x%x",""):gsub("[%c]"," "):match("^%s*(.-)%s*$")
 local length=utf8 and utf8.len and (utf8.len(value) or math.huge) or #value
 if value=="" or length>(max or FractionConfig.textLimit) or #value>(max or FractionConfig.textLimit)*4 then return false end
 return value
end
