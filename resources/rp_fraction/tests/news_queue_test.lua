dofile('resources/rp_fraction/fleet_config.lua');dofile('resources/rp_fraction/config.lua')
local player={id=1};local deleted={}
function getResourceFromName() return {} end
function getResourceState() return 'running' end
function getElementsByType() return {player} end
function getElementData() return true end
function isElement(p) return p==player end
function setElementData() end
exports={rp_core={getAuthPlayerId=function(self,p) return p.id end,
 AuthDBExec=function(self,sql,id) if sql:find('DELETE FROM fraction_ads',1,true) then assert(id,'must not clear whole queue');deleted[id]=true end;return true end,
 AuthDBQuery=function(self,sql)
  if sql:find('PRAGMA table_info',1,true) then return {{name='gear_issued'}} end
  if sql:find('SELECT id,account_id FROM fraction_ads',1,true) then return {{id=11,account_id=1},{id=22,account_id=2}} end
  return {}
 end}}
assert(loadfile('resources/rp_fraction/server/database.lua'))()
FractionDB.init()
assert(not deleted[11] and deleted[22],'resource restart preserves online author, removes offline author')
function addEvent() end
function addEventHandler() end
root,resourceRoot={},{}
assert(loadfile('resources/rp_fraction/server/main.lua'))()
Fraction.account=function(p) return p.id end
Fraction.clearCuffs=function() end
Fraction.state=function() return {} end
Fraction.endDuty=function() end
Fraction.member=function() return nil end
Fraction.sessions={[player]={account=1}}
Fraction.justice={}
function getPlayerWantedLevel() return 0 end
Fraction.disconnect(player,true)
assert(not deleted[1],'resource stop must not remove a connected author\'s pending ad')
Fraction.disconnect(player)
assert(deleted[1],'actual disconnection removes pending ad')
print('News queue: restart retains connected authors; disconnect and startup remove offline authors')
