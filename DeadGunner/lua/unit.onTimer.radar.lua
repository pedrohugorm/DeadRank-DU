local enemyContactCount = 0
local friendlyContactCount = 0
local derelictContactCount = 0;
local totalContactCount = 0

function processRadarCounts(id)
    if radar_1.isConstructAbandoned(id) == 1 then
        derelictContactCount = derelictContactCount + 1
    else
        if radar_1.hasMatchingTransponder(id) == 0 then
            enemyContactCount = enemyContactCount + 1
        else 
            friendlyContactCount = friendlyContactCount + 1
        end
    end
end

for id,pos in pairs(unknownRadar) do
    system.print()
    system.print('------ New Contact -------')
    system.print(string.format('%s',id))
    system.print('First contact:')
    system.print(string.format('::pos{0,0,%s,%s,%s}',pos['x'],pos['y'],pos['z']))
    local cored = ''
    if radar_1.isConstructAbandoned(id) == 1 then
        cored = '[CORED] '
    end
    system.print(string.format('Name: %s%s',cored,radar_1.getConstructName(id)))
    system.print(string.format('Size: %s',radar_1.getConstructCoreSize(id)))
    system.print('---------------------------')

    processRadarCounts(id)
end

totalContactCount = friendlyContactCount + enemyContactCount + derelictContactCount

-- Sound Handling Area
if not inSZ and SZD*0.000005 > radarBuffer or szAlerts then
    if totalContactCount > 0 then
        system.stopSound()
        if enemyContactCount > 0 then
            system.playSound('hostiles_detected.mp3')
        else
            if friendlyContactCount > 1 then
                system.playSound('multiple_contacts.mp3')
            elseif derelictContactCount > 0 then
                system.playSound('derelict_contact.mp3')
            else
                system.playSound('contact2.mp3')
            end
        end
    end
end

friendlyContactCount = 0
enemyContactCount = 0
derelictContactCount = 0
totalContactCount = 0
-- End of Sound Handling Area

unknownRadar = {}