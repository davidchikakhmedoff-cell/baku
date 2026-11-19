-- Inspect the loaded resources, not their updated files on disk. MTA keeps an
-- included resource's old Lua VM/exports until that resource is reloaded.
FractionDependencies={blocked=false}
local D=FractionDependencies
local required={
 {name='rp_core',exports={'AuthDBQuery','AuthDBExec','getAuthPlayerId','getPlayerByDynamicID','getPlayerDynamicID','takeAuthPlayerMoney','getAuthPlayerBalance','isCoreFounder','sendCoreNotification'}},
 {name='rp_car',exports={'registerFactionVehicle','unregisterFactionVehicle','getConfiguredVehicleName'}}
}
function D.hasExports(name,names)
 local resource=getResourceFromName(name)
 if not resource or getResourceState(resource)~='running' then return false,name..' is not running' end
 local available={}
 for _,fn in ipairs(getResourceExportedFunctions(resource) or {}) do available[fn]=true end
 for _,fn in ipairs(names) do
  if not available[fn] then return false,name..':'..fn..' is not loaded' end
 end
 return true
end
local function warn(reason)
 if D.lastReason~=reason then
  D.lastReason=reason
  outputDebugString('[Fraction] Waiting for dependencies: '..reason..'. Update rp_core/rp_car and restart them with rp_fraction stopped, then start rp_fraction. Restarting rp_fraction alone does not reload dependencies.',2)
 end
 return false
end
function D.ready()
 for _,dependency in ipairs(required) do
  local ok,reason=D.hasExports(dependency.name,dependency.exports)
  if not ok then return warn(reason) end
 end
 if D.blocked then return warn('rp_car vehicle registration failed; reload rp_car before retrying') end
 if D.lastReason then outputDebugString('[Fraction] Dependencies ready; resuming startup and fleet creation.',3);D.lastReason=nil end
 return true
end
function D.rejectVehicleAdapter()
 D.blocked=true
 return warn('rp_car vehicle registration failed; reload rp_car before retrying')
end
addEventHandler('onResourceStart',root,function(resource)
 if resource==getResourceFromName('rp_car') then D.blocked=false end
end)
