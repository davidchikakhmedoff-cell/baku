function replaceModel()
  txd = engineLoadTXD('vehicle.txd',400)
  engineImportTXD(txd,400)
  dff = engineLoadDFF('vehicle.dff',400)
  engineReplaceModel(dff,400)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
