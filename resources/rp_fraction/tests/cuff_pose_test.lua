dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
root,resourceRoot={},{}
local player={cuffed=true,streamed=true}
local events,bones,updates,writes={},{},0,{}
local function matrix(x,y,z) return {{1,0,0,0},{0,1,0,0},{0,0,1,0},{x,y,z,1}} end
local natural={[1]=matrix(0,0,1),[22]=matrix(0.2,0,1.4),[23]=matrix(0.5,0,1.4),[24]=matrix(0.8,0,1.4),[25]=matrix(0.85,0,1.4),[26]=matrix(0.9,0,1.4),[32]=matrix(-0.2,0,1.4),[33]=matrix(-0.5,0,1.4),[34]=matrix(-0.8,0,1.4),[35]=matrix(-0.85,0,1.4),[36]=matrix(-0.9,0,1.4)}
local function copy(m) local n={};for i,row in ipairs(m) do n[i]={unpack(row)} end;return n end
function addEventHandler(name,_,fn) events[name]=fn end
function getElementsByType() return {player} end
function getElementType() return 'player' end
function getElementData(p) return p.cuffed end
function isElement(p) return p==player end
function isElementStreamedIn(p) return p.streamed end
function isPedDead() return false end
function getElementMatrix() return matrix(0,0,0) end
function getElementBoneMatrix(p,bone) return bones[bone] and copy(bones[bone]) end
function setElementBoneMatrix(p,bone,m) writes[bone]=true;bones[bone]=copy(m) end
function updateElementRpHAnim()
 updates=updates+1;for bone,m in pairs(natural) do bones[bone]=copy(m) end
end
function setPedAnimation() error('full-body animation is forbidden') end
function setElementBoneRotation() error('guessed Euler angles are forbidden') end
dofile('resources/rp_fraction/client/cuff_pose.lua')
events.onClientResourceStart();events.onClientPedsProcessed()
local allowed={[22]=true,[23]=true,[24]=true,[25]=true,[26]=true,[32]=true,[33]=true,[34]=true,[35]=true,[36]=true}
for bone in pairs(writes) do assert(allowed[bone],'only arms/hands/fingers may change') end
local right,left=bones[24][4],bones[34][4]
assert(math.abs(right[1]-left[1])<=0.071,'wrists are together')
for _,wrist in ipairs({right,left}) do assert(wrist[2]>0.15 and wrist[3]<1.01 and wrist[3]>0.9,'wrists are in front of hips, never above the head') end
local function distance(a,b) return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end
assert(math.abs(distance(bones[22][4],bones[23][4])-0.3)<0.0001 and math.abs(distance(bones[23][4],bones[24][4])-0.3)<0.0001,'arm lengths preserved')
events.onClientPedsProcessed();assert(bones[24][4][3]<1.01,'pose is stable across frames')
source=player;player.cuffed=false;events.onClientElementDataChange('fraction:cuffed')
assert(bones[24][4][1]==natural[24][4][1],'uncuff restores natural skeleton')
local before=updates;events.onClientPedsProcessed();assert(updates==before,'uncuffed player no longer processed')
player.cuffed=true;events.onClientElementDataChange('fraction:cuffed');events.onClientPedsProcessed();events.onClientResourceStop()
assert(bones[34][4][1]==natural[34][4][1],'stop restores natural skeleton')
print('Cuff pose: wrist targets near hips, joint lengths, arms only, no animations/Euler guesses and cleanup passed')
-- Heading must rotate wrist targets with the player, not leave them in world axes.
for _,m in pairs(natural) do
 for i=1,4 do local x,y=m[i][1],m[i][2];m[i][1],m[i][2]=-y,x end
end
function getElementMatrix() return {{0,1,0,0},{-1,0,0,0},{0,0,1,0},{0,0,0,1}} end
player.cuffed=true;source=player;events.onClientElementDataChange('fraction:cuffed');events.onClientPedsProcessed()
assert(bones[24][4][1]<-0.15 and bones[34][4][1]<-0.15 and math.abs(bones[24][4][2]-bones[34][4][2])<0.071,'wrist target follows character heading')
events.onClientResourceStop()
