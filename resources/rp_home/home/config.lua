HomeSystemConfig = {
    dimensionBase = HomeConfig.dimensionBase,
    marker = {
        type = "arrow",
        zOffset = 0.7,
        size = 0.9,
        alpha = 205,
        color = {255, 220, 0}
    },
    interiorMarker = {
        type = "arrow",
        zOffset = 0.7,
        size = 0.9,
        alpha = 205,
        color = {255, 220, 0}
    },
    enterDistance = HomeConfig.enterDistance,
    markerDistance = HomeConfig.markerDistance,
    stateSellPercent = HomeConfig.stateSellPercent,
    salePrice = HomeConfig.salePrice,
    interiors = HomeConfig.interiors
}

function HomeSystemConfig.getInterior(key)
    for _, item in ipairs(HomeSystemConfig.interiors or {}) do
        if item.key == key then return item end
    end
    return (HomeSystemConfig.interiors or {})[1]
end
