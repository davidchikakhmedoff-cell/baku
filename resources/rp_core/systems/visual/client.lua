local function disableDistractingEffects()
    if type(setBlurLevel) == "function" then setBlurLevel(0) end
    if type(setHeatHaze) == "function" then setHeatHaze(0) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    disableDistractingEffects()
    setTimer(disableDistractingEffects, 3000, 0)
end)

