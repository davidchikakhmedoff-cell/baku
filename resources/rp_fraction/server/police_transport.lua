local addCommandHandler = FractionCommands and FractionCommands.add or addCommandHandler
local F=Fraction
local function ownPatrol(p)
 local config=FractionConfig.policeTransport
 if not F.active(p,2,config.rank) or F.cuffs[p] or isPedDead(p) then return false end
 local key=F.playerKeys[p];local v=key and F.vehicleByKey[key];local spec=v and F.vehicles[v]
 if not isElement(v) or not spec or spec.faction~=2 or not config.models[getElementModel(v)]
  or not F.hasVehicleKey(p,key) or isVehicleBlown(v) or not F.near(p,v,config.radius) then return false end
 local x,y,z=getElementVelocity(v)
 if (x*x+y*y+z*z)*180*180>=config.maxSpeed^2 then return false end
 return v
end
function F.commandPutCar(p,id)
 local config=FractionConfig.policeTransport
 if not F.active(p,2,config.rank) then F.notify(p,'Посадка задержанного доступна LSPD со 2 ранга на смене');return end
 if isPedInVehicle(p) then F.notify(p,'Выйдите и встаньте рядом со своей патрульной машиной');return end
 id=FractionRules.integer(id,1,2147483647)
 if not id then F.notify(p,'Используйте /putcar ID игрока');return end
 local target=F.player(id)
 if target==p or not F.account(target) or isPedDead(target) or F.jailed(target) then F.notify(p,'Задержанный не найден или недоступен');return end
 if not F.cuffs[target] then F.notify(p,'На игроке должны быть надеты наручники');return end
 if isPedInVehicle(target) then F.notify(p,'Игрок уже находится в транспорте');return end
 local v=ownPatrol(p)
 if not v then F.notify(p,'Подойдите вплотную к своей остановленной патрульной машине, ключи должны быть у вас');return end
 if not F.near(target,v,config.radius) then F.notify(p,'Задержанный должен стоять рядом с патрульной машиной');return end
 local max=getVehicleMaxPassengers(v);local seat
 for _,index in ipairs({2,3}) do if index<=max and not getVehicleOccupant(v,index) then seat=index;break end end
 if not seat then F.notify(p,'Задние пассажирские места заняты');return end
 if not F.throttle(p,'putcar') then F.notify(p,'Подождите перед повторной посадкой');return end
 if not warpPedIntoVehicle(target,v,seat) then F.notify(p,'Не удалось посадить задержанного');return end
 F.notify(p,'Вы посадили '..F.name(target)..' на заднее сиденье',true)
 F.notify(target,'Полицейский посадил вас в патрульную машину')
end
addCommandHandler('putcar',function(p,_,id) F.commandPutCar(p,id) end)
-- Used by the existing /eject for an officer standing beside their issued car.
function getPoliceEjectVehicle(p,target)
 if not F.account(p) or not F.account(target) or not F.cuffs[target] or isPedInVehicle(p) then return false end
 local v=ownPatrol(p)
 if not v or getPedOccupiedVehicle(target)~=v then return false end
 local seat=getPedOccupiedVehicleSeat(target)
 return (seat==2 or seat==3) and v or false
end
