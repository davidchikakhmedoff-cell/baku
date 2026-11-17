local menu, vehicle, selected, delivered, requested, dragging
local UI_NAME="car_fuel"
local hits={}
local titleFont, fontW, fontH
local function core() local r=getResourceFromName("rp_core");return r and getResourceState(r)=="running" end
local function close(cancel)
    if not menu then return end
    if cancel then triggerServerEvent("car:fuelCancel",resourceRoot) end
    menu,vehicle,dragging,delivered,requested=nil,nil,nil,nil,nil
    if core() then exports.rp_core:closeUI(UI_NAME) else showCursor(false);guiSetInputMode("allow_binds") end
end
local function velocity(v)
    local x,y,z=getElementVelocity(v);return math.sqrt(x*x+y*y+z*z)*180
end
local function allowed()
    if not menu or not isElement(vehicle) then return false end
    local x,y,z=getElementPosition(vehicle)
    return menu and isElement(vehicle) and getPedOccupiedVehicle(localPlayer)==vehicle
        and getPedOccupiedVehicleSeat(localPlayer)==0 and not isPedDead(localPlayer)
        and velocity(vehicle)<1 and not getVehicleEngineState(vehicle)
        and menu.station and getDistanceBetweenPoints3D(x,y,z,menu.station.x,menu.station.y,menu.station.z) <= menu.station.radius
        and getElementInterior(vehicle)==0 and getElementDimension(vehicle)==0
end
local function requestMenu()
    if not CarInteraction.ready(localPlayer) then return end
    if menu or isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() or isMTAWindowActive() then return end
    if core() and exports.rp_core:isAnyBlockingUIOpen() then return end
    local v=getPedOccupiedVehicle(localPlayer)
    if v and getPedOccupiedVehicleSeat(localPlayer)==0 then triggerServerEvent("car:fuelOpen",resourceRoot) end
