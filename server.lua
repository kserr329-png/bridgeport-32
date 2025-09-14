-- server.lua - time sync + robbery handling (no external dispatch)
local cooldowns = {}

local function broadcastTime()
    while true do
        local hour = tonumber(os.date('%H'))
        TriggerClientEvent('bridgeport:serverTime', -1, hour)
        Citizen.Wait(30000) -- every 30s
    end
end

Citizen.CreateThread(function()
    broadcastTime()
end)

RegisterNetEvent('bridgeport:requestTime')
AddEventHandler('bridgeport:requestTime', function()
    local src = source
    local hour = tonumber(os.date('%H'))
    TriggerClientEvent('bridgeport:serverTime', src, hour)
end)

RegisterNetEvent('bridgeport:attemptRobbery')
AddEventHandler('bridgeport:attemptRobbery', function(index, label, hour)
    local src = source
    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < 60 then
        TriggerClientEvent('bridgeport:robberyResult', src, false, 0, 'Cooldown')
        return
    end
    cooldowns[src] = now

    local successChance = 0.55
    if hour >= 20 or hour < 6 then
        successChance = successChance * 1.2
    end

    local success = math.random() < successChance
    if success then
        local payout = math.random(200, 1200)
        -- try QBCore
        local given = false
        if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                Player.Functions.AddMoney('cash', payout, 'bridgeport-robbery')
                given = true
            end
        end
        TriggerClientEvent('bridgeport:robberyResult', src, true, payout, 'Success')
    else
        TriggerClientEvent('bridgeport:robberyResult', src, false, 0, 'Failed or police responded')
    end
end)
