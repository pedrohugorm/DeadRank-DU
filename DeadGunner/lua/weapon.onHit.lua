if printCombatLog then 
    system.print(string.format('Hit %s for %.0f damage',radar_1.getConstructName(targetId),damage))
end

if dmgTracker[tostring(targetId)] then 
    dmgTracker[tostring(targetId)] = dmgTracker[tostring(targetId)] + damage
else
    dmgTracker[tostring(targetId)] = damage
end

local ts = system.getArkTime()
if dpsTracker[string.format('%.0f',ts/10)] then
    dpsTracker[string.format('%.0f',ts/10)] = dpsTracker[string.format('%.0f',ts/10)] + damage
    dpsChart[1] = dpsTracker[string.format('%.0f',ts/10)]
else
    dpsTracker[string.format('%.0f',(ts-10)/10)] = nil
    dpsTracker[string.format('%.0f',ts/10)] = damage
    table.insert(dpsChart,1,damage)
end

if track_dps then
    selfDps = addDps(selfDps, damage)
end