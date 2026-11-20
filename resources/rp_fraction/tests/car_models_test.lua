dofile('resources/rp_fraction/cars/config.lua');dofile('resources/rp_fraction/cars/patterns.lua')
assert(FractionCarConfig.models[596].dff=='cars/prepared/596.dff' and not FractionCarConfig.models[599],'Explorer replaces copcarla patrol cars and leaves Police Ranger stock')
assert(FractionCarConfig.models[497].dff=='cars/vert_pd/vert_pd.dff','PD helicopter only')
assert(FractionCarConfig.models[416].dff=='cars/ambulance/ambulance.dff' and FractionCarConfig.models[582].dff=='cars/news/newsvan.dff' and FractionCarConfig.models[523].dff=='cars/copbike/copbike.dff','uploaded service replacements keep original faction fleet IDs')
local P=FractionSirenPatterns
local fixture={references={colors={blue={red=2,green=96,blue=255,alpha=128}}},states={emergency={
 ['1']={color='blue',state=1,pattern={100,100}},['2']={color={red=255,green=0,blue=0},state=0,pattern={100,200,100}},
 ['3']={color='blue',state=1,pattern={}},['4']={color='blue',state=1,inertia=0.5,pattern={100,100}}
}}}
fixture.states['1.Emergency']=fixture.states.emergency
local compiled=P.compile(fixture,'emergency')
assert(compiled[1].color[3]==255 and P.sample(compiled[1],0)==1 and P.sample(compiled[1],100)==0 and P.sample(compiled[1],200)==1,'color references and pulse boundaries')
assert(P.sample(compiled[2],0)==0 and P.sample(compiled[2],100)==1 and P.sample(compiled[2],400)==1 and P.sample(compiled[2],800)==0,'odd pattern flips on alternating cycles')
assert(P.sample(compiled[3],99999)==1 and P.sample(compiled[4],25)==0.5,'steady lights and inertia fade')
local referenced={references={colors={red={red=255,green=0,blue=0},blue={red=0,green=0,blue=255}},strobe={state=1,pattern={500,500},color='red'}},states={['1.Emergency']={['25']={reference='strobe',colors={{410,'blue'}}}}}}
local lamp=P.compile(referenced,'1.Emergency')[25]
assert(lamp and P.sample(lamp,0)==1 and P.sample(lamp,500)==0,'named emergency state inherits reference properties')
assert(P.color(lamp,409)[1]==255 and P.color(lamp,410)[3]==255 and P.color(lamp,1000)[1]==255,'Charger color keyframe changes at configured offset and resets each pulse cycle')

