local models={}
addEventHandler('onClientResourceStart',resourceRoot,function()
 for id,paths in pairs(SkinConfig.models) do
  local txd=engineLoadTXD(paths.txd)
  local imported=txd and engineImportTXD(txd,id)
  local dff=imported and engineLoadDFF(paths.dff)
  if dff and engineReplaceModel(dff,id) then models[id]={txd=txd,dff=dff}
  else
   if dff and isElement(dff) then destroyElement(dff) end
   if txd and isElement(txd) then destroyElement(txd) end
   outputDebugString('[Fraction] Не удалось загрузить женский скин '..id..' ('..paths.dff..')',1)
  end
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 for id,loaded in pairs(models) do
  engineRestoreModel(id)
  if isElement(loaded.dff) then destroyElement(loaded.dff) end
  if isElement(loaded.txd) then destroyElement(loaded.txd) end
 end
 models={}
end)
