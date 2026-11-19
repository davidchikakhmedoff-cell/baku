-- Place wrists in world space instead of guessing mirrored bone Euler angles.
-- GTA retains its ordinary torso/leg animation; only arm matrices are changed.
local tracked={}
local function add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
local function sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function mul(a,n) return {a[1]*n,a[2]*n,a[3]*n} end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function length(a) return math.sqrt(dot(a,a)) end
local function unit(a) local n=length(a);return n>0.00001 and mul(a,1/n) or {0,0,1} end
local function rotate(from,to)
 from,to=unit(from),unit(to)
 local cosine=math.max(-1,math.min(1,dot(from,to)))
 local axis=cross(from,to);local sine=length(axis)
 if sine<0.00001 then
  if cosine>0 then return function(v) return {v[1],v[2],v[3]} end end
  axis=cross(from,{1,0,0});if length(axis)<0.00001 then axis=cross(from,{0,0,1}) end
 end
 axis=unit(axis)
 return function(v) return add(add(mul(v,cosine),mul(cross(axis,v),sine)),mul(axis,dot(axis,v)*(1-cosine))) end
end
local function transformed(matrix,rotation,position)
 local result={}
 for i=1,3 do local row=rotation(matrix[i]);result[i]={row[1],row[2],row[3],0} end
 result[4]={position[1],position[2],position[3],1};return result
end
local function arm(player,ids,target,outward)
 local upper,lower,hand=getElementBoneMatrix(player,ids[1]),getElementBoneMatrix(player,ids[2]),getElementBoneMatrix(player,ids[3])
 if not upper or not lower or not hand then return end
 local shoulder,elbow,wrist=upper[4],lower[4],hand[4]
 local first,second=length(sub(elbow,shoulder)),length(sub(wrist,elbow))
 if first<0.001 or second<0.001 then return end
 local delta=sub(target,shoulder);local direction=unit(delta)
 local distance=math.max(math.abs(first-second)+0.001,math.min(first+second-0.001,length(delta)))
 target=add(shoulder,mul(direction,distance))
 local along=(first*first-second*second+distance*distance)/(2*distance)
 local bend=unit(sub(outward,mul(direction,dot(outward,direction))))
 local nextElbow=add(add(shoulder,mul(direction,along)),mul(bend,math.sqrt(math.max(0,first*first-along*along))))
 local upperRotation=rotate(sub(elbow,shoulder),sub(nextElbow,shoulder))
 local forearmRotation=rotate(sub(wrist,elbow),sub(target,nextElbow))
 setElementBoneMatrix(player,ids[1],transformed(upper,upperRotation,shoulder))
 setElementBoneMatrix(player,ids[2],transformed(lower,forearmRotation,nextElbow))
 setElementBoneMatrix(player,ids[3],transformed(hand,forearmRotation,target))
 -- Finger matrices are in world coordinates too; keep them attached to hands.
 for index=4,#ids do
  local matrix=getElementBoneMatrix(player,ids[index])
  if matrix then setElementBoneMatrix(player,ids[index],transformed(matrix,forearmRotation,add(target,forearmRotation(sub(matrix[4],wrist))))) end
 end
end
local function restore(player)
 if tracked[player] and isElement(player) and isElementStreamedIn(player) then updateElementRpHAnim(player) end
 tracked[player]=nil
end
local function track(player)
 if getElementType(player)=='player' and getElementData(player,'fraction:cuffed')==true then tracked[player]=true end
end
addEventHandler('onClientResourceStart',resourceRoot,function()
 for _,player in ipairs(getElementsByType('player',root,true)) do track(player) end
end)
addEventHandler('onClientElementStreamIn',root,function() track(source) end)
addEventHandler('onClientElementStreamOut',root,function() restore(source) end)
addEventHandler('onClientElementDestroy',root,function() tracked[source]=nil end)
addEventHandler('onClientElementDataChange',root,function(key)
 if key=='fraction:cuffed' then if getElementData(source,key)==true then track(source) else restore(source) end end
end)
addEventHandler('onClientPedsProcessed',root,function()
 for player in pairs(tracked) do
  if not isElement(player) or not isElementStreamedIn(player) or isPedDead(player) or getElementData(player,'fraction:cuffed')~=true then restore(player)
  else
   updateElementRpHAnim(player)
   local pelvis,body=getElementBoneMatrix(player,1),getElementMatrix(player)
   if pelvis and body then
    local cfg=FractionConfig.cuffPose
    local center=add(add(pelvis[4],mul(body[2],cfg.forward)),mul(body[3],cfg.height))
    local gap=mul(body[1],cfg.wristGap/2)
    arm(player,{22,23,24,25,26},sub(center,gap),add(mul(body[1],cfg.elbowSide),add(mul(body[2],cfg.elbowForward),mul(body[3],-cfg.elbowDown))))
    arm(player,{32,33,34,35,36},add(center,gap),add(mul(body[1],-cfg.elbowSide),add(mul(body[2],cfg.elbowForward),mul(body[3],-cfg.elbowDown))))
   end
  end
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,function() for player in pairs(tracked) do restore(player) end end)
