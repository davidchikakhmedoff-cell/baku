-- Read-only checks usable from the hosting console, without debugscript or ACL grants.
local required = {
    rp_core = {'AuthDBQuery','AuthDBExec','getAuthPlayerId','sendCoreChatMessage','sendCoreNotification'},
    rp_home = {'getHouseParkingSpaces','getFreeHouseParkingSpace'},
    rp_car = {'registerFactionVehicle','getConfiguredVehicleName','executeCarCommand'},
    rp_fraction = {'executeFractionCommand','canDriveFactionVehicle'}
}
function runHostingChecks(player)
    if isElement(player) and (not AdminCore or not AdminCore.hasPermission(player,'adminCommands')) then return false end
    local issues = 0
    local function report(text, bad)
        if bad then issues = issues + 1 end
        outputServerLog('[RP HEALTH] '..text)
        if isElement(player) and RPChat then
            RPChat.send(player,{type='normal',text='[RP HEALTH] '..text,color=bad and {239,100,100} or {130,200,220}})
        end
    end
    report('MTA '..tostring(getVersion().mta or getVersion().sortable)..'; проверка ресурсов и файлов')
    for name, exportsNeeded in pairs(required) do
        local resource = getResourceFromName(name)
        local state = resource and getResourceState(resource) or 'missing'
        report(name..': '..state, state ~= 'running')
        if resource then
            local functions = {}
            for _,fn in ipairs(getResourceExportedFunctions(resource) or {}) do functions[fn]=true end
            for _,fn in ipairs(exportsNeeded) do if not functions[fn] then report('Не загружен экспорт '..name..':'..fn,true) end end
            -- Hosting ACL may prohibit reading another resource's files even
            -- read-only. Inspect our own manifest; the offline release checker
            -- validates files for all resources without changing server rights.
            if name=='rp_core' then
                local meta=xmlLoadFile('meta.xml',true)
                if not meta then report('Не удалось прочитать rp_core/meta.xml',true)
                else
                    for _,node in ipairs(xmlNodeGetChildren(meta)) do
                        local tag=xmlNodeGetName(node)
                        local src=xmlNodeGetAttribute(node,'src')
                        if src and (tag=='script' or tag=='file' or tag=='map') and not fileExists(src) then
                            report('Нет файла (проверьте регистр): rp_core/'..src,true)
                        end
                    end
                    xmlUnloadFile(meta)
                end
            end
        end
    end
    for _,name in ipairs({'aston_martin_db9','audi_r8','bmw_e46','bmw_e60','bmw_e70','bmw_f10','bmw_f12','bmw_f90','bmw_i8','ford_taurus','lexus_ls400','mercedes_c63_coupe','mercedes_clk_55','mercedes_ml63_w164','mercedes_sprinter','skoda_octavia_universal','toyota_sequoia','volkswagen_passat_cc'}) do
        local resource=getResourceFromName(name)
        if not resource or getResourceState(resource)~='running' then report('Не работает ресурс модели '..name,true) end
    end
    for _,right in ipairs({'function.kickPlayer','function.loadstring'}) do
        if not hasObjectPermissionTo(getThisResource(),right,false) then
            report('Нет ACL-права '..right..'; подтвердите запрос rp_core командой aclrequest allow rp_core all в консоли хостинга',true)
        end
    end
    local rows = AuthDBQuery and AuthDBQuery('SELECT COUNT(*) AS n FROM players')
    report(rows and rows[1] and ('База аккаунтов доступна; записей: '..tostring(rows[1].n)) or 'База аккаунтов недоступна',not (rows and rows[1]))
    for _,name in ipairs({'play','freeroam'}) do
        local resource=getResourceFromName(name)
        if resource and getResourceState(resource)=='running' then report('Запущен '..name..': проверьте его обработчики спавна, транспорта и управления',true) end
    end
    report('Проверка завершена; замечаний: '..issues)
    return issues==0
end
addCommandHandler('rphealth',runHostingChecks)
