dofile('resources/rp_fraction/skins/config.lua')
resourceRoot,localPlayer={},{}
local handlers,commands,loaded,restored,timers,chat,created={}, {},{}, {},{}, {},{}
local missing,failures={},{}
local errors,loads=0,0
function addEventHandler(name,_,fn) handlers[name]=fn end
function addCommandHandler(name,fn) commands[name]=fn end
function fileExists(path) return not missing[path] end
function getElementModel() return 151 end
function setTimer(fn,_,count) local timer={fn=fn,count=count};timers[#timers+1]=timer;return timer end
function isTimer(t) return t and not t.dead end
function killTimer(t) t.dead=true end
function outputChatBox(message) chat[#chat+1]=message end
local function element(path) local e={path=path};created[#created+1]=e;return e end
function engineLoadTXD(path) loads=loads+1;if failures.txd==path then return false end;return element(path) end
function engineImportTXD(txd,id) assert(SkinConfig.models[id].txd==txd.path);return failures.import~=id end
function engineLoadDFF(path) if failures.dff==path then return false end;return element(path) end
function engineReplaceModel(dff,id) assert(SkinConfig.models[id].dff==dff.path);if failures.replace==id then return false end;loaded[id]=dff;return true end
function engineRestoreModel(id) restored[id]=true;loaded[id]=nil end
function isElement(e) return type(e)=='table' and not e.destroyed end
function destroyElement(e) e.destroyed=true end
function outputDebugString() errors=errors+1 end
local function retries()
 local timer=timers[#timers]
 for i=1,timer.count do if not timer.dead then timer.fn() end end
end
local function contains(needle)
 for _,message in ipairs(chat) do if message:find(needle,1,true) then return true end end
 return false
end
local function stop()
 handlers.onClientResourceStop()
 for _,e in ipairs(created) do assert(e.destroyed,'all TXD/DFF elements must be released') end
 created={};chat={}
end
dofile('resources/rp_fraction/skins/models.lua')
handlers.onClientResourceStart()
local expected={[280]='p1',[281]='p2',[285]='p3',[283]='p4',[129]='pw1',[130]='pw2',[131]='pw3',[150]='pw4',[151]='pw5'}
for id,name in pairs(expected) do
 assert(SkinConfig.models[id].dff=='skins/'..name..'.dff' and SkinConfig.models[id].txd=='skins/'..name..'.txd','model and texture must use the matching uploaded pair')
 assert(loaded[id],'every configured replacement must load')
end
local initial=loads;retries();commands.checkskins()
assert(loads==initial and contains('Текущий ID: 151') and contains('151 (skins/pw5.dff): загружен'),'diagnosis reports successful imports without reloading them')
stop();assert(restored[129] and restored[130] and restored[131] and restored[151])
failures.dff='skins/pw2.dff';handlers.onClientResourceStart()
assert(loaded[129] and not loaded[130] and loaded[131] and errors==1,'one failed asset does not break other models')
retries();assert(contains('/checkskins'),'permanent failures reported without debugscript')
commands.checkskins();assert(contains('engineLoadDFF: skins/pw2.dff'),'diagnosis identifies exact failure stage and file')
stop();failures={import=151};handlers.onClientResourceStart();assert(not loaded[151])
failures={};retries();assert(loaded[151] and #chat==0,'transient engine import failure recovers automatically')
stop();missing['skins/pw1.txd']=true;handlers.onClientResourceStart();assert(not loaded[129])
commands.checkskins();assert(contains('нет файла skins/pw1.txd'))
missing={};handlers.onClientFileDownloadComplete('skins/pw1.txd',false);assert(not loaded[129])
handlers.onClientFileDownloadComplete('skins/pw1.txd',true);assert(loaded[129],'completed asset download retries missing replacement')
stop();failures={txd='skins/pw5.txd'};handlers.onClientResourceStart();commands.checkskins();assert(contains('engineLoadTXD: skins/pw5.txd'));stop()
failures={replace=151};handlers.onClientResourceStart();commands.checkskins();assert(contains('engineReplaceModel: skins/pw5.dff'));local timer=timers[#timers];stop();assert(timer.dead,'stop cancels pending retry timer')
print('Skin loader: exact IDs, staged errors, automatic recovery, file completion, chat diagnosis and full cleanup passed')
