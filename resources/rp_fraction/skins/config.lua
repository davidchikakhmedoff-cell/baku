-- Garments are unlocked at minRank and remain available at higher ranks.
-- Add entries/groups here; no server/client code changes are needed.
SkinConfig={
 models={
  [129]={txd='skins/pw1.txd',dff='skins/pw1.dff'},
  [130]={txd='skins/pw2.txd',dff='skins/pw2.dff'},
  [131]={txd='skins/pw3.txd',dff='skins/pw3.dff'},
  [151]={txd='skins/pw5.txd',dff='skins/pw5.dff'}
 },
 factions={
  [2]={title='ГАРДЕРОБ LSPD',subtitle='Выберите служебную форму',groups={
   {minRank=1,male={{model=280,name='Полицейская форма'}},female={{model=129,name='Полицейская форма'}}},
   {minRank=2,male={{model=281,name='Офицерская форма'}},female={{model=130,name='Офицерская форма'}}},
   {minRank=6,male={{model=285,name='Спецподразделение'}},female={{model=131,name='Спецподразделение'}}},
   {minRank=9,male={{model=283,name='Форма заместителя'}},female={{model=150,name='Форма заместителя'}}},
   {minRank=10,male={{model=61,name='Форма шефа полиции'}},female={{model=151,name='Форма шефа полиции'}}}
  }}
 }
}
function SkinConfig.list(faction,gender,rank)
 local config=SkinConfig.factions[faction];local result,byModel={},{}
 if not config then return result end
 gender=gender=='female' and 'female' or 'male'
 for _,group in ipairs(config.groups) do
  if type(group.minRank)=='number' and rank>=group.minRank then
   for _,entry in ipairs(group[gender] or {}) do
    local model=tonumber(entry.model)
    if model and model%1==0 and model>=0 and model<=312 then
     local existing=byModel[model]
     if not existing then
      existing={model=model,name=tostring(entry.name or ('Форма '..model)),minRank=group.minRank}
      byModel[model]=existing;result[#result+1]=existing
     elseif group.minRank<existing.minRank then existing.minRank=group.minRank;existing.name=tostring(entry.name or existing.name) end
    end
   end
  end
 end
 table.sort(result,function(a,b) return a.minRank==b.minRank and a.model<b.model or a.minRank<b.minRank end)
 return result
end
