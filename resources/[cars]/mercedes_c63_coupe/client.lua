function replaceModel()
  txd = engineLoadTXD('vehicle.txd',477)
  engineImportTXD(txd,477)
  dff = engineLoadDFF('vehicle.dff',477)
  engineReplaceModel(dff,477)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
