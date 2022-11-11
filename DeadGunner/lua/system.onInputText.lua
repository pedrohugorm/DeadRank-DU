if string.starts(text:lower(),'code') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    table.insert(tags,matches[2])
    transponder_1.setTags(tags)
    transponder_1.deactivate()
    tags = transponder_1.getTags()
    system.print('--Transponder Code Added--')
end
if string.starts(text:lower(),'hide codes') then
    showCode = false
    system.print('--Transponder Codes hidden--')
end
if string.starts(text:lower(),'show codes') then
    showCode = true
    system.print('--Transponder Codes visible--')
end
if string.starts(text:lower(),'delcode') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    local r = nil
    for i,v in ipairs(tags) do if v == matches[2] then r = i end end
    table.remove(tags,r)
    transponder_1.setTags(tags)
    transponder_1.deactivate()
    tags = transponder_1.getTags()
    system.print('--Transponder Code Removed--')
end

if string.starts(text:lower(),'printcore') then
    local targetID = radar_1.getTargetId()
    if targetID ~= 0 then
        system.print(targetID)
    end
end
if string.starts(text:lower(),'addships') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    if #matches > 1 then
        id = matches[2]
        if radar_1.hasMatchingTransponder(id) == 1 then
            local owner = radar_1.getConstructOwnerEntity(id)
            if owner['isOrganization'] then
                owner = system.getOrganization(owner['id'])
                owner = owner['tag']
            else
                owner = system.getPlayerName(owner['id'])
            end
            friendlySIDs[id] = owner
            write_db.setStringValue(string.format('sc-%s',id),owner)
            system.print(string.format('-- Added to friendly list (Name: %s | ID: %s)',radar_1.getConstructName(id),id))
        else
            friendlySIDs[id] = 'Auto Add'
            write_db.setStringValue(string.format('sc-%s',id),'Auto Add')
            system.print(string.format('-- Added to friendly list (Name: %s | ID: %s)',radar_1.getConstructName(id),id))
        end
    else
        for _,id in ipairs(radar_1.getConstructIds()) do
            if radar_1.hasMatchingTransponder(id) == 1 then
                local owner = radar_1.getConstructOwnerEntity(id)
                if owner['isOrganization'] then
                    owner = system.getOrganization(owner['id'])
                    owner = owner['tag']
                else
                    owner = system.getPlayerName(owner['id'])
                end
                friendlySIDs[id] = owner
                write_db.setStringValue(string.format('sc-%s',id),owner)
                system.print(string.format('-- Added to friendly list (Name: %s | ID: %s)',radar_1.getConstructName(id),id))
            else
                friendlySIDs[id] = 'Auto Add'
                write_db.setStringValue(string.format('sc-%s',id),'Auto Add')
                system.print(string.format('-- Added to friendly list (Name: %s | ID: %s)',radar_1.getConstructName(id),id))
            end
        end
    end
end
if string.starts(text:lower(),'delshipid') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    local r = nil
    for k,v in pairs(friendlySIDs) do if k == matches[2] then r = k end end
    if r ~= nil then friendlySIDs[r] = nil end
    if write_db ~= nil and #matches == 2 then
        if write_db.hasKey('sc-' .. tostring(matches[2])) == 1 then write_db.setStringValue('sc-' .. tostring(matches[2]),nil) end
    end
    system.print('-- Construct removed from Friendly ID list --')
end

