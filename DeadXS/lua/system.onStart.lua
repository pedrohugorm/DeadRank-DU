json = require("dkjson")
Atlas = require('atlas')


function convertWaypoint(wp)
    local clamp  = utils.clamp
    local deg2rad    = math.pi/180
    local rad2deg    = 180/math.pi
    local epsilon    = 1e-10

    local num        = ' *([+-]?%d+%.?%d*e?[+-]?%d*)'
    local posPattern = '::pos{' .. num .. ',' .. num .. ',' ..  num .. ',' .. num ..  ',' .. num .. '}'
    local systemId = wp 

    systemId, bodyId, latitude, longitude, altitude = string.match(wp, posPattern)
    assert(systemId, 'Position string is malformed.')

    systemId  = tonumber(systemId)
    bodyId    = tonumber(bodyId)
    latitude  = tonumber(latitude)
    longitude = tonumber(longitude)
    altitude  = tonumber(altitude)

    if bodyId == 0 then -- this is a hack to represent points in space
    mapPosition =  setmetatable({latitude  = latitude,
                                longitude = longitude,
                                altitude  = altitude,
                                bodyId    = bodyId,
                                systemId  = systemId}, MapPosition)
    else
    mapPosition = setmetatable({latitude  = deg2rad*clamp(latitude, -90, 90),
                                longitude = deg2rad*(longitude % 360),
                                altitude  = altitude,
                                bodyId    = bodyId,
                                systemId  = systemId}, MapPosition)
    end
    if mapPosition.bodyId == 0 then
        return vec3(mapPosition.latitude, mapPosition.longitude, mapPosition.altitude)
    end

    local center = {
        x=Atlas[systemId][bodyId].center[1],
        y=Atlas[systemId][bodyId].center[2],
        z=Atlas[systemId][bodyId].center[3]
    }

    local xproj = math.cos(mapPosition.latitude)
    return center + (Atlas[systemId][bodyId].radius + mapPosition.altitude) *
        vec3(xproj*math.cos(mapPosition.longitude),
            xproj*math.sin(mapPosition.longitude),
            math.sin(mapPosition.latitude))
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function formatNumber(val, numType)
    if numType == 'speed' then
        local speedString = ''
        if type(val) == 'number' then speedString = string.format('%.0fkm/h',val)
        else speedString = string.format('%skm/h',val)
        end
        return speedString
    elseif numType == 'distance' then
        local distString = ''
        if type(val) == 'number' then
            if val < 1000 then distString = string.format('%.2fm',val)
            elseif val < 100000 then distString = string.format('%.2fkm',val/1000)
            else distString = string.format('%.2fsu',val*.000005)
            end
        else
            distString = string.format('%sm',val)
        end
        return distString
    elseif numType == 'mass' then
        local massStr = ''
        if type(val) == 'number' then
            if val < 1000 then massStr = string.format('%.2fkg',val)
            elseif val < 1000000 then massStr = string.format('%.2ft',val/1000)
            else massStr = string.format('%.2fkt',val/1000000)
            end
        else
            massStr = string.format('%skg',val)
        end
        return massStr
    end
end

function pipeDist(A,B,loc,reachable)
    local AB = vec3.new(B['x']-A['x'],B['y']-A['y'],B['z']-A['z'])
    local BE = vec3.new(loc['x']-B['x'],loc['y']-B['y'],loc['z']-B['z'])
    local AE = vec3.new(loc['x']-A['x'],loc['y']-A['y'],loc['z']-A['z'])

    -- Is the point within warp distance and do we care?
    if AB:len() <= 500/0.000005 or not reachable then
        AB_BE = AB:dot(BE)
        AB_AE = AB:dot(AE)

        -- Is the point past the warp destination?
        -- If so, then the warp destination is closest
        if (AB_BE > 0) then
            dist = BE:len()
            distType = 'POINT'

        -- Is the point before the start point?
        -- If so, then the start point is the closest
        elseif (AB_AE < 0) then
            dist = AE:len()
            distType = 'POINT'

        -- If neither above condition was met, then the
        -- destination point must have be directly out from
        -- somewhere along the warp pipe. Let's calculate
        -- that distance
        else
            dist = vec3(AE:cross(BE)):len()/vec3(AB):len()
            distType = 'PIPE'
        end
        return dist,distType
    end
    return nil,nil
end

function closestPlanet()
    local cName = nil
    local cDist = nil
    for pname,pvec in pairs(planets) do
        local tempDist = vec3(constructPosition-pvec):len()
        if cDist == nil or cDist > tempDist then
            cDist = tempDist
            cName = pname
        end
    end
    return cName,cDist
end

function closestPipe()
    pipes = {}
    local i = 0
    for name,center in pairs(planets) do
        for name2,center2 in pairs(planets) do
            if name ~= name2 and pipes[string.format('%s - %s',name2,name)] == nil then
                pipes[string.format('%s - %s',name,name2)] = {}
                table.insert(pipes[string.format('%s - %s',name,name2)],center)
                table.insert(pipes[string.format('%s - %s',name,name2)],center2)
                if i % 50 == 0 then
                    coroutine.yield()
                end
                i = i + 1
            end
        end
    end
    local cPipe = 'None'
    local cDist = 9999999999
    local cLoc = vec3(construct.getWorldPosition())
    i = 0
    for pName,vecs in pairs(pipes) do
        local tempDist,tempType = pipeDist(vecs[1],vecs[2],cLoc,false)
        if tempDist ~= nil then
            if cDist > tempDist then
                cDist = tempDist
                cPipe = pName
            end
        end
        if i % 50 == 0 then
            coroutine.yield()
        end
        i = i + 1
    end
    closestPipeName = cPipe
    closestPipeDistance = cDist
    return cPipe,cDist
end

