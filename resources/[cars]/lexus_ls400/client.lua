function replaceModel()
  txd = engineLoadTXD('vehicle.txd',421)
  engineImportTXD(txd,421)
  dff = engineLoadDFF('vehicle.dff',421)
  engineReplaceModel(dff,421)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
