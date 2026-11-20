local loaded={}
local function destroy(element)
 if element and isElement(element) then destroyElement(element) end
end
local function cleanup()
 for i=#loaded,1,-1 do
  local state=loaded[i]
  destroy(state.object)
  if state.model then
   if state.modelReplaced then engineRestoreModel(state.model) end
   if state.colReplaced then engineRestoreCOL(state.model) end
  end
  destroy(state.dff);destroy(state.col);destroy(state.txd)
  if state.model then engineFreeModel(state.model) end
 end
 loaded={}
end
local function loadObject(paths,pos)
 local cfg=HospitalInteriorConfig;local faction=Fractions[1]
 local state={};loaded[#loaded+1]=state
 state.model=engineRequestModel('object',cfg.baseModel)
 if not state.model then return false,'не удалось выделить модель' end
 if paths.txd then
  state.txd=engineLoadTXD(paths.txd)
  if not state.txd or not engineImportTXD(state.txd,state.model) then return false,paths.txd end
 end
 state.col=engineLoadCOL(paths.col)
 if not state.col then return false,paths.col end
 state.colReplaced=engineReplaceCOL(state.col,state.model)
 if not state.colReplaced then return false,'engineReplaceCOL: '..paths.col end
 state.dff=engineLoadDFF(paths.dff)
 if not state.dff then return false,paths.dff end
 state.modelReplaced=engineReplaceModel(state.dff,state.model,true)
 if not state.modelReplaced then return false,'engineReplaceModel: '..paths.dff end
 engineSetModelLODDistance(state.model,cfg.lodDistance)
 state.object=createObject(state.model,pos.x,pos.y,pos.z)
 if not state.object then return false,'createObject: '..paths.dff end
 setElementInterior(state.object,faction.interior);setElementDimension(state.object,faction.dimension)
 setElementDoubleSided(state.object,true);setElementCollisionsEnabled(state.object,true)
 setElementFrozen(state.object,true);setObjectBreakable(state.object,false)
 return true
end
local function fail(reason)
 cleanup()
 outputDebugString('[Hospital interior] '..reason,1)
 outputChatBox('[Больница] Не удалось загрузить интерьер: '..reason,239,100,100)
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 local cfg=HospitalInteriorConfig
 if type(engineRequestModel)~='function' then fail('требуется актуальный клиент MTA 1.6');return end
 local ok,reason=loadObject(cfg,cfg.origin)
 if not ok then fail(reason);return end
 if cfg.exitBarrier then
  local origin,offset=cfg.origin,cfg.exitBarrier.offset
  ok,reason=loadObject(cfg.exitBarrier,{x=origin.x+offset.x,y=origin.y+offset.y,z=origin.z+offset.z})
  if not ok then fail(reason) end
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,cleanup)
