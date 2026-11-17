function replaceModel()
  txd = engineLoadTXD('vehicle.txd',411)
  engineImportTXD(txd,411)
  dff = engineLoadDFF('vehicle.dff',411)
  engineReplaceModel(dff,411)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
