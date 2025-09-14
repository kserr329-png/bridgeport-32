-- client.lua - Dynamic NPCs, day/night synced from server, teleport markers, robbery triggers tied to proxies
local spawnedPeds = {}
local pedGroups = {} -- track peds per POI key
local serverHour = 12 -- default midday

-- load model helper
local function loadModel(hash)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) and (GetGameTimer() - t) < 5000 do
            Wait(5)
        end
    end
    return HasModelLoaded(hash)
end

local function randomPointAround(coord, radius)
    local angle = math.random() * math.pi * 2
    local r = math.random() * radius
    local dx = math.cos(angle) * r
    local dy = math.sin(angle) * r
    return vector3(coord.x + dx, coord.y + dy, coord.z)
end

local function spawnDynamicNPC(poiKey, model, coord, heading, behavior)
    pedGroups[poiKey] = pedGroups[poiKey] or {}
    if #pedGroups[poiKey] >= Config.maxNPCsPerPOI then return end

    local hash = GetHashKey(model)
    if not loadModel(hash) then return end
    local spawnCoords = randomPointAround(coord, 1.5)
    local ped = CreatePed(4, hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading or 0.0, false, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedRelationshipGroupHash(ped, GetHashKey("CIVMALE"))
    TaskWanderInArea(ped, coord.x, coord.y, coord.z, Config.spawnRadius, 100000, 0.0)
    table.insert(pedGroups[poiKey], ped)
    table.insert(spawnedPeds, ped)

    Citizen.CreateThread(function()
        while DoesEntityExist(ped) and not IsEntityDead(ped) do
            if math.random(1,10) <= 2 then
                TriggerEvent('chat:addMessage', { args = { '[Bridgeport NPC] ' .. (behavior or "The SDz be wildin'") } })
            end
            Wait(15000 + math.random(0,15000))
        end
        -- cleanup handled by manager
    end)
end

-- manager thread
Citizen.CreateThread(function()
    while not Locations do Wait(100); end
    while true do
        local sleep = 2000
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)
        for _, poi in ipairs(Locations.teleports) do
            local dist = #(playerCoords - poi.coord)
            local key = poi.name:gsub('%s+','_'):lower()
            if dist < 120.0 then
                sleep = 100
                pedGroups[key] = pedGroups[key] or {}
                local desired = 2
                if serverHour >= Config.nightStart or serverHour < Config.dayStart then
                    if poi.name:lower():find('massage') or poi.name:lower():find('brothel') or poi.name:lower():find('bridgeport homes') then
                        desired = 4
                    else
                        desired = 2
                    end
                else
                    if poi.name:lower():find('park') then desired = 3 end
                    if poi.name:lower():find('cpd') then desired = 2 end
                end

                while #pedGroups[key] < desired do
                    local model = 'a_m_m_skater_01'
                    local phrase = "The SDz be wildin'"
                    if poi.name:lower():find('cpd') then model = 's_m_y_cop_01'; phrase = 'CPD patrol.' end
                    if poi.name:lower():find('park') then model = 'a_f_y_hipster_01'; phrase = 'Nice day for the park.' end
                    if poi.name:lower():find('massage') or poi.name:lower():find('brothel') then model = 'a_m_m_beach_01'; phrase = 'You looking for something?' end
                    spawnDynamicNPC(key, model, poi.coord, 0.0, phrase)
                    Wait(400)
                end

                -- cleanup dead peds
                for i = #pedGroups[key], 1, -1 do
                    local ped = pedGroups[key][i]
                    if not DoesEntityExist(ped) or IsEntityDead(ped) then
                        table.remove(pedGroups[key], i)
                    end
                end
            else
                -- despawn extras if player far
                if pedGroups[key] and #pedGroups[key] > 1 then
                    while #pedGroups[key] > 1 do
                        local ped = table.remove(pedGroups[key])
                        if DoesEntityExist(ped) then DeleteEntity(ped) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('bridgeport:serverTime', function(hour)
    serverHour = hour
end)

Citizen.CreateThread(function()
    TriggerServerEvent('bridgeport:requestTime')
end)

-- Teleport markers & robbery interactions (same logic as before)
Citizen.CreateThread(function()
    while not Locations do Wait(100); end
    while true do
        local sleep = 1000
        local player = PlayerPedId()
        local pcoords = GetEntityCoords(player)
        for i, t in ipairs(Locations.teleports) do
            local dist = #(pcoords - t.coord)
            if dist < 60.0 then
                sleep = 5
                DrawMarker(2, t.coord.x, t.coord.y, t.coord.z + 0.25, 0,0,0,0,0,0,0.6,0.6,0.6, 255, 140, 0, 150, false, false, 2, nil, nil, false)
                if dist < 1.5 then
                    DrawText3D(t.coord.x, t.coord.y, t.coord.z + 0.6, '[E] Teleport to ' .. t.name)
                    if IsControlJustReleased(0, 38) then
                        DoScreenFadeOut(300); Wait(350)
                        SetEntityCoords(PlayerPedId(), t.coord.x, t.coord.y, t.coord.z, false, false, false, true)
                        DoScreenFadeIn(300)
                    end
                end
            end
        end
        for i, spot in ipairs(Locations.robberySpots) do
            local dist = #(pcoords - spot.coord)
            if dist < 25.0 then
                sleep = 5
                DrawMarker(1, spot.coord.x, spot.coord.y, spot.coord.z - 1.0, 0,0,0,0,0,0, 1.0,1.0,0.4, 0, 120, 200, 120, false, false, 2, nil, nil, false)
                if dist < spot.radius + 1.2 then
                    DrawText3D(spot.coord.x, spot.coord.y, spot.coord.z + 0.6, '[E] Start Robbery: ' .. spot.label)
                    if IsControlJustReleased(0, 38) then
                        TaskStartScenarioInPlace(player, 'WORLD_HUMAN_WELDING', 0, true)
                        TriggerServerEvent('bridgeport:attemptRobbery', i, spot.label, serverHour)
                        Wait(10000)
                        ClearPedTasks(player)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- toaster helper
function DrawText3D(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x,_y)
    end
end
