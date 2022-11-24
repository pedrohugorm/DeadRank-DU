cPos = vec3(construct.getWorldPosition())
local inWS = false
if warpScan then
    for k,v in pairs(warpScan) do if id == k then inWS = true break end end
    if not inSZ and SZD*0.000005 > radarBuffer then
        system.stopSound()
        system.playSound('targetleft.mp3')
        if inWS then
            local cored = ''
            if radar_1.isConstructAbandoned(id) == 1 then
                cored = '[CORED] '
            end
            system.print('----------------------')
            system.print(string.format('%.0f - (%s[%s] %s) MIDPOINT (::pos{0,0,%.0f,%.0f,%.0f})',system.getArkTime(),cored,radar_1.getConstructCoreSize(id),radar_1.getConstructName(id),(cPos['x']+warpScan[id]['x'])/2,(cPos['y']+warpScan[id]['y'])/2,(cPos['z']+warpScan[id]['z'])/2))
            system.print('----------------------')
            system.print()
            warpScan[id] = nil
        end
    end
end