-- Replacement ID is unique across [cars] and rp_fraction/cars.
local model = 458
local txd,dff,replaced
local function cleanup()
 if replaced then engineRestoreModel(model);replaced=false end
 if dff and isElement(dff) then destroyElement(dff) end
 if txd and isElement(txd) then destroyElement(txd) end
 dff,txd=nil,nil
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 txd=engineLoadTXD('vehicle.txd')
 if txd and engineImportTXD(txd,model) then dff=engineLoadDFF('vehicle.dff') end
 if dff and engineReplaceModel(dff,model) then replaced=true
 else
  cleanup()
  outputDebugString('[skoda_octavia_universal] Failed to load vehicle replacement '..model,1)
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,cleanup)
