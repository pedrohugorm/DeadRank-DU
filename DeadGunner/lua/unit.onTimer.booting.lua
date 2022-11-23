if bootTimer == 2 then
    if radar_1 then radarData = RadarWidgetCreate() end
    
    radarStart = true
    if radar_1 then unit.setTimer('radar',0.15) end
    if shield_1 then unit.setTimer('shields', 2) end
    WeaponWidgetCreate()
    unit.stopTimer('booting')
    system.playSound('welcome.mp3')
else
    system.print('System booting: '..tostring(bootTimer))
end
bootTimer = bootTimer + 1