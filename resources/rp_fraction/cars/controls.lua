local pending
local function driverVehicle()
 local v=getPedOccupiedVehicle(localPlayer)
 local spec=v and FractionCarConfig.models[getElementModel(v)]
 if not spec or not spec.sirens or not isPedInVehicle(localPlayer) or getPedOccupiedVehicleSeat(localPlayer)~=0
  or getVehicleOccupant(v,0)~=localPlayer or isPedDead(localPlayer) or isVehicleBlown(v)
  or getElementData(localPlayer,'auth:loggedIn')~=true or getElementData(localPlayer,'fraction:cuffed') then return false end
 return v
end
local function blocked()
 if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() or isMTAWindowActive() then return true end
 local r=getResourceFromName('rp_core')
 if isCursorShowing() and r and getResourceState(r)=='running' then
  local ok,value=pcall(function() return exports.rp_core:isTextInputActive() or exports.rp_core:isAnyBlockingUIOpen() end)
  if ok and value then return true end
 end
 return false
end
local function restoreSiren(v)
 if isElement(v) then
  local mode=tonumber(getElementData(v,'fraction:sirenMode'))
  if mode and getVehicleSirensOn(v)~=(mode==2) then setVehicleSirensOn(v,mode==2) end
 end
end
local function finish()
 local state=pending;pending=nil
 if not state then return end
 if state.timer and isTimer(state.timer) then killTimer(state.timer) end
 if state.holding then setPedControlState(localPlayer,'horn',false) end
 restoreSiren(state.vehicle)
 return state
end
addEventHandler('onClientKey',root,function(key,pressed)
 if pending and not pressed and key==pending.key then
  cancelEvent()
  local state=finish()
  if not state.holding and driverVehicle()==state.vehicle and not blocked() then triggerServerEvent('fraction:cycleSirens',resourceRoot) end
  return
 end
 if not pressed or (key~='h' and not (getBoundKeys('horn') or {})[key]) then return end
 local v=driverVehicle()
 if not v or blocked() then return end
 cancelEvent() -- Suppress GTA's single-press siren toggle; held horn is restored below.
 if pending then return end
 local state={key=key,vehicle=v};pending=state
 state.timer=setTimer(function()
  if pending~=state then return end
  if driverVehicle()~=v or blocked() then finish();return end
  state.holding=true;setPedControlState(localPlayer,'horn',true)
 end,FractionCarConfig.hornHoldMs,1)
end)
addEventHandler('onClientPreRender',root,function()
 if not pending then return end
 if driverVehicle()~=pending.vehicle or blocked() then finish();return end
 if pending.holding then
  -- Native horn processing must not change the selected siren mode.
  restoreSiren(pending.vehicle)
 end
end)
addEventHandler('onClientVehicleExit',root,function(p) if p==localPlayer then finish() end end)
addEventHandler('onClientPlayerWasted',localPlayer,finish)
addEventHandler('onClientResourceStop',resourceRoot,finish)

addCommandHandler('pdcontrols',function()
 local v=getPedOccupiedVehicle(localPlayer)
 local keys={};for key in pairs(getBoundKeys('horn') or {}) do keys[#keys+1]=key end;table.sort(keys)
 outputChatBox('[PD controls] input loaded; H + '..table.concat(keys,', ')..'; driver='..tostring(driverVehicle()~=false)..'; UI='..tostring(blocked()),180,215,240)
 if isElement(v) then
  outputChatBox('[PD controls] model='..getElementModel(v)..'; mode='..tostring(getElementData(v,'fraction:sirenMode'))..'; native siren='..tostring(getVehicleSirensOn(v)),180,215,240)
 end
end)
