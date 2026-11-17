function replaceModel()
  txd = engineLoadTXD('vehicle.txd',579)
  engineImportTXD(txd,579)
  dff = engineLoadDFF('vehicle.dff',579)
  engineReplaceModel(dff,579)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
