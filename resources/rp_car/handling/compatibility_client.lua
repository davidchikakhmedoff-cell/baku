-- Model wheel size changes ride height and wheel collision; visual scale alone does not.
local originals,donors={},{}
local timer,stopping,warned
local axles={'front_axle','rear_axle'}
local function sizes(model)
 local result={}
 for _,axle in ipairs(axles) do result[axle]=getVehicleModelWheelSize(model,axle) end
 return result
end
local function apply(model,values)
 for _,axle in ipairs(axles) do
  local value=values[axle]
  if type(value)=='number' and value>0 and math.abs(getVehicleModelWheelSize(model,axle)-value)>0.00001 then
   setVehicleModelWheelSize(model,axle,value)
  end
 end
end
local function update()
 timer=nil
 if stopping then return end
 for model,config in pairs(VehicleHandling or {}) do
  if config.wheelSizeFromModel or type(config.wheelSize)=='table' then
   local resource=config.modelResource and getResourceFromName(config.modelResource)
   local active=not config.modelResource or (resource and getResourceState(resource)=='running')
   if type(getVehicleModelWheelSize)~='function' or type(setVehicleModelWheelSize)~='function' then
    if active and not warned then
     warned=true
     outputChatBox('[Автомобили] Для правильной высоты колёс обновите MTA до актуальной версии 1.6: недоступна настройка размера колёс модели.',239,140,100)
    end
   elseif active then
    originals[model]=originals[model] or sizes(model)
    local values=config.wheelSize
    if config.wheelSizeFromModel then
     local reference=config.wheelSizeFromModel
     donors[reference]=donors[reference] or sizes(reference)
     values=donors[reference]
    end
    apply(model,values)
   elseif originals[model] then apply(model,originals[model]) end
  end
 end
end
local function schedule()
 if stopping then return end
 if timer and isTimer(timer) then killTimer(timer) end
 -- Run after replacement resources have finished loading/restoring their DFFs.
 timer=setTimer(update,50,1)
end
addEventHandler('onClientResourceStart',root,schedule)
addEventHandler('onClientResourceStop',root,schedule)
addEventHandler('onClientResourceStop',resourceRoot,function()
 stopping=true
 if timer and isTimer(timer) then killTimer(timer) end
 if type(setVehicleModelWheelSize)=='function' and type(getVehicleModelWheelSize)=='function' then
  for model,values in pairs(originals) do apply(model,values) end
 end
end)
