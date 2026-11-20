local model,object,txd,dff,col
local modelReplaced,colReplaced=false,false
local function destroy(element)
 if element and isElement(element) then destroyElement(element) end
end
local function cleanup()
 destroy(object);object=nil
 if model then
  if modelReplaced then engineRestoreModel(model) end
  if colReplaced then engineRestoreCOL(model) end
 end
 destroy(dff);destroy(col);destroy(txd);dff,col,txd=nil,nil,nil
 if model then engineFreeModel(model);model=nil end
 modelReplaced,colReplaced=false,false
end
local function fail(reason)
 cleanup()
 outputDebugString('[Hospital interior] '..reason,1)
 outputChatBox('[Больница] Не удалось загрузить интерьер: '..reason,239,100,100)
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 local cfg=HospitalInteriorConfig;local faction=Fractions[1]
 if type(engineRequestModel)~='function' then fail('требуется актуальный клиент MTA 1.6');return end
 model=engineRequestModel('object',cfg.baseModel)
 if not model then fail('не удалось выделить модель');return end
 txd=engineLoadTXD(cfg.txd)
 if not txd or not engineImportTXD(txd,model) then fail(cfg.txd);return end
 col=engineLoadCOL(cfg.col)
 if not col then fail(cfg.col);return end
 colReplaced=engineReplaceCOL(col,model)
 if not colReplaced then fail('engineReplaceCOL');return end
 dff=engineLoadDFF(cfg.dff)
 if not dff then fail(cfg.dff);return end
 modelReplaced=engineReplaceModel(dff,model,true)
 if not modelReplaced then fail('engineReplaceModel');return end
 engineSetModelLODDistance(model,cfg.lodDistance)
 local p=cfg.origin
 object=createObject(model,p.x,p.y,p.z)
 if not object then fail('createObject');return end
 setElementInterior(object,faction.interior);setElementDimension(object,faction.dimension)
 setElementDoubleSided(object,true);setElementCollisionsEnabled(object,true)
 setElementFrozen(object,true);setObjectBreakable(object,false)
end)
addEventHandler('onClientResourceStop',resourceRoot,cleanup)
