local F=Fraction
local function radio(p,command,...)
 if not F.account(p) then return end
 local member=F.member(p);local definition=member and Fractions[member.faction_id]
 if not definition then F.notify(p,'Вы не состоите во фракции');return end
 local department=command=='d' or command=='db'
 local config=FractionConfig.radio
 if department and not config.department[member.faction_id] then
  F.notify(p,'Рация департамента доступна больнице, LSPD и LS News');return
 end
 local expires=tonumber(getElementData(p,'admin:muteExpires'))
 if getElementData(p,'admin:muted') and (not expires or expires>F.now()) then
  F.notify(p,'Во время блокировки чата рация недоступна');return
 end
 local message=FractionRules.text(table.concat({...},' '))
 if not message then F.notify(p,'/'..command..' сообщение');return end
 if not F.throttle(p,'radio') then return end
 local name=F.name(p):gsub('#%x%x%x%x%x%x','')
 local line='['..definition.ranks[member.rank]..'] '..name..': '..message
 if command=='rb' or command=='db' then line='(( '..line..' ))' end
 local color=department and config.departmentColor or config.fractionColor
 for _,target in ipairs(getElementsByType('player')) do
  local other=F.account(target) and F.member(target)
  if other and (department and config.department[other.faction_id] or not department and other.faction_id==member.faction_id) then
   exports.rp_core:sendCoreChatMessage(target,line,color[1],color[2],color[3])
  end
 end
end
for _,command in ipairs({'r','rb','d','db'}) do addCommandHandler(command,radio) end
