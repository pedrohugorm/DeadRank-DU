totalDps = selfDps + enemyDps

if totalDps > 0 then
    pushDpsToHistory(selfDpsHistory, selfDps)
    pushDpsToHistory(enemyDpsHistory, enemyDps)
end

selfDps = 0
enemyDps = 0