function contains(tablelist, val)
    for i=1,#tablelist do
       if tablelist[i] == val then 
          return true
       end
    end
    return false
 end


 function WeaponWidgetCreate()
    if type(weapon) == 'table' and #weapon > 0 then
        local WeaponPanaelIdList = {}
        for i = 1, #weapon do
            if i%2 ~= 0 then
            table.insert(WeaponPanaelIdList, system.createWidgetPanel(''))
            end
                local WeaponWidgetDataId = weapon[i].getDataId()
                local WeaponWidgetType = weapon[i].getWidgetType()
                system.addDataToWidget(WeaponWidgetDataId, system.createWidget(WeaponPanaelIdList[#WeaponPanaelIdList], WeaponWidgetType))
        end
    end
end

function brakeWidget()
    local brakeON = brakeInput > 0
    local bw = ''
    if brakeON then
        warnings['brakes'] = 'svgBrakes'
    else
        warnings['brakes'] = nil
    end
    return bw
end

function flightWidget()
    if Nav.axisCommandManager:getMasterMode() == controlMasterModeId.travel then mode = 'Throttle ' .. tostring(Nav.axisCommandManager:getThrottleCommand(0) * 100) .. '%' modeBG = bgColor
    else mode = 'Cruise '  .. string.format('%.2f',Nav.axisCommandManager:getTargetSpeed(0)) .. ' km/h' modeBG = 'rgba(99, 250, 79, 0.5)'
    end
    local sw = ''
    if speed ~= nil then
        --Center Top
        sw = [[
            <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
                <path d="
                M ]] .. tostring(.31*screenWidth) .. ' ' .. tostring(.001*screenHeight) ..[[ 
                L ]] .. tostring(.69*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
                L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
                L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
                L ]] .. tostring(.31*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [["
                stroke="]]..lineColor..[[" stroke-width="2" fill="]]..bgColor..[[" />]]
        

        -- Right Side
        sw = sw .. [[<path d="
                M ]] .. tostring(.6635*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [[ 
                L ]] .. tostring(.691*screenWidth) .. ' ' .. tostring(.0387*screenHeight) .. [[
                L ]] .. tostring(.80*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
                L ]] .. tostring(.69*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
                L ]] .. tostring(.6635*screenWidth) .. ' ' .. tostring(.0185*screenHeight) .. [[
                L ]] .. tostring(.6635*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [["
                stroke="]]..lineColor..[[" stroke-width="1" fill="]].. modeBG ..[[" />]]
                
        if not maxBrake then maxBrake = 0 end
        sw = sw .. [[<path d="
                M ]] .. tostring(.5*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[ 
                L ]] .. tostring(.5*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [["
                stroke="]]..lineColor..[[" stroke-width="1" fill="none" />

                <path d="
                M ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[ 
                L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [["
                stroke="]]..lineColor..[[" stroke-width="1" fill="none" />

                <path d="
                M ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[ 
                L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [["
                stroke="]]..lineColor..[[" stroke-width="1" fill="none" />

                <text x="]].. tostring(.4 * screenWidth) ..[[" y="]].. tostring(.015 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Speed: ]] .. formatNumber(speed,'speed') .. [[</text>
                <text x="]].. tostring(.4 * screenWidth) ..[[" y="]].. tostring(.0325 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Current Accel: ]] .. string.format('%.2f G',accel/9.81) .. [[</text>
                <text x="]].. tostring(.4 * screenWidth) ..[[" y="]].. tostring(.05 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Brake Dist: ]] .. formatNumber(brakeDist,'distance') .. [[</text>
                
                <text x="]].. tostring(.502 * screenWidth) ..[[" y="]].. tostring(.015 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Max Speed: ]] .. formatNumber(maxSpeed,'speed') .. [[</text>
                <text x="]].. tostring(.502 * screenWidth) ..[[" y="]].. tostring(.0325 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Max Accel: ]] .. string.format('%.2f G',maxSpaceThrust/mass/9.81) ..[[</text>
                <text x="]].. tostring(.502 * screenWidth) ..[[" y="]].. tostring(.05 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Max Brake: ]] .. string.format('%.2f G',maxBrake/mass/9.81) .. [[</text>

                <text x="]].. tostring(.37 * screenWidth) ..[[" y="]].. tostring(.015 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Mass </text>
                <text x="]].. tostring(.355 * screenWidth) ..[[" y="]].. tostring(.028 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">]]..formatNumber(mass,'mass')..[[</text>

                <text x="]].. tostring(.612 * screenWidth) ..[[" y="]].. tostring(.015 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Gravity </text>
                <text x="]].. tostring(.612 * screenWidth) ..[[" y="]].. tostring(.028 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">]].. string.format('%.2f G',gravity/9.81) ..[[</text>

                <text x="]].. tostring(.684 * screenWidth) ..[[" y="]].. tostring(.028 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold" transform="rotate(-10,]].. tostring(.684 * screenWidth) ..",".. tostring(.028 * screenHeight) ..[[)">]].. mode ..[[</text>

            </svg>
            ]]
    else
        sw = ''
    end
    return sw
end

function fuelWidget()
    curFuel = 0
    local fuelWarning = false
    local fuelTankWarning = false
    for i,v in pairs(spacefueltank) do 
        curFuel = curFuel + v.getItemsVolume()
        if v.getItemsVolume()/v.getMaxVolume() < .2 then fuelTankWarning = true end
    end
    sFuelPercent = curFuel/maxFuel * 100
    if sFuelPercent < 20 then fuelWarning = true end
    curFuelStr = string.format('%.2f%%',sFuelPercent)

    --Center bottom ribbon
    local fw = string.format([[
        <svg width="100%%" height="100%%" style="position: absolute;left:0%%;top:0%%;font-family: Calibri;">
            <linearGradient id="sFuel" x1="0%%" y1="0%%" x2="100%%" y2="0%%">
            <stop offset="%.1f%%" style="stop-color:rgba(99, 250, 79, 0.95);stop-opacity:.95" />
            <stop offset="%.1f%%" style="stop-color:rgba(255, 10, 10, 0.5);stop-opacity:.5" />
            </linearGradient>]],sFuelPercent,sFuelPercent)

    fw = fw .. [[
        <path d="
        M ]] .. tostring(.336*screenWidth) .. ' ' .. tostring(.0185*screenHeight) .. [[ 
        L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
        L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
        L ]] .. tostring(.6635*screenWidth) .. ' ' .. tostring(.0185*screenHeight) .. [[
        L ]] .. tostring(.6635*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [[
        L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [[
        L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [[
        L ]] .. tostring(.3365*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [[
        L ]] .. tostring(.336*screenWidth) .. ' ' .. tostring(.0185*screenHeight) .. [["
    stroke="]]..lineColor..[[" stroke-width="2" fill="]]..bgColor..[[" />

    <path d="
        M ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
        L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[
        L ]] .. tostring(.61*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [[
        L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.0645*screenHeight) .. [[
        L ]] .. tostring(.39*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [["
    stroke="]]..lineColor..[[" stroke-width="1" fill="url(#sFuel)" />

    <path d="
        M ]] .. tostring(.5*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[ 
        L ]] .. tostring(.5*screenWidth) .. ' ' .. tostring(.070*screenHeight) .. [["
    stroke="black" stroke-width="1.5" fill="none" />

    <path d="
        M ]] .. tostring(.555*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[ 
        L ]] .. tostring(.555*screenWidth) .. ' ' .. tostring(.070*screenHeight) .. [["
    stroke="black" stroke-width="1.5" fill="none" />

    <path d="
        M ]] .. tostring(.445*screenWidth) .. ' ' .. tostring(.055*screenHeight) .. [[ 
        L ]] .. tostring(.445*screenWidth) .. ' ' .. tostring(.070*screenHeight) .. [["
    stroke="black" stroke-width="1.5" fill="none" />

    <text x="]].. tostring(.39 * screenWidth) ..[[" y="]].. tostring(.08 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Fuel: ]] .. curFuelStr .. [[</text>
    <!--text x="]].. tostring(.445 * screenWidth) ..[[" y="]].. tostring(.08 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">25%</text>
    <text x="]].. tostring(.5 * screenWidth) ..[[" y="]].. tostring(.08 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">50%</text>
    <text x="]].. tostring(.555 * screenWidth) ..[[" y="]].. tostring(.08 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">75%</text-->


    ]]

    if fuelTankWarning or fuelWarning or showAlerts then
        fuelWarningText = 'Fuel level &lt; 20%'
        if not fuelWarning then fuelWarningText = 'A Fuel tank &lt; 20%%' end
        warnings['lowFuel'] = 'svgWarning'
    else
        warnings['lowFuel'] = nil
    end

    fw = fw .. '</svg>'

    return fw
end

function apStatusWidget()
    local bg = bgColor
    local apStatus = 'inactive'
    if auto_follow then bg = 'rgba(99, 250, 79, 0.5)' apStatus = 'following' end
    if autopilot then bg = 'rgba(99, 250, 79, 0.5)' apStatus = 'Engaged' end
    if not autopilot and autopilot_dest ~= nil then apStatus = 'Set' end
    local apw = [[
            <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            -- Left Top Side]]
    apw = apw .. [[<path d="
        M ]] .. tostring(.3365*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [[ 
        L ]] .. tostring(.309*screenWidth) .. ' ' .. tostring(.0387*screenHeight) .. [[
        L ]] .. tostring(.2*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(.31*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(.3365*screenWidth) .. ' ' .. tostring(.0185*screenHeight) .. [[
        L ]] .. tostring(.3365*screenWidth) .. ' ' .. tostring(.028*screenHeight) .. [["
        stroke="]]..lineColor..[[" stroke-width="1" fill="]]..bg..[[" />
        
        <text x="]].. tostring(.25 * screenWidth) ..[[" y="]].. tostring(.012 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold" transform="rotate(10,]].. tostring(.25 * screenWidth) ..",".. tostring(.012 * screenHeight) ..[[)">AutoPilot: ]]..apStatus..[[</text>
    ]]

    if autopilot_dest and speed > 1000 then
        local balance = vec3(autopilot_dest - constructPosition):len()/(speed/3.6) --meters/(meter/second) == seconds
        local seconds = balance % 60
        balance = balance // 60
        local minutes = balance % 60
        balance = balance // 60
        local hours = balance % 60
        apw = apw .. [[
            <text x="]].. tostring(.280 * screenWidth) ..[[" y="]].. tostring(.055 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">ETA: ]]..string.format('%.0f:%.0f.%.0f',hours,minutes,seconds)..[[</text>
        ]]
    end

    apw = apw .. [[</svg>]]
    return apw
end

function positionInfoWidget()
    local piw = [[
            <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            -- Far Left Top Side]]
    piw = piw .. [[<path d="
        M ]] .. tostring(.0*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[ 
        L ]] .. tostring(.115*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[
        L ]] .. tostring(.124*screenWidth) .. ' ' .. tostring(.025*screenHeight) .. [[
        L ]] .. tostring(.25*screenWidth) .. ' ' .. tostring(.035*screenHeight) .. [[
        L ]] .. tostring(.275*screenWidth) .. ' ' .. tostring(.027*screenHeight) .. [[
        L ]] .. tostring(.2*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(.0*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(.0*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[ 
        "
        stroke="]]..lineColor..[[" stroke-width="1" fill="]]..bgColor..[[" />

        <path d="
        M ]] .. tostring(1.0*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[ 
        L ]] .. tostring(.885*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[
        L ]] .. tostring(.876*screenWidth) .. ' ' .. tostring(.025*screenHeight) .. [[
        L ]] .. tostring(.75*screenWidth) .. ' ' .. tostring(.035*screenHeight) .. [[
        L ]] .. tostring(.725*screenWidth) .. ' ' .. tostring(.027*screenHeight) .. [[
        L ]] .. tostring(.8*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(1.0*screenWidth) .. ' ' .. tostring(.001*screenHeight) .. [[
        L ]] .. tostring(1.0*screenWidth) .. ' ' .. tostring(.0155*screenHeight) .. [[ 
        "
        stroke="]]..lineColor..[[" stroke-width="1" fill="]]..bgColor..[[" />
        
        <text x="]].. tostring(.001 * screenWidth) ..[[" y="]].. tostring(.01 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size=".6vw">DeadXS Version: ]]..hudVersion..[[</text>
        <text x="]].. tostring(.125 * screenWidth) ..[[" y="]].. tostring(.011 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Nearest Planet</text>
        <text x="]].. tostring(.15 * screenWidth) ..[[" y="]].. tostring(.022 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size=".7vw" >]]..closestPlanetStr..[[</text>
        
        <text x="]].. tostring(.82 * screenWidth) ..[[" y="]].. tostring(.011 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size="1.42vh" font-weight="bold">Nearest Pipe</text>
        <text x="]].. tostring(.78 * screenWidth) ..[[" y="]].. tostring(.022 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size=".7vw" >]]..closestPipeStr..[[</text>

        <text x="]].. tostring(.90 * screenWidth) ..[[" y="]].. tostring(.011 * screenHeight) ..[[" style="fill: ]]..fontColor..[[" font-size=".7vw" font-weight="bold">Safe Zone Distance: ]]..SZDStr..[[</text>

        </svg>]]
    return piw
end

function engineWidget()
    local ew = [[
        <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            <text x="]].. tostring(.001 * screenWidth) ..[[" y="]].. tostring(.045 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Controlling Engine tags</text>
            ]]..enabledEngineTagsStr..[[
        </svg>
    ]]
    return ew
end

function planetARWidget()
    local arw = planetAR
    arw = arw .. [[
        <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            <text x="]].. tostring(.001 * screenWidth) ..[[" y="]].. tostring(.03 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Augmented Reality Mode: ]]..AR_Mode..[[</text>
        </svg>
    ]]

    return arw
end

function shipNameWidget()
    local snw = ''
    snw = snw .. [[
        <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            <text x="]].. tostring(.90 * screenWidth) ..[[" y="]].. tostring(.03 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Ship Name: ]]..construct.getName()..[[</text>
            <text x="]].. tostring(.90 * screenWidth) ..[[" y="]].. tostring(.042 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Ship Code: ]]..tostring(construct.getId())..[[</text>
        </svg>
    ]]
    return snw
end

function helpWidget()
    local hw = ''
    if showHelp then
        hw = [[
            <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            <rect x="]].. tostring(.125 * screenWidth) ..[[" y="]].. tostring(.125 * screenHeight) ..[[" rx="15" ry="15" width="60vw" height="22vh" style="fill:rgba(50, 50, 50, 0.9);stroke:white;stroke-width:5;opacity:0.9;" />
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.15 * screenHeight) ..[[" style="fill: ]]..'orange'..[[" font-size="1.42vh" font-weight="bold">
                OPTION KEY BINDINGS</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.17 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+1: Toggle help screen (Alt+Shift+1 toggles minimal Remote HUD view)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.19 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+2: Toggle Augmented reality view mode (NONE, ALL, PLANETS, CUSTOM) HUD Loads custom waypoints for AR from "autoconf/custom/AR_Waypoints.lua"</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.21 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+3: Clear all engine tag filters (i.e. all engines controlled by throttle) (Alt+shift+3 toggles through predefined tags)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.23 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+4: Engage AutoPilot to current AP destination (shown in VR)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.25 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+5: TBD</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.27 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+6: Set AutoPilot destination to the nearest safe zone</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.29 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+7: Toggles radar widget filtering mode (Show all, Show Enemy, Show Identified, Show Friendly) (Alt+Shift+7 toggles radar widget sorting between distance and construct size)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.31 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+8: Toggle Shield vent. Start venting if available. Stop venting if currently venting</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.33 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                Alt+9: Toggle between Cruise and Throttle control modes</text>
            </rect>
            
            <rect x="]].. tostring(.125 * screenWidth) ..[[" y="]].. tostring(.365 * screenHeight) ..[[" rx="15" ry="15" width="60vw" height="22vh" style="fill:rgba(50, 50, 50, 0.9);stroke:white;stroke-width:5;opacity:0.9;" />
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.39 * screenHeight) ..[[" style="fill: ]]..'orange'..[[" font-size="1.42vh" font-weight="bold">
                Lua Commands</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.41 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                disable &lt;tag&gt;: Disables control of engines tagged with the <tag> parameter</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.43 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                enable &lt;tag&gt;: Enables control of engines tagged with <tag></text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.45 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                warpFrom &lt;start position&gt; &lt;destination position&gt;: Calculates best warp bath from the <start position> (positions are in ::pos{} format)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.47 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                warp &lt;destination position&gt;: Calculates best warp path from current postion to destination (position is in ::pos{} format)</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.49 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                addWaypoint &lt;waypoint1&gt; &lt;Name&gt;: Adds temporary AR points when enabled. Requires a position tag. Optionally, you can also optionally add a custom name as well</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.51 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                delWaypoint &lt;name&gt;: Removes the specified temporary AR point</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.53 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                addShips db: Adds all ships currently on radar to the friendly construct list</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.55 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                code &lt;transponder code&gt;: Adds the transponder tag to the transponder. "delcode &lt;code&gt;" removes the tag</text>
            <text x="]].. tostring(.13 * screenWidth) ..[[" y="]].. tostring(.57 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">
                &lt;Primary Target ID&gt;: Filters radar widget to only show the construct with the specified ID</text>
            </rect>

            </svg>
        ]]
    else
        hw = ''
    end

    return hw
end

function travelIndicatorWidget()
    local p = constructPosition + 2/.000005 * vec3(construct.getWorldOrientationForward())
    local pInfo = library.getPointOnScreen({p['x'],p['y'],p['z']})

    local tiw = '<svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">'
    if pInfo[3] ~= 0 then
        if pInfo[1] < .01 then pInfo[1] = .01 end
        if pInfo[2] < .01 then pInfo[2] = .01 end
        local fill = AR_Fill
        local translate = '(0,0)'
        local depth = '8'           
        if pInfo[1] < 1 and pInfo[2] < 1 then
            translate = string.format('(%.2f,%.2f)',screenWidth*pInfo[1],screenHeight*pInfo[2])
        elseif pInfo[1] > 1 and pInfo[1] < AR_Range and pInfo[2] < 1 then
            translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight*pInfo[2])
        elseif pInfo[2] > 1 and pInfo[2] < AR_Range and pInfo[1] < 1 then
            translate = string.format('(%.2f,%.2f)',screenWidth*pInfo[1],screenHeight)
        else
            translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight)
        end
        tiw = tiw .. [[<g transform="translate]]..translate..[[">
                <circle cx="0" cy="0" r="]].. Direction_Indicator_Size ..[[px" style="fill:lightgrey;stroke:]]..Direction_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width)..[[;opacity:]].. 0.5 ..[[;" />
                <line x1="]].. Direction_Indicator_Size*1.5 ..[[" y1="0" x2="]].. -Direction_Indicator_Size*1.5 ..[[" y2="0" style="stroke:]]..Direction_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                <line y1="]].. Direction_Indicator_Size*1.5 ..[[" x1="0" y2="]].. -Direction_Indicator_Size*1.5 ..[[" x2="0" style="stroke:]]..Direction_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                </g>]]
    end
    if speed > 20 then
        local a = constructPosition + 2/.000005 * vec3(construct.getWorldVelocity())
        local aInfo = library.getPointOnScreen({a['x'],a['y'],a['z']})
        if aInfo[3] ~= 0 then
            if aInfo[1] < .01 then aInfo[1] = .01 end
            if aInfo[2] < .01 then aInfo[2] = .01 end
            local fill = AR_Fill
            local translate = '(0,0)'
            local depth = '8'           
            if aInfo[1] < 1 and aInfo[2] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth*aInfo[1],screenHeight*aInfo[2])
            elseif aInfo[1] > 1 and aInfo[1] < AR_Range and aInfo[2] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight*aInfo[2])
            elseif aInfo[2] > 1 and aInfo[2] < AR_Range and aInfo[1] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth*aInfo[1],screenHeight)
            else
                translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight)
            end
            tiw = tiw .. [[<g transform="translate]]..translate..[[">
                    <circle cx="0" cy="0" r="]].. Prograde_Indicator_Size ..[[px" style="fill:none;stroke:]]..Prograde_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width)..[[;opacity:]].. 0.5 ..[[;" />
                    <line x1="]].. Prograde_Indicator_Size*1.4 ..[[" y1="]].. Prograde_Indicator_Size*1.4 ..[[" x2="]].. -Prograde_Indicator_Size*1.4 ..[[" y2="]].. -Prograde_Indicator_Size*1.4 ..[[" style="stroke:]]..Prograde_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                    <line x1="]].. -Prograde_Indicator_Size*1.4 ..[[" y1="]].. Prograde_Indicator_Size*1.4 ..[[" x2="]].. Prograde_Indicator_Size*1.4 ..[[" y2="]].. -Prograde_Indicator_Size*1.4 ..[[" style="stroke:]]..Prograde_Indicator_Color..[[;stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                    </g>]]
        end
        local r = constructPosition - 2/.000005 * vec3(construct.getWorldVelocity())
        local aInfo = library.getPointOnScreen({r['x'],r['y'],r['z']})
        if aInfo[3] ~= 0 then
            if aInfo[1] < .01 then aInfo[1] = .01 end
            if aInfo[2] < .01 then aInfo[2] = .01 end
            local fill = AR_Fill
            local translate = '(0,0)'
            local depth = '8'           
            if aInfo[1] < 1 and aInfo[2] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth*aInfo[1],screenHeight*aInfo[2])
            elseif aInfo[1] > 1 and aInfo[1] < AR_Range and aInfo[2] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight*aInfo[2])
            elseif aInfo[2] > 1 and aInfo[2] < AR_Range and aInfo[1] < 1 then
                translate = string.format('(%.2f,%.2f)',screenWidth*aInfo[1],screenHeight)
            else
                translate = string.format('(%.2f,%.2f)',screenWidth,screenHeight)
            end
            tiw = tiw .. [[<g transform="translate]]..translate..[[">
                    <circle cx="0" cy="0" r="]].. Prograde_Indicator_Size ..[[px" style="fill:none;stroke:rgb(255, 60, 60);stroke-width:]]..tostring(Indicator_Width)..[[;opacity:]].. 0.5 ..[[;" />
                    <line x1="]].. Prograde_Indicator_Size*1.4 ..[[" y1="]].. Prograde_Indicator_Size*1.4 ..[[" x2="]].. -Prograde_Indicator_Size*1.4 ..[[" y2="]].. -Prograde_Indicator_Size*1.4 ..[[" style="stroke:rgb(255, 60, 60);stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                    <line x1="]].. -Prograde_Indicator_Size*1.4 ..[[" y1="]].. Prograde_Indicator_Size*1.4 ..[[" x2="]].. Prograde_Indicator_Size*1.4 ..[[" y2="]].. -Prograde_Indicator_Size*1.4 ..[[" style="stroke:rgb(255, 60, 60);stroke-width:]]..tostring(Indicator_Width/5)..[[;opacity:]].. 0.85 ..[[;" />
                    </g>]]
        end
    end
    tiw = tiw .. '</svg>'
    return tiw
end

function warningsWidget()
    local ww = '<svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">'
    if caerusOption then
        ww = '<svg width="100%" height="100%" style="position: absolute;left:20%;top:59%;font-family: Calibri;">'
    end
    local warningText = {}
    warningText['lowFuel'] = fuelWarningText
    warningText['brakes'] = 'Brakes Locked'
    warningText['venting'] = 'Shield Venting'
    warningText['cored'] = 'Target is Destroyed'

    local warningColor = {}
    warningColor['lowFuel'] = 'red'
    warningColor['cored'] = 'orange'
    warningColor['friendly'] = 'green'
    warningColor['venting'] = shieldHPColor

    if math.floor(system.getArkTime()*5) % 2 == 0 then
        warningColor['brakes'] = 'orange'
    else
        warningColor['brakes'] = 'yellow'
    end

    local count = 0
    for k,v in pairs(warnings) do
        if v ~= nil and warning then
            ww = ww .. [[
                <svg width="]].. tostring(.03 * screenWidth) ..[[" height="]].. tostring(.03 * screenHeight) ..[[" x="]].. tostring(.24 * screenWidth) ..[[" y="]].. tostring(.20 * screenHeight + .032 * screenHeight * count) ..[[" style="fill: ]]..warningColor[k]..[[;">
                    ]]..warningSymbols[v]..[[
                </svg>
                <text x="]].. tostring(.267 * screenWidth) ..[[" y="]].. tostring(.22 * screenHeight + .032 * screenHeight * count) .. [[" style="fill: ]]..warningColor[k]..[[;" font-size="1.7vh" font-weight="bold">]]..warningText[k]..[[</text>
                ]]
            count = count + 1
        end
    end
    ww = ww .. '</svg>'
    return ww
end

function hpWidget()
    local hw = '<svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">'
    --Shield/CCS Widget
    shieldPercent = 0
    if shield_1 then
        shieldPercent = shield_1.getShieldHitpoints()/shield_1.getMaxShieldHitpoints()*100
    end
    CCSPercent = 0
    if core then
        if core.getMaxCoreStress() then
            CCSPercent = 100*(core.getMaxCoreStress()-core.getCoreStress())/core.getMaxCoreStress()
        end
    end
    if CCSPercent < 25 and CCSPercent > 5 and db_1 then
        db_1.clearValue('homeBaseLocation')
        if transponder_1 then transponder_1.setTags({}) end
    elseif CCSPercent == 0 and shieldPercent < 5 then
        db_1.clearValue('homeBaseLocation')
        if transponder_1 then transponder_1.setTags({}) end
    end
    if (shield_1 and shieldPercent < 15) or showAlerts then
        hw = hw .. string.format([[
        <svg width="]].. tostring(.06 * screenWidth) ..[[" height="]].. tostring(.06 * screenHeight) ..[[" x="]].. tostring(.40 * screenWidth) ..[[" y="]].. tostring(.60 * screenHeight) ..[[" style="fill: red;">
            ]]..warningSymbols['svgCritical']..[[
        </svg>
        <text x="]].. tostring(.45 * screenWidth) ..[[" y="]].. tostring(.64 * screenHeight) ..[[" style="fill: red" font-size="3.42vh" font-weight="bold">SHIELD CRITICAL</text>
        ]])
    elseif (shield_1 and shieldPercent < 30) or showAlerts then
        hw = hw .. string.format([[
        <svg width="]].. tostring(.06 * screenWidth) ..[[" height="]].. tostring(.06 * screenHeight) ..[[" x="]].. tostring(.40 * screenWidth) ..[[" y="]].. tostring(.60 * screenHeight) ..[[" style="fill: orange;">
            ]]..warningSymbols['svgWarning']..[[
        </svg>
        <text x="]].. tostring(.45 * screenWidth) ..[[" y="]].. tostring(.64 * screenHeight) ..[[" style="fill: orange" font-size="3.42vh" font-weight="bold">SHIELD LOW</text>
        ]])
    end
    hw = hw .. '</svg>'
    hw = hw .. [[
        <svg style="position: absolute; top: ]]..hpWidgetY..[[vh; left: ]]..hpWidgetX..[[vw;" viewBox="0 0 355 97" width="]]..tostring(hpWidgetScale)..[[vw">
            <polyline style="fill-opacity: 0; stroke-linejoin: round; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" points="2 78.902 250 78.902 276 50" bx:origin="0.564202 0.377551"/>
            <polyline style="stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" points="225 85.853 253.049 85.853 271 67.902" bx:origin="-1.23913 -1.086291"/>
            <rect x="26.397" y="158.28" width="59" height="9" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" transform="matrix(1, 0.000076, 0, 1, -24.396999, -79.380203)" bx:origin="2.813559 -3.390291"/>
            <rect x="4.921" y="123.131" width="11" height="7" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" transform="matrix(1, 0.000076, 0, 1, -2.921, -35.229931)" bx:origin="15.090909 -5.644607"/>
            <rect x="4.921" y="123.111" width="11" height="6.999" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" transform="matrix(1, 0.000106, 0, 1, 13.079, -35.20953)" bx:origin="13.636364 -5.645962"/>
            <rect x="4.921" y="123.111" width="11" height="6.999" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" transform="matrix(1, 0.000106, 0, 1, 29.078999, -35.20953)" bx:origin="12.181818 -5.645719"/>
            <rect x="4.921" y="123.111" width="11" height="6.999" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[; fill: none;" transform="matrix(1, 0.000106, 0, 1, 45.078999, -35.20953)" bx:origin="10.727273 -5.645477"/>
            ]]
    local placement = 0
    for i = 4, CCSPercent, 4 do 
        hw = hw .. [[<line style="stroke-width: 5px; stroke-miterlimit: 1; stroke: ]]..ccsHPColor..[[; fill: none;" x1="]]..tostring(5+placement)..[["   y1="56" x2="]]..tostring(5+placement)..[["   y2="72" bx:origin="0 0.096154"/>]]  placement = placement + 10
    end
            
    hw = hw .. [[
            <line style="stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="5" y1="25.706" x2="5" y2="39.508" bx:origin="0 1.607143"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="14.859" y1="31.621" x2="14.859" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="24.718" y1="31.684" x2="24.718" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="34.576" y1="31.684" x2="34.576" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="44.435" y1="31.621" x2="44.435" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="54.294" y1="31.621" x2="54.294" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="64.153" y1="31.621" x2="64.153" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="74.012" y1="31.621" x2="74.012" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="83.871" y1="31.621" x2="83.871" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="93.729" y1="31.621" x2="93.729" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="103.588" y1="31.684" x2="103.588" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="113.447" y1="31.684" x2="113.447" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="123.306" y1="31.621" x2="123.306" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="133.165" y1="31.621" x2="133.165" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="143.023" y1="31.621" x2="143.023" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="152.882" y1="31.621" x2="152.882" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="162.741" y1="31.621" x2="162.741" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="172.6" y1="31.621" x2="172.6" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="182.459" y1="31.684" x2="182.459" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="192.318" y1="31.684" x2="192.318" y2="39.571" bx:origin="0 2.0545"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="202.176" y1="31.621" x2="202.176" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="212.035" y1="31.621" x2="212.035" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="221.894" y1="31.621" x2="221.894" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="231.753" y1="31.621" x2="231.753" y2="39.508" bx:origin="0 2.0625"/>
            <line style="paint-order: fill; stroke-miterlimit: 1; stroke-linecap: round; fill: none; stroke: ]]..neutralLineColor..[[;" x1="245" y1="25.706" x2="245" y2="39.508" bx:origin="0 1.535714"/>
            <text style="fill: ]]..shieldHPColor..[[; font-family: Arial; font-size: 11.8px; white-space: pre;" x="15" y="28.824" bx:origin="-2.698544 2.296589">Shield:</text>
            <text style="fill: rgb(255, 240, 25); font-family: Arial; font-size: 6.70451px; stroke-width: 0.25px; white-space: pre;" transform="matrix(1.017081, 0, 0, 0.89492, -12.273296, 5.679566)" x="16" y="89.114" bx:origin="3.495402 -4.692753">Incoming Damage</text>
            <text style="fill: rgb(255, 240, 25); font-family: Arial; font-size: 5.58709px; line-height: 8.93935px; stroke-width: 0.25px; white-space: pre;" transform="matrix(1.017081, 0, 0, 0.89492, 73.924286, 48.558426)" x="16" y="89.114" dx="-83.506" dy="-39.079" bx:origin="35.484825 -7.519482">A</text>
            <text style="fill: rgb(255, 240, 25); font-family: Arial; font-size: 5.58709px; line-height: 8.93935px; stroke-width: 0.25px; white-space: pre;" transform="matrix(1.017081, 0, 0, 0.89492, 98.152718, 71.789642)" x="16" y="89.114" dx="-91.857" dy="-65.038" bx:origin="38.374239 -7.519481">E</text>
            <text style="fill: rgb(255, 240, 25); font-family: Arial; font-size: 5.58709px; line-height: 8.93935px; stroke-width: 0.25px; white-space: pre;" transform="matrix(1.017081, 0, 0, 0.89492, 106.659058, 48.558426)" x="16" y="89.114" dx="-83.506" dy="-39.079" bx:origin="33.936403 -7.519482">T</text>
            <text style="fill: rgb(255, 240, 25); font-family: Arial; font-size: 5.58709px; line-height: 8.93935px; stroke-width: 0.25px; white-space: pre;" transform="matrix(1.017081, 0, 0, 0.89492, 121.659058, 48.558426)" x="16" y="89.114" dx="-83.506" dy="-39.079" bx:origin="27.291514 -7.519482">K</text>
            <text style="fill: ]]..shieldHPColor..[[; font-family: Arial; font-size: 11.8px; white-space: pre;" x="53.45" y="28.824" bx:origin="-2.698544 2.296589">]]..string.format('%.2f',shieldPercent)..[[%</text>
            <text style="fill: ]]..ccsHPColor..[[; font-family: Arial; font-size: 11.8px; white-space: pre;" x="153" y="28.824" bx:origin="-2.698544 2.296589">CCS:</text>
            <text style="fill: ]]..ccsHPColor..[[; font-family: Arial; font-size: 11.8px; white-space: pre;" x="182.576" y="28.824" bx:origin="-2.698544 2.296589">]]..string.format('%.2f',CCSPercent)..[[%</text>
            
            ]]
            if shield_1 then
                local ventCD = shield_1.getVentingCooldown()
                if ventCD > 0 then
                    hw = hw .. [[
                        <text style="fill: ]]..warning_outline_color..[[; font-family: Arial; font-size: 11.8px; paint-order: fill; white-space: pre;" x="66" y="91.01" bx:origin="-2.698544 2.296589">Vent Cooldown: </text>
                        <text style="fill: ]]..warning_outline_color..[[; font-family: Arial; font-size: 11.8px; paint-order: fill; white-space: pre;" x="151" y="91.01" bx:origin="-2.698544 2.296589">]]..string.format('%.2f',ventCD)..[[s</text>
                    ]]
                end
            end
    local placement = 0
    for i = 4, shieldPercent, 4 do 
        hw = hw .. [[<line style="stroke-width: 5px; stroke-miterlimit: 1; stroke: ]]..shieldHPColor..[[; fill: none;" x1="]]..tostring(5+placement)..[["   y1="42" x2="]]..tostring(5+placement)..[["   y2="55" bx:origin="0 0.096154"/>]]  placement = placement + 10
    end

    hw = hw .. '</svg>'

    return hw
end

function resistWidget()
    local rw = ''

    local stress = shield_1.getStressRatioRaw()
    local amS = stress[1]
    local emS = stress[2]
    local knS = stress[3]
    local thS = stress[4]

    local srp = shield_1.getResistancesPool()
    local csr = shield_1.getResistances()
    local amR = csr[1]/srp
    local emR = csr[2]/srp
    local knR = csr[3]/srp
    local thR = csr[4]/srp

    local resistTimer = shield_1.getResistancesCooldown()
    local resistTimerPer = 1 - resistTimer/shield_1.getResistancesMaxCooldown()
    local resistTimerColor = shieldHPColor
    if resistTimer > 0 then resistTimerColor = warning_outline_color end 

    if shield_1.isVenting() == 0 then
        warnings['venting'] = nil
    else 
        warnings['venting'] = 'svgCritical'
    end

    rw = [[
        <svg style="position: absolute; top: ]]..resistWidgetY..[[vh; left: ]]..resistWidgetX..[[vw;" viewBox="0 0 143 127" width="]]..resistWidgetScale..[[vw">
            <defs>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="stress-am">
                    <stop offset="]]..tostring(amS*100)..[[%" style="stop-color: ]]..antiMatterColor..[[; stop-opacity: 1"/>
                    <stop offset="]]..tostring(amS*100)..[[%" style="stop-color: ]]..neutralLineColor..[[; stop-opacity:.5"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="stress-th">
                    <stop offset="]]..tostring(thS*100)..[[%" style="stop-color: ]]..thermicColor..[[; stop-opacity: 1"/>
                    <stop offset="]]..tostring(thS*100)..[[%" style="stop-color: ]]..neutralLineColor..[[; stop-opacity:.5"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="stress-em">
                    <stop offset="]]..tostring(emS*100)..[[%" style="stop-color: ]]..electroMagneticColor..[[; stop-opacity: 1"/>
                    <stop offset="]]..tostring(emS*100)..[[%" style="stop-color: ]]..neutralLineColor..[[; stop-opacity:.5"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="stress-kn">
                    <stop offset="]]..tostring(knS*100)..[[%" style="stop-color: ]]..kineticColor..[[; stop-opacity: 1"/>
                    <stop offset="]]..tostring(knS*100)..[[%" style="stop-color: ]]..neutralLineColor..[[; stop-opacity:.5"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="resist-am">
                    <stop offset="]]..tostring(amR*100)..[[%" style="stop-color: ]]..antiMatterColor..[["/>
                    <stop offset="]]..tostring(amR*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="resist-em">
                    <stop offset="]]..tostring(emR*100)..[[%" style="stop-color: ]]..electroMagneticColor..[["/>
                    <stop offset="]]..tostring(emR*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="resist-th">
                    <stop offset="]]..tostring(thR*100)..[[%" style="stop-color: ]]..thermicColor..[["/>
                    <stop offset="]]..tostring(thR*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                </linearGradient>
                <linearGradient x1="100%" y1="0%" x2="0%" y2="100%" id="resist-kn">
                    <stop offset="]]..tostring(knR*100)..[[%" style="stop-color: ]]..kineticColor..[[;"/>
                    <stop offset="]]..tostring(knR*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                </linearGradient>
                <linearGradient x1="0%" y1="50%" x2="100%" y2="50%" id="resist-timer-horizontal" gradientUnits="userSpaceOnUse">
                    <stop offset="]]..tostring(resistTimerPer*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                    <stop offset="]]..tostring(resistTimerPer*100)..[[%" style="stop-color: ]]..warning_outline_color..[[;"/>  
                </linearGradient>
                <linearGradient x1="50%" y1="0%" x2="50%" y2="80%" id="resist-timer-vertical" gradientUnits="userSpaceOnUse">
                    <stop offset="]]..tostring(resistTimerPer*100)..[[%" style="stop-color: ]]..neutralLineColor..[[;"/>
                    <stop offset="]]..tostring(resistTimerPer*100)..[[%" style="stop-color: ]]..warning_outline_color..[[;"/>  
                </linearGradient>
            </defs>
            <ellipse style="fill: none; stroke: ]]..neutralLineColor..[[;" cx="73" cy="61" rx="8" ry="8"/>
            <ellipse style="fill: ]]..neutralLineColor..[[; stroke: ]]..neutralLineColor..[[;" cx="73" cy="61" rx="2" ry="2"/>
            <polyline style="fill: none; stroke-linejoin: bevel; stroke-linecap: round; stroke: ]]..neutralLineColor..[[;" points="53 30 35 61 53 93"/>
            <polyline style="fill: none; stroke-linejoin: bevel; stroke-linecap: round; stroke: ]]..neutralLineColor..[[;" points="92 30 110 61 92 93"/>
            <polyline style="fill: none; stroke-linecap: round; stroke-linejoin: bevel; stroke: ]]..neutralLineColor..[[;" points="90 35 105 61 90 89"/>
            <polyline style="fill: none; stroke-linecap: round; stroke-linejoin: bevel; stroke: ]]..neutralLineColor..[[;" points="55 35 40 61 55 89"/>
            <line style="fill: none; stroke-width: 0.5px; stroke: url(#resist-timer-horizontal);" x1="17" y1="61" x2="128" y2="61"/>
            <line style="fill: none; stroke-width: 0.5px; stroke: url(#resist-timer-vertical);" x1="72.888" y1="-9.275" x2="72.888" y2="101.725" transform="matrix(1, 0, 0, 1, 0.112056, 14.27536)"/>
            <text style="fill: ]]..antiMatterColor..[[; font-size: 8px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="55.182" y="51.282">AM</text>
            <text style="fill: ]]..electroMagneticColor..[[; font-size: 8px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="78" y="51.282">EM</text>
            <text style="fill: ]]..thermicColor..[[; font-size: 8px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="78" y="77.282">TH</text>
            <text style="fill: ]]..kineticColor..[[; font-size: 8px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="55" y="77.282">KN</text>
            <path style="fill: none; stroke-width: 3px; stroke-linecap: round; stroke: url(#stress-am);" d="M 15 59 C 45.52 58.894 71.021 34.344 71 3" transform="matrix(-1, 0, 0, -1, 86.000015, 62)"/>
            <path style="fill: none; stroke-width: 3px; stroke-linecap: round; stroke: url(#stress-th);" d="M 75 119 C 105.52 118.894 131.021 94.344 131 63"/>
            <path style="fill: none; stroke-width: 3px; stroke-linecap: round; stroke: url(#stress-em);" d="M 75 59 C 105.52 58.894 131.021 34.344 131 3" transform="matrix(0, -1, 1, 0, 72.000008, 134.000008)"/>
            <path style="fill: none; stroke-width: 3px; stroke-linecap: round; stroke: url(#stress-kn);" d="M 15 119 C 45.52 118.894 71.021 94.344 71 63" transform="matrix(0, 1, -1, 0, 134.000008, 47.999992)"/>
            <path style="fill: none; stroke-linecap: round; stroke: url(#resist-am); stroke-width: 5px;" d="M 25 56 C 48.435 55.92 68.016 37.068 68 13" transform="matrix(-1, 0, 0, -1, 93.000015, 69)"/>
            <path style="fill: none; stroke-linecap: round; stroke: url(#resist-em); stroke-width: 5px;" d="M 78 56 C 101.435 55.919 121.016 37.068 121 13" transform="matrix(0, -1, 1, 0, 65.000004, 134.000004)"/>
            <path style="fill: none; stroke-linecap: round; stroke: url(#resist-th); stroke-width: 5px;" d="M 78 109 C 101.435 108.919 121.016 90.068 121 66"/>
            <path style="fill: none; stroke-linecap: round; stroke: url(#resist-kn); stroke-width: 5px;" d="M 24 109 C 47.435 108.919 67.016 90.068 67 66" transform="matrix(0, 1, -1, 0, 133.000008, 41.999992)"/>
            </svg>
    ]]
    return rw
end

function transponderWidget()
    local tw = ''
    if transponder_1 ~= nil then
        local transponderColor = warning_outline_color
        local transponderStatus = 'offline'
        if transponder_1.isActive() == 1 then transponderColor = shieldHPColor transponderStatus = 'Active' end
        local tags = transponder_1.getTags()

        local x,y,s
        if minimalWidgets then
            y = transponderWidgetYmin
            x = transponderWidgetXmin
            s = transponderWidgetScalemin
        else
            y = transponderWidgetY
            x = transponderWidgetX
            s = transponderWidgetScale
        end

        tw = [[
            <svg style="position: absolute; top: ]]..y..[[vh; left: ]]..x..[[vw;" viewBox="0 0 286 ]]..tostring(101+#tags*24)..[[" width="]]..s..[[vw">
                <rect x="6%" y="12%" width="87%" height="79%" rx="1%" ry="1%" fill="rgba(100,100,100,.9)" />
                <polygon style="stroke-width: 2px; stroke-linejoin: round; fill: ]]..bgColor..[[; stroke: ]]..lineColor..[[;" points="22 15 266 15 266 32 252 46 22 46"/>
                <polygon style="stroke-linejoin: round; fill: ]]..bgColor..[[; stroke: ]]..lineColor..[[;" points="18 17 12 22 12 62 15 66 15 ]]..tostring(81+#tags*24)..[[ 18 ]]..tostring(83+#tags*24)..[["/>
                <text style="fill: ]]..fontColor..[[; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="37" y="35">Transponder Status:</text>
                <text style="fill: ]]..transponderColor..[[; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="190" y="35">]]..transponderStatus..[[</text>
            ]]


        for i,tag in pairs(tags) do
            local code = 'redacted'
            if codeCount > 0 then code = tag end
            tw = tw .. [[<line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="]]..tostring(54+(i-1)*27)..[[" x2="22" y2="]]..tostring(80.7+(i-1)*27)..[["/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="]]..tostring(73+(i-1)*27)..[[">]]..code..[[</text>]]
        end
        tw = tw .. '</svg>'
    end

    return tw
end

function minimalShipInfo()
    local msi = ''

    local bg = bgColor
    local apStatus = 'inactive'
    if auto_follow then bg = 'rgba(99, 250, 79, 0.5)' apStatus = 'following' end
    if autopilot then bg = 'rgba(99, 250, 79, 0.5)' apStatus = 'Engaged' end
    if not autopilot and autopilot_dest ~= nil then apStatus = 'Set' end

    local eta = ''
    if autopilot_dest and speed > 1000 then
        local balance = vec3(autopilot_dest - constructPosition):len()/(speed/3.6) --meters/(meter/second) == seconds
        local seconds = balance % 60 if seconds < 10 then seconds = string.format('0%.0f',seconds) else seconds = string.format('%.0f',seconds) end
        balance = balance // 60
        local minutes = balance % 60 if minutes < 10 then minutes = string.format('0%.0f',minutes) else minutes = string.format('%.0f',minutes) end
        balance = balance // 60
        local hours = balance % 60
        eta = string.format(' (ETA %.0f:%s.%s)',hours,minutes,seconds)
    end

    msi = msi .. [[
        <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
            <text x="]].. tostring(.001 * screenWidth) ..[[" y="]].. tostring(.015 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.42vh" font-weight="bold">Auto Pilot Mode: ]]..apStatus..eta..[[</text>]]
    if caerusOption then
        msi = msi .. [[<text x="]].. tostring(.547 * screenWidth) ..[[" y="]].. tostring(.92 * screenHeight) ..[[" style="fill: ]]..topHUDFillColorSZ..[[" font-size="1.42vh" font-weight="bold">Speed: ]] .. formatNumber(speed,'speed') .. [[</text>]]
    end
    msi = msi .. [[</svg>
    ]]

    msi = msi .. [[
        <svg style="position: absolute; top: ]]..shipInfoWidgetY..[[vh; left: ]]..shipInfoWidgetX..[[vw;" viewBox="0 0 286 260" width="]]..shipInfoWidgetScale..[[vw">
            <polygon style="stroke-width: 2px; stroke-linejoin: round; fill: ]]..bgColor..[[; stroke: ]]..lineColor..[[;" points="22 15 266 15 266 32 252 46 22 46"/>
            <polygon style="stroke-linejoin: round; fill: ]]..bg..[[; stroke: ]]..lineColor..[[;" points="18 17 12 22 12 62 15 66 15 258 18 260"/>
            <text style="fill: ]]..fontColor..[[; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="37" y="35">]]..string.format('%s (%s)',construct.getName(),pilotName)..[[</text>
        ]]
    msi = msi .. [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="54" x2="22" y2="77"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="40" y="73">Top Speed:</text>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 18px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="137" y="73" font-family: "monospace";>]]..formatNumber(maxSpeed,'speed')..[[</text>

            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="81" x2="22" y2="104"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="40" y="100">Brake Dist:</text>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 18px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="137" y="100" font-family: "monospace";>]]..formatNumber(brakeDist,'distance')..[[</text>

        ]]

    msi = msi .. '</svg>'

    curFuel = 0
    local fuelWarning = false
    local fuelTankWarning = false
    for i,v in pairs(spacefueltank) do 
        curFuel = curFuel + v.getItemsVolume()
        if v.getItemsVolume()/v.getMaxVolume() < .2 then fuelTankWarning = true end
    end
    sFuelPercent = curFuel/maxFuel * 100
    if sFuelPercent < 20 then fuelWarning = true end
    curFuelStr = string.format('%.2f%%',sFuelPercent)

    msi = msi .. string.format([[
        <svg width="100%%" height="100%%" style="position: absolute;left:0%%;top:0%%;font-family: Calibri;">
            <linearGradient id="sFuel-vertical" x1="0%%" y1="100%%" x2="0%%" y2="0%%">
            <stop offset="%.1f%%" style="stop-color:rgba(99, 250, 79, 0.95);stop-opacity:.95" />
            <stop offset="%.1f%%" style="stop-color:rgba(255, 10, 10, 0.5);stop-opacity:.5" />
            </linearGradient>]],sFuelPercent,sFuelPercent)


    if Nav.axisCommandManager:getMasterMode() == controlMasterModeId.travel then mode = 'Throttle ' .. tostring(Nav.axisCommandManager:getThrottleCommand(0) * 100) .. '%' modeBG = fuelTextColor
    else mode = 'Cruise '  .. string.format('%.2f',Nav.axisCommandManager:getTargetSpeed(0)) .. ' km/h' modeBG = 'rgba(99, 250, 79, 0.5)'
    end
    msi = msi .. [[
                <path d="
                    M ]] .. tostring(.843*screenWidth) .. ' ' .. tostring(.052*screenHeight) .. [[
                    L ]] .. tostring(.843*screenWidth) .. ' ' .. tostring(.185*screenHeight) .. [[
                    L ]] .. tostring(.848*screenWidth) .. ' ' .. tostring(.185*screenHeight) .. [[
                    L ]] .. tostring(.848*screenWidth) .. ' ' .. tostring(.052*screenHeight) .. [[
                    L ]] .. tostring(.843*screenWidth) .. ' ' .. tostring(.052*screenHeight) .. [["
                    stroke="]]..lineColor..[[" stroke-width="1" fill="url(#sFuel-vertical)" />
                <text x="]].. tostring(.80 * screenWidth) ..[[" y="]].. tostring(.198 * screenHeight) ..[[" style="fill: ]]..fuelTextColor..[[" font-size="1.32vh" font-weight="bold">Fuel: ]] .. curFuelStr .. [[</text>]]
    if caerusOption then
        msi = msi .. [[<text x="]].. tostring(.547 * screenWidth) ..[[" y="]].. tostring(.90 * screenHeight) ..[[" style="fill: ]]..modeBG..[[" font-size="1.32vh" font-weight="bold">]] .. mode .. [[</text>]]
    else
        msi = msi .. [[<text x="]].. tostring(.80 * screenWidth) ..[[" y="]].. tostring(.2115 * screenHeight) ..[[" style="fill: ]]..modeBG..[[" font-size="1.32vh" font-weight="bold">]] .. mode .. [[</text>]]
    end    
    msi = msi .. [[</svg>
        ]]

    if fuelTankWarning or fuelWarning or showAlerts then
        fuelWarningText = 'Fuel level &lt; 20%'
        if not fuelWarning then fuelWarningText = 'A Fuel tank &lt; 20%%' end
        warnings['lowFuel'] = 'svgWarning'
    else
        warnings['lowFuel'] = nil
    end

    msi = msi .. '</svg>'

    return msi
end

function globalDB(action)
    if db_1 ~= nil then
        if action == 'get' then
            if db_1.hasKey('generateAutoCode') == 1 then generateAutoCode = db_1.getIntValue('generateAutoCode') == 1 end
            if db_1.hasKey('toggleBrakes') == 1 then toggleBrakes = db_1.getIntValue('toggleBrakes') == 1 end
            if db_1.hasKey('caerusOption') == 1 then caerusOption = db_1.getIntValue('caerusOption') == 1 end
            if db_1.hasKey('validatePilot') == 1 then validatePilot = db_1.getIntValue('validatePilot') == 1 end
            if db_1.hasKey('showRemotePanel') == 1 then showRemotePanel = db_1.getIntValue('showRemotePanel') == 1 end
            if db_1.hasKey('showDockingPanel') == 1 then showDockingPanel = db_1.getIntValue('showDockingPanel') == 1 end
            if db_1.hasKey('showFuelPanel') == 1 then showFuelPanel = db_1.getIntValue('showFuelPanel') == 1 end
            if db_1.hasKey('showHelper') == 1 then showHelper = db_1.getIntValue('showHelper') == 1 end
            if db_1.hasKey('defaultHoverHeight') == 1 then defaultHoverHeight = db_1.getIntValue('defaultHoverHeight') end
            if db_1.hasKey('topHUDLineColorSZ') == 1 then topHUDLineColorSZ = db_1.getStringValue('topHUDLineColorSZ') end
            if db_1.hasKey('topHUDFillColorSZ') == 1 then topHUDFillColorSZ = db_1.getStringValue('topHUDFillColorSZ') end
            if db_1.hasKey('textColorSZ') == 1 then textColorSZ = db_1.getStringValue('textColorSZ') end
            if db_1.hasKey('topHUDLineColorPVP') == 1 then topHUDLineColorPVP = db_1.getStringValue('topHUDLineColorPVP') end
            if db_1.hasKey('topHUDFillColorPVP') == 1 then topHUDFillColorPVP = db_1.getStringValue('topHUDFillColorPVP') end
            if db_1.hasKey('textColorPVP') == 1 then textColorPVP = db_1.getStringValue('textColorPVP') end
            if db_1.hasKey('fuelTextColor') == 1 then fuelTextColor = db_1.getStringValue('fuelTextColor') end
            if db_1.hasKey('Direction_Indicator_Size') == 1 then Direction_Indicator_Size = db_1.getFloatValue('Direction_Indicator_Size') end
            if db_1.hasKey('Direction_Indicator_Color') == 1 then Direction_Indicator_Color = db_1.getStringValue('Direction_Indicator_Color') end
            if db_1.hasKey('Prograde_Indicator_Size') == 1 then Prograde_Indicator_Size = db_1.getFloatValue('Prograde_Indicator_Size') end
            if db_1.hasKey('Prograde_Indicator_Color') == 1 then Prograde_Indicator_Color = db_1.getStringValue('Prograde_Indicator_Color') end
            if db_1.hasKey('AP_Brake_Buffer') == 1 then AP_Brake_Buffer = db_1.getFloatValue('AP_Brake_Buffer') end
            if db_1.hasKey('AP_Max_Rotation_Factor') == 1 then AP_Max_Rotation_Factor = db_1.getFloatValue('AP_Max_Rotation_Factor') end
            if db_1.hasKey('AR_Mode') == 1 then AR_Mode = db_1.getStringValue('AR_Mode') end
            if db_1.hasKey('AR_Range') == 1 then AR_Range = db_1.getFloatValue('AR_Range') end
            if db_1.hasKey('AR_Size') == 1 then AR_Size = db_1.getFloatValue('AR_Size') end
            if db_1.hasKey('AR_Fill') == 1 then AR_Fill = db_1.getStringValue('AR_Fill') end
            if db_1.hasKey('AR_Outline') == 1 then AR_Outline = db_1.getStringValue('AR_Outline') end
            if db_1.hasKey('AR_Opacity') == 1 then AR_Opacity = db_1.getStringValue('AR_Opacity') end
            if db_1.hasKey('AR_Exclude_Moons') == 1 then AR_Exclude_Moons = db_1.getIntValue('AR_Exclude_Moons') == 1 end
            if db_1.hasKey('EngineTagColor') == 1 then EngineTagColor = db_1.getStringValue('EngineTagColor') end
            if db_1.hasKey('Indicator_Width') == 1 then Indicator_Width = db_1.getFloatValue('Indicator_Width') end
            if db_1.hasKey('warning_size') == 1 then warning_size = db_1.getFloatValue('warning_size') end
            if db_1.hasKey('warning_outline_color') == 1 then warning_outline_color = db_1.getStringValue('warning_outline_color') end
            if db_1.hasKey('warning_fill_color') == 1 then warning_fill_color = db_1.getStringValue('warning_fill_color') end
            if db_1.hasKey('useLogo') == 1 then useLogo = db_1.getIntValue('useLogo') == 1 end
            if db_1.hasKey('logoSVG') == 1 then logoSVG = db_1.getStringValue('logoSVG') end
            if db_1.hasKey('minimalWidgets') == 1 then minimalWidgets = db_1.getIntValue('minimalWidgets') == 1 end
            if db_1.hasKey('homeBaseLocation') == 1 then homeBaseLocation = db_1.getStringValue('homeBaseLocation') end
            if db_1.hasKey('homeBaseDistance') == 1 then homeBaseDistance = db_1.getIntValue('homeBaseDistance') end

            if db_1.hasKey('autoVent') == 1 then autoVent = db_1.getIntValue('autoVent') == 1 end

            if db_1.hasKey('hpWidgetX') == 1 then hpWidgetX = db_1.getFloatValue('hpWidgetX') end
            if db_1.hasKey('hpWidgetY') == 1 then hpWidgetY = db_1.getFloatValue('hpWidgetY') end
            if db_1.hasKey('hpWidgetScale') == 1 then hpWidgetScale = db_1.getFloatValue('hpWidgetScale') end
            if db_1.hasKey('shieldHPColor') == 1 then shieldHPColor = db_1.getStringValue('shieldHPColor') end
            if db_1.hasKey('ccsHPColor') == 1 then ccsHPColor = db_1.getStringValue('ccsHPColor') end

            if db_1.hasKey('resistWidgetX') == 1 then resistWidgetX = db_1.getFloatValue('resistWidgetX') end
            if db_1.hasKey('resistWidgetY') == 1 then resistWidgetY = db_1.getFloatValue('resistWidgetY') end
            if db_1.hasKey('resistWidgetScale') == 1 then resistWidgetScale = db_1.getFloatValue('resistWidgetScale') end
            if db_1.hasKey('antiMatterColor') == 1 then antiMatterColor = db_1.getStringValue('antiMatterColor') end
            if db_1.hasKey('electroMagneticColor') == 1 then electroMagneticColor = db_1.getStringValue('electroMagneticColor') end
            if db_1.hasKey('kineticColor') == 1 then kineticColor = db_1.getStringValue('kineticColor') end
            if db_1.hasKey('thermicColor') == 1 then thermicColor = db_1.getStringValue('thermicColor') end

            if db_1.hasKey('transponderWidgetX') == 1 then transponderWidgetX = db_1.getFloatValue('transponderWidgetX') end
            if db_1.hasKey('transponderWidgetY') == 1 then transponderWidgetY = db_1.getFloatValue('transponderWidgetY') end
            if db_1.hasKey('transponderWidgetScale') == 1 then transponderWidgetScale = db_1.getFloatValue('transponderWidgetScale') end
            if db_1.hasKey('transponderWidgetXmin') == 1 then transponderWidgetXmin = db_1.getFloatValue('transponderWidgetXmin') end
            if db_1.hasKey('transponderWidgetYmin') == 1 then transponderWidgetYmin = db_1.getFloatValue('transponderWidgetYmin') end
            if db_1.hasKey('transponderWidgetScalemin') == 1 then transponderWidgetScalemin = db_1.getFloatValue('transponderWidgetScalemin') end

        elseif action == 'save' then
            if generateAutoCode then db_1.setIntValue('generateAutoCode',1) else db_1.setIntValue('generateAutoCode',0) end
            if toggleBrakes then db_1.setIntValue('toggleBrakes',1) else db_1.setIntValue('toggleBrakes',0) end
            if caerusOption then db_1.setIntValue('caerusOption',1) else db_1.setIntValue('caerusOption',0) end
            if showRemotePanel then db_1.setIntValue('showRemotePanel',1) else db_1.setIntValue('showRemotePanel',0) end
            if showDockingPanel then db_1.setIntValue('showDockingPanel',1) elsedb_1.setIntValue('showDockingPanel',0) end
            if showFuelPanel then db_1.setIntValue('showFuelPanel',1) else db_1.setIntValue('showFuelPanel',0) end
            if showHelper then db_1.setIntValue('showHelper',1) else db_1.setIntValue('showHelper',0) end
            if validatePilot then db_1.setIntValue('validatePilot',1) else db_1.setIntValue('validatePilot',0) end
            db_1.setIntValue('defaultHoverHeight',defaultHoverHeight)
            db_1.setStringValue('topHUDLineColorSZ',topHUDLineColorSZ)
            db_1.setStringValue('topHUDFillColorSZ',topHUDFillColorSZ)
            db_1.setStringValue('textColorSZ',textColorSZ)
            db_1.setStringValue('topHUDLineColorPVP',topHUDLineColorPVP)
            db_1.setStringValue('topHUDFillColorPVP',topHUDFillColorPVP)
            db_1.setStringValue('textColorPVP',textColorPVP)
            db_1.setStringValue('fuelTextColor',fuelTextColor)
            db_1.setFloatValue('Direction_Indicator_Size',Direction_Indicator_Size)
            db_1.setStringValue('Direction_Indicator_Color',Direction_Indicator_Color)
            db_1.setFloatValue('Prograde_Indicator_Size',Prograde_Indicator_Size) 
            db_1.setStringValue('Prograde_Indicator_Color',Prograde_Indicator_Color) 
            db_1.setFloatValue('AP_Brake_Buffer',AP_Brake_Buffer)
            db_1.setFloatValue('AP_Max_Rotation_Factor',AP_Max_Rotation_Factor)
            db_1.setStringValue('AR_Mode',AR_Mode)
            db_1.setFloatValue('AR_Range',AR_Range)
            db_1.setFloatValue('AR_Size',AR_Size)
            db_1.setStringValue('AR_Fill',AR_Fill)
            db_1.setStringValue('AR_Outline',AR_Outline)
            db_1.setStringValue('AR_Opacity',AR_Opacity)
            db_1.setStringValue('EngineTagColor',EngineTagColor)
            db_1.setFloatValue('Indicator_Width',Indicator_Width)
            db_1.setFloatValue('warning_size',warning_size)
            if AR_Exclude_Moons then db_1.setIntValue('AR_Exclude_Moons',1) else db_1.setIntValue('AR_Exclude_Moons',0) end
            db_1.setStringValue('warning_outline_color',warning_outline_color)
            db_1.setStringValue('warning_fill_color',warning_fill_color)
            if useLogo then db_1.setIntValue('useLogo',1) else db_1.setIntValue('useLogo',0) end
            db_1.setStringValue('logoSVG',logoSVG)
            if minimalWidgets then db_1.setIntValue('minimalWidgets',1) else db_1.setIntValue('minimalWidgets',0) end
            if homeBaseLocation then db_1.setStringValue('homeBaseLocation',homeBaseLocation) end
            db_1.setIntValue('homeBaseDistance',homeBaseDistance)
            if autoVent then db_1.setIntValue('autoVent',1) else db_1.setIntValue('autoVent',0) end

            db_1.setFloatValue('hpWidgetX',hpWidgetX)
            db_1.setFloatValue('hpWidgetY',hpWidgetY)
            db_1.setFloatValue('hpWidgetScale',hpWidgetScale)
            db_1.setStringValue('shieldHPColor',shieldHPColor)
            db_1.setStringValue('ccsHPColor',ccsHPColor)

            db_1.setFloatValue('resistWidgetX',resistWidgetX)
            db_1.setFloatValue('resistWidgetY',resistWidgetY)
            db_1.setFloatValue('resistWidgetScale',resistWidgetScale)
            db_1.setStringValue('antiMatterColor',antiMatterColor)
            db_1.setStringValue('electroMagneticColor',electroMagneticColor)
            db_1.setStringValue('kineticColor',kineticColor)
            db_1.setStringValue('thermicColor',thermicColor)

            db_1.setFloatValue('transponderWidgetX',transponderWidgetX)
            db_1.setFloatValue('transponderWidgetY',transponderWidgetY)
            db_1.setFloatValue('transponderWidgetScale',transponderWidgetScale)
            db_1.setFloatValue('transponderWidgetXmin',transponderWidgetXmin)
            db_1.setFloatValue('transponderWidgetYmin',transponderWidgetYmin)
            db_1.setFloatValue('transponderWidgetScalemin',transponderWidgetScalemin)
        end
    end
end

function WeaponWidgetCreate()
    if type(weapon) == 'table' and #weapon > 0 then
        local _panel = system.createWidgetPanel("Weapons")
        weaponDataList = {}
        for i = 1, #weapon do
            local weaponDataID = weapon[i].getWidgetDataId()
            local widgetType = weapon[i].getWidgetType()
            local _widget = system.createWidget(_panel, "weapon")
            system.addDataToWidget(weaponDataID,system.createWidget(_panel, widgetType))
            if i % maxWeaponsPerWidget == 0 and i < #weapon then _panel = system.createWidgetPanel("Weapons") end
        end
    end
end

function updateRadar(filter)
    local data = radar_1.getWidgetData()

    local radarList = radar_1.getConstructIds()
    local constructList = {}
    if #radarList > max_radar_load then radarOverload = true else radarOverload = false end
    radarContactNumber = #radarList

    local enemyLShips = 0
    local friendlyLShips = 0
    
    local shipsBySize = {}
    shipsBySize['XS'] = {}
    shipsBySize['S'] = {}
    shipsBySize['M'] = {}
    shipsBySize['L'] = {}

    local localIdentifiedBy = 0
    local localAttackedBy = 0
    local tempRadarStats = {
        ['enemy'] = {
            ['L'] = 0,
            ['M'] = 0,
            ['S'] = 0,
            ['XS'] = 0
        },
        ['friendly'] = {
            ['L'] = 0,
            ['M'] = 0,
            ['S'] = 0,
            ['XS'] = 0
        }
    }
    
    local target = tostring(radar_1.getTargetId())
    --for n,id in pairs(radarList) do
    local n = 0
    for id in data:gmatch('{"constructId":"([%d%.]*)"') do
        local identified = radar_1.isConstructIdentified(id) == 1--construct.isIdentified--
        local shipType = radar_1.getConstructKind(id)
        local abandonded = radar_1.isConstructAbandoned(id) == 1
        local nameOrig = radar_1.getConstructName(id) --construct.name--
        if abandonded then
            local core_pos = radar_1.getConstructWorldPos(id)
            if write_db then
                if write_db.hasKey('abnd-'..tostring(id)) then
                    if write_db.getStringValue('abnd-'..tostring(id)) ~= string.format('::pos{0,0,%.2f,%.2f,%.2f}',core_pos[1],core_pos[2],core_pos[3]) then
                        write_db.setStringValue('abnd-'..tostring(id),string.format('::pos{0,0,%.2f,%.2f,%.2f}',core_pos[1],core_pos[2],core_pos[3]))
                        write_db.setStringValue('abnd-name-'..tostring(id),nameOrig)
                    end
                else
                    write_db.setStringValue('abnd-'..tostring(id),string.format('::pos{0,0,%.2f,%.2f,%.2f}',core_pos[1],core_pos[2],core_pos[3]))
                    write_db.setStringValue('abnd-name-'..tostring(id),nameOrig)
                end
            end
        end

        if  (radarOverload and shipType == 5 and not abandonded) or identified or id == target or (not radarOverload and not (hideAbandonedCores and abandonded)) then
            local shipSize = radar_1.getConstructCoreSize(id)--construct.size--
            local threatLevel = radar_1.getThreatRateFrom(id)--construct.targetThreatState--
            if threatLevel == 2 then localIdentifiedBy = localIdentifiedBy + 1
            elseif threatLevel == 5 then localAttackedBy = localAttackedBy + 1
            end
            local tMatch = radar_1.hasMatchingTransponder(id) == 1
            local name = nameOrig--:gsub('%[',''):gsub('%]','')
            nameOrig = nameOrig:gsub('%]','%%]'):gsub('%[','%%['):gsub('%(','%%('):gsub('%)','%%)')
            local uniqueCode = string.sub(tostring(id),-3)
            local uniqueName = string.format('[%s] %s',uniqueCode,name)
            if tMatch then 
                local owner = radar_1.getConstructOwnerEntity(id)
                if owner['isOrganization'] then
                    owner = system.getOrganization(owner['id'])
                    uniqueName = string.format('[%s] %s',owner['tag'],name)
                else
                    owner = system.getPlayerName(owner['id'])
                    uniqueName = string.format('[%s] %s',owner,name)
                end
            elseif abandonded then
                uniqueName = string.format('[CORED] %s',name)
            end

            local shipIDMatch = false
            if useShipID then for k,v in pairs(friendlySIDs) do if id == k then shipIDMatch = true end end end
            local friendly = tMatch or shipIDMatch
            
            if shipType == 5 and not abandonded then
                if friendly then tempRadarStats['friendly'][shipSize] = tempRadarStats['friendly'][shipSize] + 1
                else tempRadarStats['enemy'][shipSize] = tempRadarStats['enemy'][shipSize] + 1
                end
            end

            if contains(filterSize,shipSize) or tostring(id) == target then
                if filter == 'enemy' and not friendly then
                    local rawData = data:gmatch('{"constructId":"'..tostring(id)..'"[^}]*}[^}]*}') 
                    for str in rawData do
                        local replacedData = str:gsub(nameOrig,uniqueName)
                        if identified then
                            table.insert(constructList,1,replacedData)
                        elseif radarSort == 'Size' then
                            table.insert(shipsBySize[shipSize],replacedData)
                        else
                            table.insert(constructList,replacedData)
                        end
                    end
                elseif filter == 'identified' and identified then
                    local rawData = data:gmatch('{"constructId":"'..tostring(id)..'"[^}]*}[^}]*}') 
                    for str in rawData do
                        local replacedData = str:gsub(nameOrig,uniqueName)
                        if radarSort == 'Size' then
                            table.insert(shipsBySize[shipSize],replacedData)
                        else
                            table.insert(constructList,replacedData)
                        end
                    end
                elseif filter == 'friendly' and friendly then
                    local rawData = data:gmatch('{"constructId":"'..tostring(id)..'"[^}]*}[^}]*}') 
                    for str in rawData do
                        local replacedData = str:gsub(nameOrig,uniqueName)
                        if identified then
                            table.insert(constructList,1,replacedData)
                        elseif radarSort == 'Size' then
                            table.insert(shipsBySize[shipSize],replacedData)
                        else
                            table.insert(constructList,replacedData)
                        end
                    end
                elseif filter == 'primary' and tostring(primary) == uniqueCode then
                    local rawData = data:gmatch('{"constructId":"'..tostring(id)..'"[^}]*}[^}]*}') 
                    for str in rawData do
                        local replacedData = str:gsub(nameOrig,uniqueName)
                        if identified then
                            table.insert(constructList,1,replacedData)
                        elseif radarSort == 'Size' then
                            table.insert(shipsBySize[shipSize],replacedData)
                        else
                            table.insert(constructList,replacedData)
                        end
                    end
                elseif radarFilter == 'All' then
                    local rawData = data:gmatch('{"constructId":"'..tostring(id)..'"[^}]*}[^}]*}') 
                    for str in rawData do
                        local replacedData = str:gsub(nameOrig,uniqueName)
                        if identified or tostring(id) == target then
                            table.insert(constructList,1,replacedData)
                        elseif radarSort == 'Size' then
                            table.insert(shipsBySize[shipSize],replacedData)
                        else
                            table.insert(constructList,replacedData)
                        end
                    end
                end
            end
            if n % 150 == 0 then coroutine.yield() end
        end
        n = n + 1
    end

    coroutine.yield()
    data = data:gsub('{"constructId[^}]*}[^}]*},*', "")
    data = data:gsub('"errorMessage":""','"errorMessage":"'..radarFilter..'-'..radarSort..'"')
    if radarSort == 'Size' then
        for _,ship in pairs(shipsBySize['XS']) do table.insert(constructList,ship) end
        for _,ship in pairs(shipsBySize['S']) do table.insert(constructList,ship) end
        for _,ship in pairs(shipsBySize['M']) do table.insert(constructList,ship) end
        for _,ship in pairs(shipsBySize['L']) do table.insert(constructList,ship) end
        data = data:gsub('"constructsList":%[%]','"constructsList":['..table.concat(constructList,',')..']')
    else
        data = data:gsub('"constructsList":%[%]','"constructsList":['..table.concat(constructList,',')..']')
    end

    radarStats = tempRadarStats
    radarWidgetData = data
    identifiedBy = localIdentifiedBy
    attackedBy = localAttackedBy
    return data
end

function RadarWidgetCreate()
    local _data = radar_1.getWidgetData()--updateRadar(radarFilter)
    local _panel = system.createWidgetPanel("RADAR")
    local _widget = system.createWidget(_panel, "radar")
    radarDataID = system.createData(_data)
    system.addDataToWidget(radarDataID, _widget)
    return radarDataID
end

function weaponsWidget()
    local ww = '<svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">'
    local wtext = ''
    if weapon_size > 0 then
        local wStatus = {[1] = 'Idle', [2] = 'Firing', [4] = 'Reloading', [5] = 'Unloading'}
        ww = ww .. [[
            <line x1="]].. 0.02*screenWidth ..[[" y1="]].. 0.665*screenHeight ..[[" x2="]].. 0.15*screenWidth ..[[" y2="]].. 0.665*screenHeight ..[[" style="stroke:]]..neutralLineColor..[[;stroke-width:0.25;opacity:]].. 1 ..[[;" />
            ]]
        local offset = 1
        for i,w in pairs(weapon) do
            local textColor = neutralFontColor
            local ammoColor = neutralFontColor
            local probColor = warning_outline_color
            if w.isOutOfAmmo() == 1 then ammoColor = warning_outline_color end

            local probs = w.getHitProbability()
            if probs > .7 then probColor = friendlyTextColor elseif probs > .5 then probColor = 'yellow' end
            
            local weaponName = w.getName():lower()

            local matches = {}
            for w in weaponName:gmatch("([^ ]+) ?") do table.insert(matches,w) end
            local prefix = matches[1]:sub(1,1) .. matches[2]:sub(1,1)
            local wtype = ''
            if string.find(weaponName,'cannon') then wType = 'Cannon'
            elseif string.find(weaponName,'railgun') then wType = 'Railgun'
            elseif string.find(weaponName,'missile') then wType = 'Missile'
            elseif string.find(weaponName,'laser') then wType = 'Laser'
            elseif string.find(weaponName,'stasis') then wType = 'Stasis'
            end
            if wType == 'Stasis' then
                weaponName = wType
            else
                weaponName = prefix .. wType
            end

            local ammoType = system.getItem(w.getAmmo())
            ammoType = tostring(ammoType['name']):lower()
            ammoTypeColor = neutralFontColor
            if string.find(ammoType,'antimatter') then ammoTypeColor = antiMatterColor ammoType = 'Antimatter'
            elseif string.find(ammoType,'electromagnetic') then ammoTypeColor = electroMagneticColor ammoType = 'ElectroMagnetic'
            elseif string.find(ammoType,'kinetic') then ammoTypeColor = kineticColor ammoType = 'Kinetic'
            elseif string.find(ammoType,'thermic') then ammoTypeColor = thermicColor ammoType = 'Thermic'
            end
            local weaponStr = string.format('<div style="position: absolute;font-weight: bold;font-size: .8vw;top: '.. tostring((0.66 - 0.015*i) * screenHeight) ..'px;left: '.. tostring(0.02* screenWidth) ..'px;"><div style="float: left;color: %s;">%s |&nbsp;</div><div style="float: left;color:%s;"> %.2f%% </div><div style="float: left;color: %s;"> | %s |&nbsp;</div><div style="float: left;color: %s;"> '..ammoType..'&nbsp;</div><div style="float: left;color: %s;">(%s) </div></div>',neutralFontColor,weaponName,probColor,probs*100,textColor,wStatus[w.getStatus()],ammoTypeColor,ammoColor,w.getAmmoCount())
            wtext = wtext .. weaponStr
            offset = i
        end
        offset = offset + 1
        ww = ww .. [[
            <line x1="]].. 0.02*screenWidth ..[[" y1="]].. (0.675-offset*0.015)*screenHeight ..[[" x2="]].. 0.15*screenWidth ..[[" y2="]].. (0.675-offset*0.015)*screenHeight ..[[" style="stroke:]]..neutralLineColor..[[;stroke-width:0.25;opacity:]].. 1 ..[[;" />
            ]]
    end
    ww = ww .. '</svg>' .. wtext
    return ww
end

function radarWidget()
    local rw = ''
    local friendlyShipNum = radarStats['friendly']['L'] + radarStats['friendly']['M'] + radarStats['friendly']['S'] + radarStats['friendly']['XS']
    local enemyShipNum = radarStats['enemy']['L'] + radarStats['enemy']['M'] + radarStats['enemy']['S'] + radarStats['enemy']['XS']
    local radarRangeString = formatNumber(radarRange,'distance')

    local x, y, s
    if minimalWidgets then 
        y = radarInfoWidgetYmin
        x = radarInfoWidgetXmin
        s = radarInfoWidgetScalemin
    else
        y = radarInfoWidgetY
        x = radarInfoWidgetX
        s = radarInfoWidgetScale
    end

    rw = rw .. string.format([[<div style="position: absolute;font-weight: bold;font-size: .8vw;top: ]].. tostring(.185 * screenHeight) ..'px;left: '.. tostring(.875 * screenWidth) ..[[px;">
    <div style="float: left;color: ]]..'white'..[[;">&nbsp;&nbsp;Identification Range:&nbsp;</div><div style="float: left;color: rgb(25, 247, 255);">%s&nbsp;</div></div>]],radarRangeString)
  

    rw = rw .. string.format([[<div style="position: absolute;font-weight: bold;font-size: .8vw;top: ]].. tostring(.15 * screenHeight) ..'px;left: '.. tostring(.90 * screenWidth) ..[[px;">
    <div style="float: left;color: ]]..'white'..[[;">Identified By:&nbsp;</div><div style="float: left;color: orange;">%.0f&nbsp;</div><div style="float: left;color: ]]..'white'..[[;">ships</div></div>]],identifiedBy)

    rw = rw .. string.format([[<div style="position: absolute;font-weight: bold;font-size: .8vw;top: ]].. tostring(.165 * screenHeight) ..'px;left: '.. tostring(.90 * screenWidth) ..[[px;">
    <div style="float: left;color: ]]..'white'..[[;">&nbsp;&nbsp;Attacked By:&nbsp;</div><div style="float: left;color: ]]..warning_outline_color..[[;">%.0f&nbsp;</div><div style="float: left;color: ]]..'white'..[[;">ships</div></div>]],attackedBy)

    rw = rw .. [[
        <svg style="position: absolute; top: ]]..y..[[vh; left: ]]..x..[[vw;" viewBox="0 0 286 240" width="]]..s..[[vw">
            <rect x="6%" y="6%" width="87%" height="52%" rx="1%" ry="1%" fill="rgba(100,100,100,.9)" />
            <polygon style="stroke-width: 2px; stroke-linejoin: round; fill: ]]..bgColor..[[; stroke: ]]..lineColor..[[;" points="22 15 266 15 266 32 252 46 22 46"/>
            <polygon style="stroke-linejoin: round; fill: ]]..bgColor..[[; stroke: ]]..lineColor..[[;" points="18 17 12 22 12 62 15 66 15 135 18 138"/>
            <text style="fill: ]]..fontColor..[[; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="37" y="35">Radar Information (]]..tostring(radarContactNumber)..[[)</text>
        ]]
    rw = rw .. [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="54" x2="22" y2="77"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="73">Enemy Ships:</text>
            <text style="fill: ]]..warning_outline_color..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="137" y="73">]]..enemyShipNum..[[</text>

            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="81" x2="22" y2="104"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="30" y="100">L:</text>
            <text style="fill: ]]..warning_outline_color..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="50" y="100">]]..radarStats['enemy']['L']..[[</text>

            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="68" y="100">M:</text>
            <text style="fill: ]]..warning_outline_color..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="95" y="100">]]..radarStats['enemy']['M']..[[</text>

            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="115" y="100">S:</text>
            <text style="fill: ]]..warning_outline_color..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="135" y="100">]]..radarStats['enemy']['S']..[[</text>

            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="155" y="100">XS:</text>
            <text style="fill: ]]..warning_outline_color..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="185" y="100">]]..radarStats['enemy']['XS']..[[</text>

            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="108" x2="22" y2="131"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="127">Friendly Ships:</text>
            <text style="fill: ]]..friendlyTextColor..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="150" y="127">]]..friendlyShipNum..[[</text>

        ]]

    rw = rw .. '</svg>'

    if attackedBy >= dangerWarning or showAlerts then
        warnings['attackedBy'] = 'svgWarning'
    else
        warnings['attackedBy'] = nil
    end

    if radarOverload or showAlerts then 
        warnings['radarOverload'] = 'svgCritical'
    else
        warnings['radarOverload'] = nil
    end
    return rw
end

function identifiedWidget()
    local id = radar_1.getTargetId()
    local iw = ''
    if id ~= 0 then
        if targetID == 0 then warnings['cored'] = nil warnings['friendly'] = nil end

        local targetSpeedSVG = ''

        local size = radar_1.getConstructCoreSize(id)
        local dmg = 0
        if write_db and dmgTracker[tostring(id)] then write_db.setFloatValue('damage - ' .. tostring(id) .. ' - ' .. pilotName,dmgTracker[tostring(id)]) end
        if #db > 0 then
            for _,dbName in pairs(db) do
                for _,key in pairs(dbName.getKeyList()) do
                    if string.starts(key,'damage - ' .. tostring(id)) then
                        dmg = dmg + dbName.getFloatValue(key)
                    end
                end
            end
        end
        if (dmg == 0 or not write_db) and dmgTracker[tostring(id)] then dmg = dmgTracker[tostring(id)] end
        local dmgRatio = clamp(dmg/shieldDmgTrack[size],0,1)
        if dmg < 1000 then dmg = string.format('%.2f',dmg)
        elseif dmg < 1000000 then dmg = string.format('%.2fk',dmg/1000)
        else dmg = string.format('%.2fm',dmg/1000000)
        end

        local tMatch = radar_1.hasMatchingTransponder(id) == 1
        local shipIDMatch = false
        if useShipID then for k,v in pairs(friendlySIDs) do if id == k then shipIDMatch = true end end end
        local friendly = tMatch or shipIDMatch

        local abandonded = radar_1.isConstructAbandoned(id) == 1
        local cardFill = warning_outline_color
        local cardText = textColorPVP
        if friendly then cardFill = bottomHUDFillColorSZ cardText = textColorSZ
        elseif abandonded then cardFill = 'darkgrey' cardText = 'black'
        end

        local distance = radar_1.getConstructDistance(id)
        local distString = formatNumber(distance,'distance')

        local name = radar_1.getConstructName(id)
        local uniqueCode = string.sub(tostring(id),-3)
        local shortName = name:sub(0,17)

        local lineColor = 'lightgrey'
        local targetIdentified = radar_1.isConstructIdentified(id) == 1


        if abandonded or showAlerts then warnings['cored'] = 'svgTarget' else warnings['cored'] = nil end
        if friendly or showAlerts then warnings['friendly'] = 'svgGroup' else warnings['friendly'] = nil end

        local speedVec = vec3(construct.getWorldVelocity())
        local mySpeed = speedVec:len() * 3.6
        local myMass = construct.getMass()

        local targetSpeedString = 'Not Identified'
        if targetIdentified then targetSpeed = radar_1.getConstructSpeed(id) * 3.6 targetSpeedString = formatNumber(targetSpeed,'speed') end
        local speedDiff = 0
        if targetIdentified then speedDiff = mySpeed-targetSpeed end
        
        local targetSpeedColor = neutralFontColor
        if targetIdentified then
            if speedDiff < -1000 then targetSpeedColor = warning_outline_color
            elseif speedDiff > 1000 then targetSpeedColor = 'rgb(56, 255, 56)'
            end
        end
        targetSpeedSVG = [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="54" x2="22" y2="77"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="73">Speed:</text>
            <text style="fill: ]]..targetSpeedColor..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="80" y="73">]]..targetSpeedString..[[</text>
        ]]

        local updateTimer = false
        if system.getArkTime() - lastUpdateTime > 0.5 and lastUpdateTime ~= 0 then 
            lastUpdateTime = system.getArkTime()
            updateTimer = true
        elseif lastUpdateTime == 0 then
            lastUpdateTime = system.getArkTime()
            lastDistance = distance
        end

        if updateTimer then
            local localGapCompare = 'Stable'
            local gap = distance - lastDistance
            if gap < -250 then localGapCompare = 'Closing' 
            elseif gap > 250 then localGapCompare = 'Parting'
            end
            gapCompare = localGapCompare
            lastDistance = distance
        end
        local gapColor = neutralFontColor
        if gapCompare == 'Closing' then gapColor = 'rgb(56, 255, 56)' elseif gapCompare == 'Parting' then gapColor = warning_outline_color end
        local distanceCompareSVG = [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="81" x2="22" y2="104"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="100">Gap:</text>
            <text style="fill: ]]..gapColor..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="65" y="100">]]..tostring(gapCompare)..[[</text>
        ]]

        if updateTimer and targetIdentified then
            local localSpeedCompare = 'No Change'
            if lastSpeed then
                local speedChange = targetSpeed - lastSpeed
                if speedChange < -100 then localSpeedCompare = 'Braking'
                elseif speedChange > 100 then localSpeedCompare = 'Accelerating'
                end
                speedCompare = localSpeedCompare
            end
            lastSpeed = targetSpeed
        elseif not targetIdentified then
            speedCompare = 'Not Identified'
        end
        local speedCompareColor = neutralFontColor
        if speedCompare == 'Braking' then speedCompareColor = warning_outline_color elseif speedCompare == 'Accelerating' then speedCompareColor = 'rgb(56, 255, 56)' end
        local speedCompareSVG = [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="108" x2="22" y2="131"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="127">&#8796;Speed:</text>
            <text style="fill: ]]..speedCompareColor..[[; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="95" y="127">]]..tostring(speedCompare)..[[</text>
        ]]

        local dmgSVG = [[
            <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="135" x2="22" y2="158"/>
            <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="154">Damage:</text>
            <text style="fill: orange; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="95" y="154">]]..string.format('%s (%.2f%%)',dmg,(1-dmgRatio)*100)..[[</text>
        ]]

        local mass = radar_1.getConstructMass(id)
        local topSpeed = (50000/3.6-10713*(mass-10000)/(853926+(mass-10000)))*3.6
        if targetIdentified then
            topSpeed = clamp(topSpeed,20000,50000)
        else
            topSpeed = 0
        end
        local topSpeedSVG = ''
        if topSpeed > 0 then
            topSpeedSVG = [[
                <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="162" x2="22" y2="185"/>
                <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="181">Top Speed:</text>
                <text style="fill: orange; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="110" y="181">]]..formatNumber(topSpeed,'speed')..[[</text>
            ]]
        end

        local info = radar_1.getConstructInfos(id)
        local weapons = 'False'
        if info['weapons'] ~= 0 then weapons = 'True' end
        local dataSVG = ''
        if targetIdentified then
            dataSVG = [[
                <line style="fill: none; stroke-linecap: round; stroke-width: 2px; stroke: ]]..neutralLineColor..[[;" x1="22" y1="189" x2="22" y2="212"/>
                <text style="fill: ]]..neutralFontColor..[[; font-size: 20px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="27" y="208">Armed:</text>
                <text style="fill: orange; font-size: 19px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="95" y="208">]]..weapons..[[</text>
            ]]
        end

        local owner = ''
        if radar_1.hasMatchingTransponder(id) == 1 then
            owner = radar_1.getConstructOwnerEntity(id)
            if owner['isOrganization'] then
                owner = system.getOrganization(owner['id'])
                owner = owner['tag']
            else
                owner = system.getPlayerName(owner['id'])
            end
        elseif friendlySIDs[id] then
            owner = friendlySIDs[id]
        end
        if owner ~= '' then 
            owner = [[<text style="fill: white; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="37" y="5">]]..string.format('Owned by: %s (%s)',owner,id)..[[</text>]]
        end

        local x,y,s
        y = 11.25
        x = 1.75
        s = 11.25
        iw = iw .. [[
            <svg style="position: absolute; top: ]]..y..[[vh; left: ]]..x..[[vw;" viewBox="0 -10 286 240" width="]]..s..[[vw">
                ]]..owner..[[
                <rect x="6%" y="6%" width="87%" height="90%" rx="1%" ry="1%" fill="rgba(100,100,100,.9)" />
                <polygon style="stroke-width: 2px; stroke-linejoin: round; fill: ]]..cardFill..[[; stroke: ]]..lineColor..[[;" points="22 15 266 15 266 32 252 46 22 46"/>
                <polygon style="stroke-linejoin: round; fill: ]]..cardFill..[[; stroke: ]]..lineColor..[[;" points="18 17 12 22 12 62 15 66 15 225 18 227"/>
                <text style="fill: ]]..cardText..[[; font-size: 17px; paint-order: fill; stroke-width: 0.5px; white-space: pre;" x="37" y="35">]]..string.format('%s - [%s] %s (%s)',size,uniqueCode,shortName,distString)..[[</text>
                ]]..targetSpeedSVG..[[
                ]]..distanceCompareSVG..[[
                ]]..speedCompareSVG..[[
                ]]..dmgSVG

        if targetIdentified then
            iw = iw .. topSpeedSVG .. dataSVG
        end

        iw = iw.. [[
            </svg>
        ]]

        if targetIndicators or showAlerts then
            iw = iw .. [[
                <svg width="100%" height="100%" style="position: absolute;left:0%;top:0%;font-family: Calibri;">
                    <svg width="]].. tostring(.03 * screenWidth) ..[[" height="]].. tostring(.03 * screenHeight) ..[[" x="]].. tostring(.30 * screenWidth) ..[[" y="]].. tostring(.50 * screenHeight) ..[[" style="fill: ]]..speedCompareColor..[[;">
                        ]]..warningSymbols['svgTarget']..[[
                    </svg>
                    <text x="]].. tostring(.327 * screenWidth) ..[[" y="]].. tostring(.51 * screenHeight) .. [[" style="fill: ]]..neutralFontColor..[[;" font-size="1.7vh" font-weight="bold">Speed Change:</text>
                    <text x="]].. tostring(.390 * screenWidth) ..[[" y="]].. tostring(.51 * screenHeight) .. [[" style="fill: ]]..speedCompareColor..[[;" font-size="1.7vh" font-weight="bold">]]..speedCompare..[[</text>
                    <text x="]].. tostring(.359 * screenWidth) ..[[" y="]].. tostring(.53 * screenHeight) .. [[" style="fill: ]]..neutralFontColor..[[;" font-size="1.7vh" font-weight="bold">Speed: </text>
                    <text x="]].. tostring(.390 * screenWidth) ..[[" y="]].. tostring(.53 * screenHeight) .. [[" style="fill: ]]..speedCompareColor..[[;" font-size="1.7vh" font-weight="bold">]]..targetSpeedString..[[</text>
                </svg>
            ]]
        end
    end
    return iw
end

function generateScreen()
    if db_1 and db_1.hasKey('minimalWidgets') then
        minimalWidgets = db_1.getIntValue('minimalWidgets') == 1
    end 
    html = [[ <html> <body style="font-family: Calibri;"> ]]
    html = html .. brakeWidget()
    if showScreen then 
        if minimalWidgets then
            html = html .. minimalShipInfo()
        else
            html = html .. flightWidget()
            html = html .. fuelWidget()
            html = html .. apStatusWidget()
            html = html .. positionInfoWidget()
            html = html .. shipNameWidget()
            html = html .. weaponsWidget()
            html = html .. radarWidget()
            html = html .. identifiedWidget()
        end
        if transponder_1 then html = html .. transponderWidget() end
        html = html .. hpWidget()
        if shield_1 then html = html .. resistWidget() end
        html = html .. engineWidget()
        if useLogo then
            html = html .. [[<svg viewBox="0 0 500 500" width="5vw" height="5vh" style="position: absolute; top: 7vh; left: 0vw;">]] .. logoSVG .. [[
                </svg>]]
        end
    end
    html = html .. planetARWidget()
    html = html .. helpWidget()
    html = html .. travelIndicatorWidget()
    html = html .. warningsWidget()

    html = html .. [[ </body> </html> ]]
    system.setScreen(html)
end

Kinematic = {} -- just a namespace
local ITERATIONS = 100 -- iterations over engine "warm-up" period

function Kinematic.computeAccelerationTime(initial, acceleration, final)
    -- ans: t = (vf - vi)/a
    return (final - initial)/acceleration
end

function Kinematic.computeDistanceAndTime(initial,final,mass,thrust,t50,brakeThrust)

    t50            = t50 or 0
    brakeThrust    = brakeThrust or 0 -- usually zero when accelerating

    local speedUp  = initial < final
    local a0       = thrust / (speedUp and mass or -mass)
    local b0       = -brakeThrust/mass
    local totA     = a0+b0

    if initial == final then
        return 0, 0   -- trivial
    elseif speedUp and totA <= 0 or not speedUp and totA >= 0 then
        return -1, -1 -- no solution
    end

    local distanceToMax, timeToMax = 0, 0

    if a0 ~= 0 and t50 > 0 then

        local c1  = math.pi/t50/2

        local v = function(t)
            return a0*(t/2 - t50*math.sin(c1*t)/math.pi) + b0*t + initial
        end

        local speedchk = speedUp and function(s) return s >= final end or
                                     function(s) return s <= final end
        timeToMax  = 2*t50

        if speedchk(v(timeToMax)) then
            local lasttime = 0

            while math.abs(timeToMax - lasttime) > 0.25 do
                local t = (timeToMax + lasttime)/2
                if speedchk(v(t)) then
                    timeToMax = t 
                else
                    lasttime = t
                end
            end
        end

        -- Closed form solution for distance exists (t <= 2*t50):
        local K       = 2*a0*t50^2/math.pi^2
        distanceToMax = K*(math.cos(c1*timeToMax) - 1) +
                        (a0+2*b0)*timeToMax^2/4 + initial*timeToMax

        if timeToMax < 2*t50 then
            return distanceToMax, timeToMax
        end
        initial = v(timeToMax)
    end
    -- At full thrust, motion follows Newton's formula:
    local a = a0+b0
    local t = Kinematic.computeAccelerationTime(initial, a, final)
    local d = initial*t + a*t*t/2
    return distanceToMax+d, timeToMax+t
end

function Kinematic.computeTravelTime(initial, acceleration, distance)
    if distance == 0 then return 0 end
    if acceleration ~= 0 then
        return (math.sqrt(2*acceleration*distance+initial^2) - initial)/
                    acceleration
    end
    assert(initial > 0, 'Acceleration and initial speed are both zero.')
    return distance/initial
end

function isNumber(n)  return type(n)           == 'number' end
function isSNumber(n) return type(tonumber(n)) == 'number' end
function isTable(t)   return type(t)           == 'table'  end
function isString(s)  return type(s)           == 'string' end
function isVector(v)  return isTable(v) and isNumber(v.x and v.y and v.z) end

clamp = utils.clamp

Transform = {}

function Transform.computeHeading(planetCenter, position, direction)
    planetCenter   = vec3(planetCenter)
    position       = vec3(position)
    direction      = vec3(direction)
    local radius   = position - planetCenter
    if radius.x == 0 and radius.y == 0 then -- at north or south pole
        return radius.z >=0 and math.pi or 0
    end
    local chord    = planetCenter + vec3(0,0,radius:len()) - position
    local north    = chord:project_on_plane(radius):normalize_inplace()
    -- facing north, east is to the right
    local east     = north:cross(radius):normalize_inplace()
    local dir_prj  = direction:project_on_plane(radius):normalize_inplace()
    local adjacent = north:dot(dir_prj)
    local opposite = east:dot(dir_prj)
    local heading  = math.atan(opposite, adjacent) -- North==0

    if heading < 0 then heading = heading + 2*math.pi end
    if math.abs(heading - 2*math.pi) < .001 then heading = 0 end
    return heading
end

function Transform.computePRYangles(yaxis, zaxis, faxis, uaxis)
    yaxis = yaxis.x and yaxis or vec3(yaxis)
    zaxis = zaxis.x and zaxis or vec3(zaxis)
    faxis = faxis.x and faxis or vec3(faxis)
    uaxis = uaxis.x and uaxis or vec3(uaxis)
    local zproject = zaxis:project_on_plane(faxis):normalize_inplace()
    local adjacent = uaxis:dot(zproject)
    local opposite = faxis:cross(zproject):dot(uaxis)
    local roll     = math.atan(opposite, adjacent) -- rotate 'up' around 'fwd'
    local pitch    = math.asin(clamp(faxis:dot(zaxis), -1, 1))
    local fproject = faxis:project_on_plane(zaxis):normalize_inplace()
    local yaw      = math.asin(clamp(yaxis:cross(fproject):dot(zaxis), -1, 1))
    return pitch, roll, yaw
end