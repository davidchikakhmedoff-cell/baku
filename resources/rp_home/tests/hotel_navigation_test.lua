-- Run from repository root using Lua 5.1. Exercise the actual navigation helpers.
local file=assert(io.open('resources/rp_home/client.lua','rb'))
local source=file:read('*a'):gsub('\r\n','\n');file:close()
local begin=assert(source:match('local function beginWindow%(.-\nend'))
local extend=assert(source:match('local function openExtendHotel%(.-\nend'))
local back=assert(source:match('elseif id == "backHouse" then ([^\n]+)'))
local factory=assert(loadstring([[
local window,windowContext,selectedHouse,buttons,inputs,formValues,inputStates
local function acquireHomeUI() return true end
]]..begin..'\n'..extend..'\n'..[[
return function(context)
    local hotel={id=-1,property_type='hotel'}
    beginWindow('house',hotel,context)
    openExtendHotel(hotel)
    assert(window=='extendHotel' and windowContext==context)
    assert(formValues.extendDays=='1')
]]..back..[[
    assert(window=='house' and selectedHouse==hotel)
    assert(windowContext==context,'Back must preserve the interior-marker context')
end
]]))()
factory({hotelInside=true,marker={}})
factory(nil)
print('Hotel navigation: interior context and exterior context round trips passed')
