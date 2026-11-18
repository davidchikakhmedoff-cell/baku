local function inPrison(player)
 return isElement(player) and getElementType(player)=='player'
  and getElementInterior(player)==6
  and getElementDimension(player)==FractionConfig.dimensionBase+100
end
addEventHandler('onClientPlayerDamage',root,function(attacker)
 if inPrison(source) or inPrison(attacker) then cancelEvent() end
end,true,'high+20')
addEventHandler('onClientPlayerStealthKill',root,function(target)
 if inPrison(source) or inPrison(target) then cancelEvent() end
end,true,'high+20')
