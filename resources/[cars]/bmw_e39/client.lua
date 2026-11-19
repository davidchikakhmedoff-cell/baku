function replaceModel()
  txd = engineLoadTXD('vehicle.txd',445)
  engineImportTXD(txd,445)
  dff = engineLoadDFF('vehicle.dff',445)
  engineReplaceModel(dff,445)
end
addEventHandler ( 'onClientResourceStart', getResourceRootElement(getThisResource()), replaceModel)
