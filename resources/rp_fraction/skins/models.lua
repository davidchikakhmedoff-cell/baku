local models,errors={},{}
local retryTimer
local function release(loaded,id)
 if id then engineRestoreModel(id) end
 if loaded.dff and isElement(loaded.dff) then destroyElement(loaded.dff) end
 if loaded.txd and isElement(loaded.txd) then destroyElement(loaded.txd) end
end
local function loadModel(id,paths)
 if models[id] then return true end
 local loaded={};local reason
 if not fileExists(paths.txd) then reason='нет файла '..paths.txd
 elseif not fileExists(paths.dff) then reason='нет файла '..paths.dff
 else
  loaded.txd=engineLoadTXD(paths.txd)
  if not loaded.txd then reason='engineLoadTXD: '..paths.txd
  elseif not engineImportTXD(loaded.txd,id) then reason='engineImportTXD: '..paths.txd
  else
   loaded.dff=engineLoadDFF(paths.dff)
   if not loaded.dff then reason='engineLoadDFF: '..paths.dff
   elseif not engineReplaceModel(loaded.dff,id) then reason='engineReplaceModel: '..paths.dff
   end
  end
 end
 if reason then
  release(loaded)
  if errors[id]~=reason then outputDebugString('[Fraction] Скин '..id..': '..reason,1) end
  errors[id]=reason;return false
 end
 models[id]=loaded;errors[id]=nil;return true
end
local function loadMissing()
 for id,paths in pairs(SkinConfig.models) do loadModel(id,paths) end
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 loadMissing()
 -- Retry transient engine failures without reloading models that already work.
 local remaining=2
 retryTimer=setTimer(function()
  loadMissing();remaining=remaining-1
  if remaining==0 then
   retryTimer=nil
   if next(errors) then outputChatBox('[Скины] Не все модели загрузились. Введите /checkskins для проверки.',239,100,100) end
  end
 end,1500,2)
end)
addEventHandler('onClientFileDownloadComplete',resourceRoot,function(path,success)
 if not success then return end
 for id,paths in pairs(SkinConfig.models) do
  if path==paths.txd or path==paths.dff then loadModel(id,paths) end
 end
end)
addCommandHandler('checkskins',function()
 loadMissing()
 local current=getElementModel(localPlayer)
 outputChatBox('[Скины] Текущий ID: '..current..'. '..(models[current] and 'Пользовательская модель загружена.' or 'Пользовательская модель не загружена для этого ID.'),180,215,240)
 local ids={};for id in pairs(SkinConfig.models) do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids) do
  local paths=SkinConfig.models[id]
  local ok=models[id]~=nil
  outputChatBox('[Скины] '..id..' ('..paths.dff..'): '..(ok and 'загружен' or errors[id]),ok and 103 or 239,ok and 196 or 100,ok and 216 or 100)
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 if retryTimer and isTimer(retryTimer) then killTimer(retryTimer) end
 retryTimer=nil
 for id,loaded in pairs(models) do release(loaded,id) end
 models={};errors={}
end)
