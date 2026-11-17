
Toner = {

button = {},

gridlist = {},

row = {},

column = {},

window = {}
}

local shader = {}
local toner = {
{"files/toner/t1.tga", "toner"},
{"files/toner/t2.tga", "toner"},
{"files/toner/t3.tga", "toner"},
{"files/toner/t4.tga", "toner"},
{"files/toner/t5.tga", "toner"},
{"files/toner/t6.tga", "toner"},
{"files/toner/t7.tga", "toner"},
{"files/toner/t8.tga", "toner"},
{"files/toner/t9.tga", "toner"}}

localPlayer = getLocalPlayer()

addEventHandler("onClientResourceStart", resourceRoot,
 function(res)

    if res == getThisResource() then
        Toner.window[1] = guiCreateWindow(396, 289, 435, 370, "Выбор тонировки:", false)

        guiWindowSetSizable(Toner.window[1], false)


        Toner.gridlist[1] = guiCreateGridList(70, 37, 273, 180, false, Toner.window[1])
   
        Toner.column[1] = guiGridListAddColumn(Toner.gridlist[1], "Вид тонировки:", 0.5)
    
        Toner.column[2] = guiGridListAddColumn(Toner.gridlist[1], "Цена:", 0.5)
               
        Toner.row[1] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[2] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[3] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[4] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[5] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[6] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[7] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[8] = guiGridListAddRow(Toner.gridlist[1])
        Toner.row[9] = guiGridListAddRow(Toner.gridlist[1])

        guiGridListSetItemText(Toner.gridlist[1], Toner.row[1], Toner.column[1], "Дубай синий", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[1], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[1], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[2], Toner.column[1], "Дубай фиолетовый", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[2], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[2], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[3], Toner.column[1], "Дубай красный", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[3], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[3], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[4], Toner.column[1], "Хамелеон", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[4], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[4], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[5], Toner.column[1], "Черная 5%", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[5], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[5], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[6], Toner.column[1], "Черная 25%", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[6], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[6], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[7], Toner.column[1], "Черная 65%", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[7], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[7], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[8], Toner.column[1], "Голубая 25%", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[8], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[8], Toner.column[2], 0)


        guiGridListSetItemText(Toner.gridlist[1], Toner.row[9], Toner.column[1], "Снег на стёклах", false, false)
        guiGridListSetItemText(Toner.gridlist[1], Toner.row[9], Toner.column[2], "бесплатно", false, false)

        guiGridListSetItemData(Toner.gridlist[1], Toner.row[9], Toner.column[2], 0)

       
        Toner.button[1] = guiCreateButton(70, 237, 273, 40, "Купить", false, Toner.window[1])
        guiSetFont(Toner.button[1], "default-bold-small")

        guiSetProperty(Toner.button[1], "NormalTextColour", "FFFFFFFF")
        Toner.button[2] = guiCreateButton(70, 287, 273, 40, "Выйти", false, Toner.window[1])
        guiSetFont(Toner.button[2], "default-bold-small")

        guiSetProperty(Toner.button[2], "NormalTextColour", "FFFFFFFF")
        guiSetVisible(Toner.window[1], false)
        showCursor(false)
		bindKey("F5", "down", ShowToner)
    end
end
)


function ShowToner()
    if guiGetVisible(Toner.window[1]) then
        guiSetVisible(Toner.window[1], false)
        showCursor(false)
    else
        guiSetVisible(Toner.window[1], true)
        showCursor(true)
    end
end

function onGuiClickPanel (button, state, absoluteX, absoluteY)
    veh = getPedOccupiedVehicle(localPlayer)
    if veh and getVehicleController(veh) == localPlayer then
        for k, _ in ipairs(Toner.row) do
            if source == Toner.gridlist[1] and (guiGridListGetSelectedItem  ( Toner.gridlist[1] ) == Toner.row[k]) then
                if not shader[veh] then
                    shader[veh] = dxCreateShader("files/toner.fx")
                end
                engineApplyShaderToWorldTexture(shader[veh], toner[k][2], veh)
                dxSetShaderValue(shader[veh], "gTexture", dxCreateTexture(toner[k][1]))
            end
        end
        if (source == Toner.button[1]) then
            if #guiGridListGetSelectedItems ( Toner.gridlist[1] ) > 0 then
                for k, _ in ipairs(Toner.row) do
                    if guiGridListGetSelectedItem ( Toner.gridlist[1] ) == Toner.row[k] then   
                        price = guiGridListGetItemData(Toner.gridlist[1], Toner.row[k], Toner.column[2])

                        triggerServerEvent("setServerToner", getRootElement(), localPlayer, veh, k, price)
                    end
                end
            end
        elseif (source == Toner.button[2]) then
            guiSetVisible(Toner.window[1], false)
            showCursor(false)
            setToner(veh, getElementData(veh, "toner"))
        end
    end
end
addEventHandler ("onClientGUIClick", getRootElement(), onGuiClickPanel)

function setToner(veh, type)
    if not shader[veh] then
        shader[veh] = dxCreateShader("files/toner.fx")
    end
    if type == 0 then
        for k = 1, 9 do
            engineRemoveShaderFromWorldTexture(shader[veh], toner[k][2], veh)
        end
    else
        engineApplyShaderToWorldTexture(shader[veh], toner[type][2], veh)
        dxSetShaderValue(shader[veh], "gTexture", dxCreateTexture(toner[type][1]))
    end
end
addEvent("setToner", true)
addEventHandler("setToner", getRootElement(), setToner)