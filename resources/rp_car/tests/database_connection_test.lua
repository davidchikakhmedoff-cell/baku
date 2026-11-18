-- Actual database wrappers must not call MTA SQL functions on a destroyed handle.
local f=assert(io.open('resources/rp_car/database.lua','rb'));local code=f:read('*a');f:close()
local connection={valid=true};local calls=0
function isElement(value) return value==connection and connection.valid end
function dbExec(handle) assert(isElement(handle));calls=calls+1;return true end
function dbQuery(handle) assert(isElement(handle));calls=calls+1;return {} end
function dbPoll() return {} end
assert(loadstring(code))()
RPCarDB.connection=connection
assert(RPCarDB.exec('SELECT 1'))
RPCarDB.query('SELECT 1');assert(calls==2)
connection.valid=false
assert(not RPCarDB.exec('UPDATE personal_vehicles SET fuel=0'))
assert(#RPCarDB.query('SELECT 1')==0)
assert(not RPCarDB.createVehicle({}))
assert(calls==2,'destroyed connection never reaches dbExec/dbQuery')
RPCarDB.connection=nil;assert(not RPCarDB.exec('SELECT 1'))
print('SQLite wrappers: valid, destroyed and missing connections handled safely')
