dofile('resources/rp_fraction/interior/config.lua')
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
for _,failure in ipairs({'none','request','txd','import','col','replaceCol','dff','replaceModel','object'}) do
 local handlers,elements,restored,freed,errors={}, {},{},0,0
 local allocated=21001
 function addEventHandler(name,_,fn) handlers[name]=fn end
 function isElement(e) return type(e)=='table' and not e.dead end
 function destroyElement(e) assert(not e.dead,'no double destroy');e.dead=true end
 local function element(kind) local e={kind=kind};elements[#elements+1]=e;return e end
 function engineRequestModel(kind,base) assert(kind=='object' and base==1337);if failure~='request' then return allocated end end
 function engineLoadTXD(path) assert(path==HospitalInteriorConfig.txd);if failure~='txd' then return element('txd') end end
 function engineImportTXD(_,id) assert(id==allocated);return failure~='import' end
 function engineLoadCOL(path) assert(path=='interior/laehospital1.col','never load whole road collision archive');if failure~='col' then return element('col') end end
 function engineReplaceCOL(_,id) assert(id==allocated);return failure~='replaceCol' end
 function engineLoadDFF(path) assert(path==HospitalInteriorConfig.dff);if failure~='dff' then return element('dff') end end
 function engineReplaceModel(_,id) assert(id==allocated,'base world model must not be replaced');return failure~='replaceModel' end
 function engineSetModelLODDistance(id,distance) assert(id==allocated and distance==200) end
 function createObject(id,x,y,z)
  assert(id==allocated and x==1500 and y==1500 and z==1200)
  if failure~='object' then return element('object') end
 end
 function setElementInterior(e,id) assert(e.kind=='object' and id==Fractions[1].interior);e.interior=id end
 function setElementDimension(e,id) assert(id==Fractions[1].dimension);e.dimension=id end
 function setElementDoubleSided() end
 function setElementCollisionsEnabled(_,on) assert(on) end
 function setElementFrozen(_,on) assert(on) end
 function setObjectBreakable(_,on) assert(not on) end
 function engineRestoreModel(id) assert(id==allocated);restored.model=true end
 function engineRestoreCOL(id) assert(id==allocated);restored.col=true end
 function engineFreeModel(id) assert(id==allocated);freed=freed+1 end
 function outputDebugString() errors=errors+1 end
 function outputChatBox() end
 dofile('resources/rp_fraction/interior/client.lua')
 handlers.onClientResourceStart()
 if failure=='none' then
  local shell=elements[#elements];assert(shell.kind=='object' and shell.interior==1 and shell.dimension==20001,'custom hospital lives only in faction interior world')
  assert(not shell.dead and freed==0,'active shell stays loaded')
 else assert(errors==1,'failed asset reports the problem once') end
 handlers.onClientResourceStop();handlers.onClientResourceStop()
 assert(freed==(failure=='request' and 0 or 1),'dynamic slot freed exactly once on stop/failure')
 for _,e in ipairs(elements) do assert(e.dead,'all assets and shell released') end
 if failure=='none' then assert(restored.model and restored.col,'both replacements restored before freeing slot') end
end
print('Custom hospital: dynamic model isolation, extracted collision, world/dimension, loading failures and complete cleanup passed')