root,resourceRoot,localPlayer={},{},{model=0}
local car={model=596,siren=false}
local heli={model=497};local sedan={model=599}
local handlers,elements,timers,restored={}, {},{},{}
local clock=0;local applied,removed=0,0;local palette
local shaderFail,chatErrors=false,0
function addEventHandler(name,_,fn) handlers[name]=fn end
function getElementModel(e) return e.model end
function getElementData(e,key) return e[key] end
function getElementType(e) return e.model and 'vehicle' or 'other' end
function getElementPosition() return 0,0,0 end
function getElementInterior() return 0 end
function getElementDimension(e) return e.dimension or 0 end
function getElementsByType() return {car,heli,sedan} end
function isElementStreamedIn() return true end
function getTickCount() return clock end
function isElement(e) return type(e)=='table' and not e.dead end
local function element(kind) local e={kind=kind};elements[#elements+1]=e;return e end
function destroyElement(e) e.dead=true end
function engineLoadTXD() return element('txd') end
function engineImportTXD() return true end
function engineLoadDFF() return element('dff') end
function engineReplaceModel(_,id) assert(id==596 or id==597 or id==598 or id==497 or id==416 or id==582 or id==523);return true end
function engineRestoreModel(id) restored[id]=true end
function fileOpen(path) return assert(io.open('resources/rp_fraction/'..path,'rb')) end
function fileGetSize(f) local n=f:seek('end');f:seek('set');return n end
function fileRead(f,n) return f:read(n) end
function fileClose(f) f:close() end
function fromJSON(content) assert(content:find('emergency',1,true) or content:find('Emergency',1,true));return fixture end
function outputDebugString(message) if not shaderFail then error(message) end end
function outputChatBox(message) assert(message:find('Не удалось загрузить эффект',1,true));chatErrors=chatErrors+1 end
function setTimer(fn,ms) assert(ms==25);local t=element('timer');t.fn=fn;timers[#timers+1]=t;return t end
function isTimer(e) return isElement(e) end
function killTimer(e) e.dead=true end
function getVehicleSirensOn(v) return v.siren end
function isVehicleBlown(v) return v.blown end
function dxCreateShader(path)
 assert(path=='cars/sirens.fx')
 if shaderFail then return false,'unsupported shader' end
 local file=assert(io.open('resources/rp_fraction/'..path,'rb'));local shader=file:read('*a');file:close()
 -- Lamp ID is sampled from dedicated masks, never vehicle material lighting.
 assert(shader:find('mask.r*255.0',1,true) and not shader:find('materialState',1,true),'shader must use stable texture IDs independently of GTA material color')
 return element('shader'),'SirenMaterials'
end
function dxCreateTexture(w,h) assert(w==64 and h==1);return element('texture') end
function dxGetTexturePixels() return {} end
function dxSetPixelColor(pixels,x,y,r,g,b,a) pixels[x]={r,g,b,a} end
function dxSetTexturePixels(_,pixels) palette=pixels end
function dxSetShaderValue() end
function engineApplyShaderToWorldTexture(_,pattern,v) assert(v==car and pattern=='rp_pd_els_*','ordinary headlight/body textures must not be overridden');applied=applied+1 end
function engineRemoveShaderFromWorldTexture(_,pattern,v) assert(v==car and pattern=='rp_pd_els_*');removed=removed+1 end
dofile('resources/rp_fraction/cars/client.lua');handlers.onClientResourceStart()
local tick=timers[1].fn;tick();assert(palette[1][4]==0,'siren off hides lamp materials')
car['fraction:sirenMode']=1;tick();assert(palette[1][4]==128 and not car.siren,'silent mode illuminates lamps without native siren audio')
car['fraction:sirenMode']=0;tick();assert(palette[1][4]==0,'off mode without native siren is dark')
car.siren=true;tick();assert(palette[1][4]==128,'native siren remains visible when custom mode is stale/off')
car.siren=false;tick()
car['fraction:sirenMode']=nil
car.siren=true;tick();assert(palette[1][3]==255 and palette[1][4]==128,'native siren enables JSON pattern')
clock=100;tick();assert(palette[1][4]==0,'configured duration changes lamp state')
car.siren=false;tick();assert(palette[3][4]==0,'turning siren off also stops steady lights')
car.siren=true;clock=200;tick();assert(palette[1][4]==128,'restart resets phase')
car.blown=true;tick();assert(palette[1][4]==0,'explosion switches lights off')
assert(applied==1,'reuse one shader across pulse updates')
car.blown=false;tick();car.dimension=1;tick();car.siren=false;car.dimension=0;tick()
assert(palette[1][4]==0 and applied==1 and removed==0,'invisible/distant cars retain an unlit mask shader so encoded textures never appear raw')
source=car;handlers.onClientElementStreamOut();assert(removed==1,'stream out detaches shader')
car.blown=false;handlers.onClientElementStreamIn();tick();assert(applied==2,'stream in restores animation')
handlers.onClientResourceStop();assert(restored[596] and restored[597] and restored[598] and restored[497] and restored[416] and restored[582] and restored[523],'restore both stock models on stop')
for _,e in ipairs(elements) do assert(e.dead,'all graphics elements and timer must be released') end
shaderFail=true;handlers.onClientResourceStart();timers[#timers].fn();timers[#timers].fn()
assert(chatErrors==1,'shader failure is visible in chat once without debugscript')
handlers.onClientResourceStop()
for _,e in ipairs(elements) do assert(e.dead,'failed shader resources also released') end
print('PD car models: mapping, JSON pulse semantics, siren toggle, explosion, streaming, reuse and cleanup passed')
