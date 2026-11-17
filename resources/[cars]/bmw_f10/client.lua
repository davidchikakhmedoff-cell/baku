function replaceModel()
  txd = engineLoadTXD('vehicle.txd',529)
  engineImportTXD(txd,529)
  dff = engineLoadDFF('vehicle.dff',529)
  engineReplaceModel(dff,529)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
