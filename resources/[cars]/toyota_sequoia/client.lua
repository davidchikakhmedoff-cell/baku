function replaceModel()
  txd = engineLoadTXD('vehicle.txd',404)
  engineImportTXD(txd,404)
  dff = engineLoadDFF('vehicle.dff',404)
  engineReplaceModel(dff,404)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