if type(tonumber(text)) == 'number' and (#text == 3 or text == '0') and codeSeed ~= nil then
    if text == '0' then
            system.print('-- Removing primary target filter --')
            primary = nil
            radarFilter = 'All'
    else
        system.print(string.format('-- Adding primary target filter [%s] --',text))
        primary = tostring(text)
        radarFilter = 'primary'
    end
end

if string.starts(text,'agc') then
    local matches = {}
    for w in text:gmatch('([^ ]+) ?') do table.insert(matches,w) end
    if (#matches ~= 2 or not tonumber(matches[2])) and codeSeed ~= nil then
        system.print('-- Invalid start command --')
    else
        local t = nil
        if #matches == 2 then t = tonumber(matches[2]) elseif #matches == 1 then t = tonumber(matches[1]) end
        if codeSeed == nil then
            system.print('-- Transponder started --')
            codeSeed = t
            unit.setTimer('code',0.25)
        else
            codeSeed = t
            system.print('-- Code seed changed --')
        end
    end
end
if string.starts(text:lower(),'show ') and not string.starts(text,'show code') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    if #matches ~= 2 then
        system.print('-- Invalid command format --')
    elseif not contains(validSizes,matches[2]) then
        system.print(string.format('-- Invalid filter "%s"',matches[2]))
    else
        if contains(filterSize,matches[2]) then
            system.print(string.format('-- Already showing %s core size --',matches[2]))
        else
            system.print(string.format('-- Including %s core size --',matches[2]))
            table.insert(filterSize,matches[2])
        end
    end
end
if string.starts(text:lower(),'hide ') and not string.starts(text,'hide code') then
    local matches = {}
    for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
    if (#matches ~= 2 ) then
        system.print('-- Invalid command format --')
    else
        if not contains(filterSize,matches[2]) then
            system.print(string.format('-- Already hiding %s core size --',matches[2]))
        else
            local r = nil
            for i,v in ipairs(filterSize) do 
                if v == matches[2] then
                    r = i
                end
            end
            if r ~= nil then
                system.print(string.format('-- Hiding %s core size --',matches[2]))
                table.remove(filterSize,r)
            else
                system.print(string.format('-- %s core size not found --',matches[2]))
            end
        end
    end
end
if text:lower() == 'print db' then
    if write_db ~= nil then
        system.print('-- DB READOUT START --')
        for _,key in pairs(write_db.getKeyList()) do
            if string.find(write_db.getStringValue(key),'::pos') ~= nil or true then
                system.print(string.format('%s: %s',key,write_db.getStringValue(key)))
            end
        end
        system.print('-- DB READOUT END --')
    else
        system.print('-- NO DB ATTACHED --')
    end
end
if text:lower() == 'clear db' then
    if write_db ~= nil then
        write_db.clear()
        system.print('-- DB CLEARED --')
    else
        system.print('-- NO DB ATTACHED --')
    end
end
if text:lower() == 'coreid' then
    system.print(string.format('-- %.0f --',construct.getId()))
end
if text:lower() == 'clear damage' then
    system.print('-- Clearing damage dealt to target (this seat only) --')
    local targetID = radar_1.getTargetId()
    if targetID == 0 then
        system.print('-- No target selected --')
    else
        if write_db then
            if write_db.hasKey('damage - ' .. tostring(targetID) .. ' - ' .. pilotName) then
                write_db.clearValue('damage - ' .. tostring(targetID) .. ' - ' .. pilotName)
                system.print('Cleared: ' .. 'damage - ' .. tostring(targetID) .. ' - ' .. pilotName)
            end
        end
        dmgTracker[tostring(targetID)] = nil
        system.print('Cleared dmgTracker: ' .. tostring(targetID))
    end
end
if text:lower() == 'clear all damage' then
    system.print('-- Clearing all damage dealt (this seat only) --')
    dmgTracker = {}
    for _,dbName in pairs(db) do
        for _,key in pairs(dbName.getKeyList()) do
            if string.starts(key,'damage - ') then
                dbName.clearValue(key)
            end
        end
    end
end
if text:lower() == 'print damage' then
    system.print('-- Printing all damage dealt --')
    for _,dbName in pairs(db) do
        for _,key in pairs(dbName.getKeyList()) do
            if string.starts(key,'damage - ') then
                system.print(string.format('%s: %.2f',key,dbName.getFloatValue(key)))
            end
        end
    end
end
if string.starts(text,'/G') then
    if write_db ~= nil then
        local matches = {}
        for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
        local found = false
        if #matches > 2 then
            for _,key in pairs(write_db.getKeyList()) do
                if matches[2] == key then
                    found = true
                    write_db.setStringValue(key,matches[3])
                    write_db.setIntValue(key,tonumber(matches[3]))
                end
            end
            if found then
                system.print(string.format('Set "%s" to "%s"',matches[2],matches[3]))
            else
                system.print('-- INVALID VARIABLE NAME --')
            end
        else
            system.print('-- INVALID COMMAND FORMAT --')
        end
    else
        system.print('-- NO DATABANK --')
    end
end
if string.starts(text,'?') then
    if write_db ~= nil then
        local matches = {}
        for w in text:gmatch("([^ ]+) ?") do table.insert(matches,w) end
        if #matches > 1 then
            system.print('-- DB READOUT START --')
            for _,key in pairs(write_db.getKeyList()) do
                if string.find(key,matches[2]) ~= nil then
                    system.print(string.format('%s = %s',key,write_db.getStringValue(key)))
                end
            end
            system.print('-- DB READOUT END --')
        end
    else
        system.print('-- NO DB ATTACHED --')
    end
end