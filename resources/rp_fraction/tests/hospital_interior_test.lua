dofile('resources/rp_fraction/interior/config.lua')
dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
for _,failure in ipairs({'none','request','txd','import','col','replaceCol','dff','replaceModel','object',
 'barrier_request','barrier_col','barrier_replaceCol','barrier_dff','barrier_replaceModel','barrier_object'}) do
 local handlers,elements,restored,freed,errors={}, {},{}, {},0
 local phase=0
 local function bad(stage) return failure==(phase==2 and 'barrier_'..stage or stage) end
 function addEventHandler(name,_,fn) handlers[name]=fn end
 function isElement(e) return type(e)=='table' and not e.dead end
 function destroyElement(e) assert(not e.dead,'no double destroy');e.dead=true end
 local function element(kind) local e={kind=kind};elements[#elements+1]=e;return e end
 function engineRequestModel(kind,base)
  assert(kind=='object' and base==1337);phase=phase+1
  if not bad('request') then return 21000+phase end
 end
 function engineLoadTXD(path) assert(path==HospitalInteriorConfig.txd);if not bad('txd') then return element('txd') end end
 function engineImportTXD(_,id) assert(id==21001);return not bad('import') end
 function engineLoadCOL(path)
  assert(path==(phase==1 and 'interior/laehospital1.col' or 'interior/exit_barrier.col'),'never load whole road collision archive')
  if not bad('col') then return element('col') end
 end
 function engineReplaceCOL(_,id) assert(id==21000+phase);return not bad('replaceCol') end
 function engineLoadDFF(path)
  assert(path==(phase==1 and HospitalInteriorConfig.dff or HospitalInteriorConfig.exitBarrier.dff))
  if not bad('dff') then return element('dff') end
 end
 function engineReplaceModel(_,id) assert(id==21000+phase,'base world model must not be replaced');return not bad('replaceModel') end
 function engineSetModelLODDistance(id,distance) assert(id==21000+phase and distance==200) end
 function createObject(id,x,y,z)
  assert(id==21000+phase)
  if phase==1 then assert(x==1500 and y==1500 and z==1200)
  else assert(math.abs(x-1479.3)<0.0001 and math.abs(y-1502.4)<0.0001 and z==1184.5,'barrier is behind the hospital front door') end
  if not bad('object') then local e=element('object');e.model=id;return e end
 end
 function setElementInterior(e,id) assert(e.kind=='object' and id==Fractions[1].interior);e.interior=id end
 function setElementDimension(e,id) assert(id==Fractions[1].dimension);e.dimension=id end
 function setElementDoubleSided() end
 function setElementCollisionsEnabled(_,on) assert(on) end
 function setElementFrozen(_,on) assert(on) end
 function setObjectBreakable(_,on) assert(not on) end
 function engineRestoreModel(id) restored['model'..id]=true end
 function engineRestoreCOL(id) restored['col'..id]=true end
 function engineFreeModel(id) assert(not freed[id],'slot freed once');freed[id]=true end
 function outputDebugString() errors=errors+1 end
 function outputChatBox() end
 dofile('resources/rp_fraction/interior/client.lua')
 handlers.onClientResourceStart()
 if failure=='none' then
  local objects=0
  for _,e in ipairs(elements) do if e.kind=='object' then
   objects=objects+1;assert(not e.dead and e.interior==1 and e.dimension==20001,'hospital and barrier exist only in hospital world')
  end end
  assert(objects==2 and not next(freed),'two independent active model slots')
 else assert(errors==1,'failed asset reports the problem once') end
 handlers.onClientResourceStop();handlers.onClientResourceStop()
 local count=0;for _ in pairs(freed) do count=count+1 end
 local expected=failure=='request' and 0 or ((failure=='none' or (failure:find('barrier_',1,true) and failure~='barrier_request')) and 2 or 1)
 assert(count==expected,'all successfully allocated slots freed on stop/failure')
 for _,e in ipairs(elements) do assert(e.dead,'all assets and objects released') end
 if failure=='none' then
  for _,id in ipairs({21001,21002}) do assert(restored['model'..id] and restored['col'..id],'both objects restore model and collision') end
 end
end
print('Custom hospital: shell/barrier isolation, solid collision, loading failures and full cleanup of both objects passed')
