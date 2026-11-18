local file=assert(io.open('resources/rp_core/systems/hud/client.lua','rb'))
local source=file:read('*a');file:close()
local helper=assert(source:match('(local function drawWantedStars.-)local function drawHud'))
local level,draws=0,{}
localPlayer={}
function getPlayerWantedLevel() return level end
function isElement() return true end
function s(n) return n end
function tocolor(...) return {...} end
function dxDrawImage(x,y,w,h,texture,rotation,ox,oy,color)
 draws[#draws+1]={x=x,y=y,w=w,h=h,color=color}
end
local draw=assert(loadstring('local wantedStar={}\n'..helper..'return drawWantedStars'))()
draw(1000,100,255);assert(#draws==0,'zero wanted hides stars')
for stars=1,6 do
 level=stars;draws={};draw(1000,100,255)
 assert(#draws==6,'wanted has six slots')
 for i,item in ipairs(draws) do
  assert((item.color[1]==255)==(i<=stars),'exact number of active gold stars')
  assert(item.y==100 and item.x+item.w<=1000,'stars fit below HUD')
 end
end
level=99;draws={};draw(1000,100,255);assert(#draws==6 and draws[6].color[1]==255,'wanted clamps to six stars')
print('Wanted HUD: hidden at zero, six slots, active counts, placement and cap passed')
