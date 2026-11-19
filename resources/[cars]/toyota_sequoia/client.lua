function replaceModel()
  txd = engineLoadTXD('vehicle.txd',479)
  engineImportTXD(txd,479)
  dff = engineLoadDFF('vehicle.dff',479)
  engineReplaceModel(dff,479)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
