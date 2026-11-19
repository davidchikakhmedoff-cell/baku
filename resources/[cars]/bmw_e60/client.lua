function replaceModel()
  txd = engineLoadTXD('vehicle.txd',405)
  engineImportTXD(txd,405)
  dff = engineLoadDFF('vehicle.dff',405)
  engineReplaceModel(dff,405)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
