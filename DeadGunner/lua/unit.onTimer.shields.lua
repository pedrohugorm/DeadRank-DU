local shieldPercent = shield_1.getShieldHitpoints()/shield_1.getMaxShieldHitpoints()*100

if shieldPercent <= 12 then
    system.stopSound()
    system.playSound('shield_critical.mp3')
elseif shieldPercent <= 25 and not cue25pDone then
    system.stopSound()
    system.playSound('25p_shields.mp3')
    cue25pDone = true
elseif shieldPercent <= 50 and not cue50pDone then
    system.stopSound()
    system.playSound('50p_shields.mp3')
    cue50pDone = true
elseif shieldPercent <= 75 and not cue50pDone then
    system.stopSound()
    system.playSound('75p_shields.mp3')
    cue50pDone = true
elseif shieldPercent > 25 then
    cue25pDone = false
elseif shieldPercent > 50 then
    cue50pDone = false
elseif shieldPercent > 75 then
    cue75pDone = false
end