dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local player={cuffed=true,streamed=true}
local events,bones,updates={},{},0
function addEventHandler(name,_,fn) events[name]=fn end
function getElementsByType() return {player} end
function getElementType() return 'player' end
function getElementData(p) return p.cuffed end
function isElement(p) return p==player end
function isElementStreamedIn(p) return p.streamed end
function isPedDead() return false end
function getElementBoneRotation(p,bone) return unpack(bones[bone] or {0,0,0}) end
function setElementBoneRotation(p,bone,x,y,z) bones[bone]={x,y,z} end
function updateElementRpHAnim() updates=updates+1 end
function setPedAnimation() error('full-body animation is forbidden') end
dofile('resources/rp_fraction/client/cuff_pose.lua')
events.onClientResourceStart();events.onClientPedsProcessed()
local count=0
for bone in pairs(bones) do
 count=count+1;assert(bone==22 or bone==23 or bone==24 or bone==32 or bone==33 or bone==34,'only arms and wrists may change')
end
assert(count==6 and updates==1,'both arms posed after natural ped processing')
events.onClientPedsProcessed()
source=player;player.cuffed=false;events.onClientElementDataChange('fraction:cuffed')
for _,angles in pairs(bones) do assert(angles[1]==0 and angles[2]==0 and angles[3]==0,'uncuff restores original arm rotations') end
local before=updates;events.onClientPedsProcessed();assert(updates==before,'uncuffed player no longer processed')
player.cuffed=true;events.onClientElementDataChange('fraction:cuffed');events.onClientPedsProcessed()
events.onClientResourceStop()
for _,angles in pairs(bones) do assert(angles[1]==0 and angles[2]==0 and angles[3]==0,'resource stop restores arms') end
print('Cuff pose: arms only, no body animation, frame updates, uncuff and resource cleanup passed')
