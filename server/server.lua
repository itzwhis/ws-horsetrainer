local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local function IsValidTrainingAction(action)
    return action == 'ride' or action == 'lead'
end

local function IsPlayerAllowedToTrain(src, Player)
    local jobName = Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name
    local stable = jobName and Config.HorseTrainerStables and Config.HorseTrainerStables[jobName]

    if not stable then
        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Player %s has no allowed trainer job. Job: %s^7'):format(src, tostring(jobName)))
        end
        return false
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local radius = stable.radius or Config.DefaultStableRadius or 70.0
    local distance = #(coords - stable.coords)

    if distance > radius then
        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Player %s outside stable zone. Job: %s, Distance: %.2f, Radius: %.2f^7'):format(src, jobName, distance, radius))
        end
        return false
    end

    return true
end

-------------------------------------
-- update horse xp
-------------------------------------
local lastXPAt = {} -- [src] = { ride = ms, lead = ms }

RegisterNetEvent('rex-horsetrainer:server:updatexp', function(amount, action)
    local src = source

    -- Server-side rate limit (anti-spam / anti-double-fire)
    local now = GetGameTimer()
    lastXPAt[src] = lastXPAt[src] or {}
    local minGap = (action == 'lead') and (Config.LeadingWait or 5000) - 250
                or (Config.RidingWait  or 5000) - 250
    if lastXPAt[src][action] and (now - lastXPAt[src][action]) < minGap then
        if Config.Debug then
            print(('^3[rex-horsetrainer] rate-limit (%s) src=%s^7'):format(action, src))
        end
        return
    end
    lastXPAt[src][action] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
        print(('^1[rex-horsetrainer] ERROR: Player object not found for source %s^7'):format(src))
        return
    end

    if not IsValidTrainingAction(action) then
        print(('^1[rex-horsetrainer] WARNING: Invalid training action (%s) from player %s^7'):format(tostring(action), src))
        return
    end

    if not IsPlayerAllowedToTrain(src, Player) then
        print(('^1[rex-horsetrainer] WARNING: Player %s tried to gain horse XP without valid trainer job/stable zone^7'):format(src))
        return
    end
    
    if not Player.PlayerData.citizenid then
        print(('^1[rex-horsetrainer] ERROR: CitizenID not found for source %s^7'):format(src))
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if Config.Debug then
        print(('^3[rex-horsetrainer] DEBUG: XP update received - Player: %s, Amount: %s, Action: %s^7'):format(citizenid, tostring(amount), tostring(action)))
    end

    -- check valid amount
    if type(amount) ~= 'number' or amount <= 0 or amount > Config.MaxXPGain then
        print(('^1[rex-horsetrainer] WARNING: Invalid XP amount (%s) from player %s^7'):format(tostring(amount), src))
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Horse Training',
            description = 'Invalid XP amount',
            type = 'error',
            duration = 5000
        })
        return
    end

    -- check if player has any horses at all
    local playerHorses = MySQL.query.await('SELECT id, active FROM player_horses WHERE citizenid = ?', { citizenid })
    if not playerHorses or #playerHorses == 0 then
        print(('^1[rex-horsetrainer] ERROR: No horses found for citizen %s^7'):format(citizenid))
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Horse Training',
            description = 'No horses found!',
            type = 'error',
            duration = 5000
        })
        return
    end

    -- check if an active horse exists
    local activeHorse = MySQL.query.await('SELECT id, horsexp FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if not activeHorse or not activeHorse[1] then
        print(('^3[rex-horsetrainer] WARNING: No active horse for citizen %s. Available horses: %d^7'):format(citizenid, #playerHorses))
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Horse Training',
            description = 'No active horse!',
            type = 'error',
            duration = 5000
        })
        return
    end

    local oldXP = activeHorse[1].horsexp or 0
    if oldXP >= 5000 then return end

    MySQL.update.await('UPDATE player_horses SET horsexp = LEAST(horsexp + ?, 5000) WHERE citizenid = ? AND active = 1', { amount, citizenid })

    local result = MySQL.query.await('SELECT horsexp, name FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if not result or not result[1] then return end

    local newXP      = result[1].horsexp
    local horseName  = result[1].name or 'Unnamed Horse'
    local playerName = ('%s %s'):format(
        Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Horse Training',
        description = ('XP increased! Current: %d/5000'):format(newXP),
        type = 'success',
        duration = 5000
    })

    if RexWebhook and RexWebhook.SendXP then
        RexWebhook.SendXP({
            playerName = playerName,
            horseName  = horseName,
            citizenid  = citizenid,
            action     = action,
            amount     = newXP - oldXP,
            oldXP      = oldXP,
            newXP      = newXP,
        })
    end
end)

-- ----------------------------------------------------------------
-- Shared award helper used by jump_training (server-side).
-- ----------------------------------------------------------------
function RexAwardXP(src, amount, action)
    if type(amount) ~= 'number' or amount <= 0 then return end
    if amount > Config.MaxXPGain then amount = Config.MaxXPGain end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.citizenid then return end
    local citizenid = Player.PlayerData.citizenid

    local row = MySQL.query.await(
        'SELECT horsexp, name FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if not row or not row[1] then return end

    local oldXP = row[1].horsexp or 0
    if oldXP >= 5000 then return end

    MySQL.update.await(
        'UPDATE player_horses SET horsexp = LEAST(horsexp + ?, 5000) WHERE citizenid = ? AND active = 1',
        { amount, citizenid })

    local newRow = MySQL.query.await(
        'SELECT horsexp FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    local newXP = (newRow and newRow[1] and newRow[1].horsexp) or (oldXP + amount)

    if RexWebhook and RexWebhook.SendXP then
        local playerName = ('%s %s'):format(
            Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
        RexWebhook.SendXP({
            playerName = playerName,
            horseName  = row[1].name or 'Unnamed Horse',
            citizenid  = citizenid,
            action     = action,
            amount     = newXP - oldXP,
            oldXP      = oldXP,
            newXP      = newXP,
        })
    end
end

AddEventHandler("playerDropped", function() lastXPAt[source] = nil end)