end
addEvent("car:fuelMenu",true)
addEventHandler("car:fuelMenu",resourceRoot,function(v,data)
    if menu or not isElement(v) then return end
    if core() then
        if not exports.rp_core:openUI(UI_NAME,true,"no_binds_when_editing") then return end
    else showCursor(true);guiSetInputMode("no_binds_when_editing") end
    menu,vehicle=data,v
    selected=math.min(10,math.max(0,data.capacity-data.fuel))
end)
addEvent("car:fuelProgress",true)
addEventHandler("car:fuelProgress",resourceRoot,function(amount,total,fuel)
    if not menu then return end
    delivered,requested=amount,total
    menu.fuel=fuel
end)
addEvent("car:fuelClosed",true)
addEventHandler("car:fuelClosed",resourceRoot,function() close(false) end)
local function render()
    if not menu then return end
    if not allowed() then close(true);return end
    local sw,sh=guiGetScreenSize()
    local scale=math.min(sw/1920,sh/1080)
    if sw~=fontW or sh~=fontH then
        if isElement(titleFont) then destroyElement(titleFont) end
        titleFont=dxCreateFont(":rp_core/CompactC.ttf",math.max(10,math.floor(14*scale+0.5)),false,"cleartype")
        fontW,fontH=sw,sh
    end
    local function s(v) return math.floor(v*scale+0.5) end
    local w,h=s(420),s(365)
    local x,y=math.floor((sw-w)/2),math.floor((sh-h)/2)
    local white,muted,accent=tocolor(245,245,245),tocolor(155,163,173),tocolor(103,196,216)
    dxDrawRectangle(x,y,w,h,tocolor(0,0,0,230))
    dxDrawRectangle(x+1,y+1,w-2,h-2,tocolor(0,0,0,130))
    local function text(value,top,color,size)
        dxDrawText(value,x+s(20),y+s(top),x+w-s(20),y+s(top+24),color or white,(size or 1)*scale,"default-bold","left","center",true)
    end
    dxDrawText("ЗАПРАВКА",x+s(20),y+s(12),x+w-s(20),y+s(36),white,1,titleFont or "default-bold","left","center",true)
    text(menu.name,42,muted,0.9)
    text(string.format("В баке: %.1f / %.1f л",menu.fuel,menu.capacity),80)
    text(string.format("Цена за литр: $%.2f",menu.price),110,muted)
    hits={}
    local cx,cy=getCursorPosition();cx,cy=(cx or -1)*sw,(cy or -1)*sh
    local left,width=x+s(20),w-s(40)
    if requested then
        local ratio=math.min(1,delivered/requested)
        text(string.format("Заправлено: %.1f / %.1f л",delivered,requested),151,accent)
        dxDrawRectangle(left,y+s(191),width,s(5),tocolor(40,40,40))
        dxDrawRectangle(left,y+s(191),width*ratio,s(5),accent)
        text(string.format("Оплачено: $%d",math.ceil(requested*menu.price-0.000001)),214)
    else
        local room=math.max(0,menu.capacity-menu.fuel)
        if dragging then selected=math.min(room,math.max(0,(cx-left)/width*room)) end
        local ratio=room>0 and selected/room or 0
        text(string.format("Купить: %.1f л",selected),151,accent)
        dxDrawRectangle(left,y+s(191),width,s(4),tocolor(70,70,70))
        dxDrawRectangle(left,y+s(191),width*ratio,s(4),accent)
        dxDrawRectangle(left+width*ratio-s(3),y+s(186),s(6),s(14),white)
        hits.slider={left,y+s(179),width,s(28)}
        text(string.format("Итого: $%d",math.ceil(selected*menu.price-0.000001)),214)
    end
    local function button(id,label,bx,by,bw,bh,enabled)
        local hover=enabled and cx>=bx and cy>=by and cx<=bx+bw and cy<=by+bh
        dxDrawRectangle(bx,by,bw,bh,tocolor(0,0,0))
        dxDrawRectangle(bx+1,by+1,bw-2,bh-2,hover and tocolor(17,17,17) or tocolor(14,14,14))
        dxDrawRectangle(bx+s(3),by+1,bw-s(6),1,tocolor(18,18,18))
        dxDrawText(label,bx,by,bx+bw,by+bh,enabled and white or muted,scale,"default-bold","center","center",true)
        if enabled then hits[id]={bx,by,bw,bh} end
    end
    if not requested then
        button("buy","Заправить",left,y+s(262),s(184),s(34),selected>0)
        button("full","Полный бак",left+s(192),y+s(262),width-s(192),s(34),menu.fuel<menu.capacity)
    end
    button("close",requested and "Отменить заправку" or "Закрыть",left,y+s(306),width,s(34),true)
end
addEventHandler("onClientRender",root,render)
addEventHandler("onClientClick",root,function(button,state,cx,cy)
    if button~="left" or not menu then return end
    if state=="up" then dragging=false;return end
    for id,box in pairs(hits) do
        if cx>=box[1] and cy>=box[2] and cx<=box[1]+box[3] and cy<=box[2]+box[4] then
            if id=="slider" then dragging=true
            elseif id=="full" then selected=math.max(0,menu.capacity-menu.fuel)
            elseif id=="buy" then triggerServerEvent("car:fuelBuy",resourceRoot,selected)
            elseif id=="close" then close(true) end
            return
        end
    end
end)
addEventHandler("onClientKey",root,function(key,down)
    if menu and down and (key=="escape" or key=="e") then cancelEvent();close(true) end
end)
addEventHandler("onClientResourceStart",resourceRoot,function() bindKey("e","down",requestMenu) end)
addEventHandler("onClientResourceStop",resourceRoot,function()
    if isElement(titleFont) then destroyElement(titleFont) end
    close(true);unbindKey("e","down",requestMenu);removeEventHandler("onClientRender",root,render)
end)
