local models,vehicles,patterns={},{},{}
local timer
local function destroy(e) if e and isElement(e) then destroyElement(e) end end
local function removeLights(v)
 local state=vehicles[v]
 if not state then return end
 if state.shader then engineRemoveShaderFromWorldTexture(state.shader,'*',v) end
 destroy(state.shader);destroy(state.texture);vehicles[v]=nil
end
local function addVehicle(v)
 local spec=FractionCarConfig.models[getElementModel(v)]
 if spec and spec.sirens and models[getElementModel(v)] and not vehicles[v] then vehicles[v]={} end
end
local function readPatterns(path)
 local file=fileOpen(path,true);if not file then return false end
 local content=fileRead(file,fileGetSize(file));fileClose(file)
 local json=fromJSON(content)
 return type(json)=='table' and FractionSirenPatterns.compile(json,FractionCarConfig.sirenState) or false
end
local function updateLights()
 local px,py,pz=getElementPosition(localPlayer)
 local interior,dimension=getElementInterior(localPlayer),getElementDimension(localPlayer)
 local now=getTickCount()
 for v,state in pairs(vehicles) do
  if not isElement(v) then removeLights(v)
  else
   local x,y,z=getElementPosition(v)
   local visible=getElementInterior(v)==interior and getElementDimension(v)==dimension
    and (px-x)^2+(py-y)^2+(pz-z)^2<=FractionCarConfig.sirenDistance^2
   local mode=tonumber(getElementData(v,'fraction:sirenMode'))
   local enabled=visible and (mode and mode>0 or (not mode and getVehicleSirensOn(v))) and not isVehicleBlown(v)
   local lights=patterns[getElementModel(v)]
   if visible and lights and not state.failed then
    if not state.shader then
     state.shader=dxCreateShader('cars/sirens.fx',1,0,false,'vehicle')
     state.texture=dxCreateTexture(64,1,'argb','clamp')
     if not state.shader or not state.texture then
      outputDebugString('[Fraction cars] Не удалось создать шейдер мигалок',1)
      destroy(state.shader);destroy(state.texture);state.shader=nil;state.texture=nil;state.failed=true
     else
      state.pixels=dxGetTexturePixels(state.texture)
      dxSetShaderValue(state.shader,'lightPalette',state.texture)
      dxSetShaderValue(state.shader,'lampBrightness',FractionCarConfig.sirenBrightness)
      dxSetShaderValue(state.shader,'lampOpacity',FractionCarConfig.sirenOpacity)
     end
    end
    if state.shader then
     if not state.applied then engineApplyShaderToWorldTexture(state.shader,'*',v);state.applied=true end
     if enabled and not state.enabled then state.started=now end
     if enabled or state.enabled~=enabled then
      local pixels=state.pixels
      for id=0,63 do
       local light=lights[id];local value=enabled and light and FractionSirenPatterns.sample(light,now-state.started) or 0
       local c=light and light.color or {0,0,0,0}
       dxSetPixelColor(pixels,id,0,c[1]*value,c[2]*value,c[3]*value,c[4]*value)
      end
      dxSetTexturePixels(state.texture,pixels)
     end
     state.enabled=enabled
    end
   elseif state.applied then
    engineRemoveShaderFromWorldTexture(state.shader,'*',v);state.applied=false;state.enabled=nil
   end
  end
 end
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 for id,spec in pairs(FractionCarConfig.models) do
  local txd=engineLoadTXD(spec.txd)
  local imported=txd and engineImportTXD(txd,id)
  local dff=imported and engineLoadDFF(spec.dff)
  if dff and engineReplaceModel(dff,id,true) then
   models[id]={txd=txd,dff=dff}
   if spec.sirens then
    patterns[id]=readPatterns(spec.sirens)
    if not patterns[id] or not next(patterns[id]) then outputDebugString('[Fraction cars] Не удалось прочитать анимацию '..spec.sirens,1);patterns[id]=nil end
   end
  else
   destroy(dff);destroy(txd);outputDebugString('[Fraction cars] Не удалось загрузить модель '..id..': '..spec.dff,1)
  end
 end
 for _,v in ipairs(getElementsByType('vehicle',root,true)) do addVehicle(v) end
 timer=setTimer(updateLights,FractionCarConfig.sirenInterval,0)
end)
addEventHandler('onClientElementStreamIn',root,function() if getElementType(source)=='vehicle' then addVehicle(source) end end)
addEventHandler('onClientElementStreamOut',root,function() removeLights(source) end)
addEventHandler('onClientElementDestroy',root,function() removeLights(source) end)
addEventHandler('onClientElementModelChange',root,function() removeLights(source);if getElementType(source)=='vehicle' and isElementStreamedIn(source) then addVehicle(source) end end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 if timer and isTimer(timer) then killTimer(timer) end
 for v in pairs(vehicles) do removeLights(v) end
 for id,state in pairs(models) do engineRestoreModel(id);destroy(state.dff);destroy(state.txd) end
 models={};patterns={}
end)
