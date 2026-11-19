function replaceModel()
  txd = engineLoadTXD('vehicle.txd',436)
  engineImportTXD(txd,436)
  dff = engineLoadDFF('vehicle.dff',436)
  engineReplaceModel(dff,436)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
