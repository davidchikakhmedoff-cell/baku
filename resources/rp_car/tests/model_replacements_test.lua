dofile('resources/rp_car/handling/base.lua')
dofile('resources/rp_car/dealerships.lua')
dofile('resources/rp_car/vehicles.lua')
dofile('resources/rp_fraction/cars/config.lua')
root,resourceRoot={},{}
local models={aston_martin_db9=602,bmw_f12=480,bmw_i8=451,ford_taurus=550,
 mercedes_sprinter=413,skoda_octavia_universal=458,volkswagen_passat_cc=445}
local occupied={}
for model in pairs(FractionCarConfig.models) do occupied[model]='rp_fraction' end
-- Include existing model resources too: a new ID must never overwrite one.
for _,folder in ipairs({'audi_r8','bmw_e46','bmw_e60','bmw_e70','bmw_f10','bmw_f90','lexus_ls400','mercedes_c63_coupe','mercedes_clk_55','mercedes_ml63_w164','toyota_sequoia'}) do
 local file=assert(io.open('resources/[cars]/'..folder..'/client.lua'));local code=file:read('*a');file:close()
 local model=assert(tonumber(code:match('engineReplaceModel%(dff,(%d+)%)')))
 assert(not occupied[model],'pre-existing replacement IDs must be unique');occupied[model]=folder
end
for folder,model in pairs(models) do
 assert(not occupied[model],'new replacement collides with '..tostring(occupied[model]));occupied[model]=folder
 local cfg=VehicleHandling[model]
 assert(cfg.modelResource==folder and cfg.wheelSize.front_axle>0 and cfg.wheelSize.rear_axle>0,'model has resource-scoped physical wheel sizes')
 assert(getConfiguredVehicleName(model)==folder:gsub('_',' '):upper(),'canonical label matches folder without underscores')
 for _,failure in ipairs({'none','txd','dff','replace'}) do
  local handlers,created,restored,errors={}, {},0,0
  function addEventHandler(name,_,fn) handlers[name]=fn end
  function isElement(e) return type(e)=='table' and not e.dead end
  function destroyElement(e) assert(not e.dead);e.dead=true end
  local function element() local e={};created[#created+1]=e;return e end
  function engineLoadTXD(path) assert(path=='vehicle.txd');if failure~='txd' then return element() end end
  function engineImportTXD(_,id) assert(id==model);return true end
  function engineLoadDFF(path)
   local file=assert(io.open('resources/[cars]/'..folder..'/'..path,'rb'));file:close()
   if failure~='dff' then return element() end
  end
  function engineReplaceModel(_,id) assert(id==model);return failure~='replace' end
  function engineRestoreModel(id) assert(id==model);restored=restored+1 end
  function outputDebugString() errors=errors+1 end
  dofile('resources/[cars]/'..folder..'/client.lua')
  handlers.onClientResourceStart();handlers.onClientResourceStop()
  assert(restored==(failure=='none' and 1 or 0),'only a successfully replaced model may be restored')
  assert(errors==(failure=='none' and 0 or 1),'model loading failure must be visible')
  for _,e in ipairs(created) do assert(e.dead,'stop/failure must release all loaded assets') end
 end
end
assert(VehicleModelNames[416]=='AMBULANCE' and VehicleModelNames[582]=='NEWS CAR' and not VehicleModelNames[523],'service names updated while motorcycle keeps stock name')
print('Replacement registry: unique IDs, canonical names, exact DFF case, actual loader success/failure and cleanup passed')
