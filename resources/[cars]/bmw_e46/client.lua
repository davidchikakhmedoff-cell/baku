function replaceModel()
  txd = engineLoadTXD('vehicle.txd',547)
  engineImportTXD(txd,547)
  dff = engineLoadDFF('vehicle.dff',547)
  engineReplaceModel(dff,547)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
