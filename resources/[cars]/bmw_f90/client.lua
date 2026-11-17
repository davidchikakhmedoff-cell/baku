function replaceModel()
  txd = engineLoadTXD('vehicle.txd',560)
  engineImportTXD(txd,560)
  dff = engineLoadDFF('vehicle.dff',560)
  engineReplaceModel(dff,560)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
