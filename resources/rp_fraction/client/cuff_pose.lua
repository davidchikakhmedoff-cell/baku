-- Modify arms after GTA processes the normal skeleton. Legs, torso and head
-- keep their ordinary movement; no full-body animation is applied.
local tracked={}
local function restore(player)
 local saved=tracked[player]
 if saved and isElement(player) and isElementStreamedIn(player) then
  for bone,angles in pairs(saved) do setElementBoneRotation(player,bone,unpack(angles)) end
  updateElementRpHAnim(player)
 end
 tracked[player]=nil
end
local function track(player)
 if getElementType(player)=='player' and getElementData(player,'fraction:cuffed')==true then tracked[player]=tracked[player] or {} end
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 for _,player in ipairs(getElementsByType('player',root,true)) do track(player) end
end)
addEventHandler('onClientElementStreamIn',root,function() track(source) end)
addEventHandler('onClientElementStreamOut',root,function() restore(source) end)
addEventHandler('onClientElementDestroy',root,function() tracked[source]=nil end)
addEventHandler('onClientElementDataChange',root,function(key)
 if key~='fraction:cuffed' then return end
 if getElementData(source,key)==true then track(source) else restore(source) end
end)
addEventHandler('onClientPedsProcessed',root,function()
 for player,saved in pairs(tracked) do
  if not isElement(player) or not isElementStreamedIn(player) or isPedDead(player) or getElementData(player,'fraction:cuffed')~=true then restore(player)
  else
   for bone,angles in pairs(FractionConfig.cuffPose) do
    local x,y,z=getElementBoneRotation(player,bone)
    if x then
     saved[bone]=saved[bone] or {x,y,z}
     setElementBoneRotation(player,bone,unpack(angles))
    end
   end
   updateElementRpHAnim(player)
  end
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 for player in pairs(tracked) do restore(player) end
end)
