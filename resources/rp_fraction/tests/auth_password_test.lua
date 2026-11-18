-- Exercise real auth handlers across device changes and console recovery.
dofile('resources/rp_core/systems/auth/config.lua')
root,resourceRoot={},{}
local player={data={},device='DEVICE_A'}
local events,commands={},{}
function addEvent() end
function addEventHandler(name,element,fn) events[name]=fn end
function addCommandHandler(name,fn) commands[name]=fn end
function isElement(e) return e==player end
function getElementData(p,k) return p.data[k] end
function setElementData(p,k,v) p.data[k]=v end
function getPlayerSerial(p) return p.device end
function getRealTime() return {timestamp=1000} end
function getTickCount() return 100 end
function hash(kind,value) return 'digest:'..value end
local function digest(password,serial) return hash('sha256',password..':'..serial..':'..AuthConfig.passwordSalt) end
local row={id=87,rp_name='Auth_Tester',password=digest('CorrectSecret','DEVICE_A'),serial='DEVICE_A',money=54321}
local accepted
function triggerClientEvent(p,event,root,ok) if event=='auth:response' then accepted=ok end end
function dbConnect() return {} end
function dbQuery(db,sql,...) return {sql=sql,args={...}} end
function dbPoll(q)
 if q.sql:find('PRAGMA',1,true) then
  local columns={};for _,key in ipairs({'pos_x','pos_y','pos_z','rotation','interior','dimension','health','armor','money','skin','weapons','has_position','last_position_at','rp_name','gender','level','experience','house_id','password_serial'}) do columns[#columns+1]={name=key} end;return columns
 end
 if q.sql:find('SELECT * FROM players',1,true) and q.args[1]==row.rp_name then return {row} end
 return {}
end
function dbExec(db,sql,...)
 local args={...}
 if sql:find('UPDATE players SET last_login',1,true) then row.serial=args[2];row.password_serial=args[4]
 elseif sql:find('SET password=?,password_serial=?',1,true) then row.password=args[1];row.password_serial=args[2]
 elseif sql:find('SET password_serial = serial',1,true) then row.password_serial=row.password_serial or row.serial end
 return true
end
function outputDebugString() end
function outputServerLog() end
dofile('resources/rp_core/systems/auth/server.lua')
events.onResourceStart()
source,client=player,player
local function login(secret) accepted=nil;events['auth:login']('Auth_Tester',secret,false);return accepted end
assert(login('CorrectSecret'),'original device accepts correct password')
player.device='DEVICE_B';assert(login('CorrectSecret'),'first login from another device accepted')
assert(row.serial=='DEVICE_B' and row.password_serial=='DEVICE_A','device tracking cannot overwrite credential salt')
assert(login('CorrectSecret'),'repeat login from new device remains valid')
assert(not login('WrongSecret'),'incorrect password still rejected')
row.password_serial='DEVICE_B';player.device='DEVICE_A'
assert(login('CorrectSecret') and row.password_serial=='DEVICE_A','legacy overwritten serial recoverable from original device with correct password')
row.password_serial='DEVICE_B';row.serial='DEVICE_B';player.device='DEVICE_B'
assert(not login('CorrectSecret'),'unknown original credential serial is never bypassed')
local before=row.password;commands.authreset(player,'authreset','Auth_Tester','NewSecret')
assert(row.password==before,'in-game players cannot reset credentials')
commands.authreset(false,'authreset','Auth_Tester','NewSecret')
assert(login('NewSecret') and not login('CorrectSecret'),'console recovery replaces password without bypass')
assert(row.id==87 and row.money==54321,'account identity and game data remain intact')
print('Auth password: device changes, repeat login, legacy recovery, wrong password and console-only reset passed')
