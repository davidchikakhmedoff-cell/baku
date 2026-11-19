dofile('resources/rp_fraction/skins/config.lua')
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
resourceRoot={}
local handlers,loaded,restored={}, {},{}
local fail=false;local errors=0
function addEventHandler(name,_,fn) handlers[name]=fn end
function engineLoadTXD(path) return {path=path} end
function engineImportTXD(txd,id) assert(SkinConfig.models[id].txd==txd.path);return true end
function engineLoadDFF(path) if fail and path=='skins/pw2.dff' then return false end;return {path=path} end
function engineReplaceModel(dff,id) assert(SkinConfig.models[id].dff==dff.path);loaded[id]=dff;return true end
function engineRestoreModel(id) restored[id]=true end
function isElement(e) return type(e)=='table' and not e.destroyed end
function destroyElement(e) e.destroyed=true end
function outputDebugString() errors=errors+1 end
dofile('resources/rp_fraction/skins/models.lua')
handlers.onClientResourceStart()
assert(loaded[129] and loaded[130] and loaded[131] and loaded[151] and not loaded[150],'four uploaded models replace only requested IDs')
handlers.onClientResourceStop();assert(restored[129] and restored[130] and restored[131] and restored[151],'models restored on stop')
fail=true;loaded={};handlers.onClientResourceStart()
assert(loaded[129] and not loaded[130] and loaded[131] and errors==1,'one failed asset does not break other models')
handlers.onClientResourceStop()
print('Female model loader: exact ID/file mapping, failure isolation and restoration passed')
