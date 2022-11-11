if debug_dps then
    local randomValSelf = math.random(20000, 100000)
    local randomValEnemy = math.random(20000, 100000)
    
    selfDps = addDps(selfDps, randomValSelf)
    enemyDps = addDps(enemyDps, randomValEnemy)
    
    system.print('debug dps self=' .. tostring(randomValSelf) .. ' enemy=' .. tostring(randomValEnemy))
end