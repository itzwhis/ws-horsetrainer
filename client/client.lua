local RSGCore = exports['rsg-core']:GetCoreObject()
local horsePed = nil
local horse = nil
local horseSpeed = 0
local horsespeedcheck = false
local horseEXP = 0
lib.locale()

local function GetTrainerStableForPlayer()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local jobName = PlayerData and PlayerData.job and PlayerData.job.name

    if not jobName then return nil, nil end

    local stable = Config.HorseTrainerStables and Config.HorseTrainerStables[jobName]
    if not stable then return nil, jobName end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local radius = stable.radius or Config.DefaultStableRadius or 70.0
    local distance = #(pedCoords - stable.coords)

    if distance > radius then
        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Outside stable zone - Job: %s, Distance: %.2f, Radius: %.2f^7'):format(jobName, distance, radius))
        end
        return nil, jobName
    end

    return stable, jobName
end

local function CanTrainHorse()
    local stable, jobName = GetTrainerStableForPlayer()
    if not stable then
        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Not allowed to gain horse XP - Job: %s^7'):format(tostring(jobName)))
        end
        return false
    end

    return true
end

--------------------------------------------------------------------
-- Riding horse XP loop
--------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.RidingWait)

        if (Config.TrainerRidingXP or 0) <= 0 then goto continue end
        if not LocalPlayer.state['isLoggedIn'] then goto continue end
        if not CanTrainHorse() then goto continue end

        local ped = PlayerPedId()

        horse = GetLastMount(ped)
        horsePed = exports['rsg-horses']:CheckActiveHorse()

        if not horsePed or not IsEntityAPed(horsePed) then goto continue end

        horseSpeed = GetEntitySpeed(horsePed)
        horsespeedcheck = horseSpeed > 5

        if horse ~= horsePed or not IsPedOnMount(ped) or IsPedStopped(horsePed) or not horsespeedcheck then
            goto continue
        end

        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Riding XP trigger - horsePed: %s, mounted: %s, speed: %.2f^7'):format(tostring(horsePed), tostring(IsPedOnMount(ped)), horseSpeed))
        end

        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
            if not data then
                print('^1[rex-horsetrainer] ERROR: GetActiveHorse callback returned nil^7')
                return
            end
            
            horseEXP = data.horsexp or 0
            if Config.Debug then
                print(('^3[rex-horsetrainer] DEBUG: Active horse XP: %d/5000^7'):format(horseEXP))
            end
            
            if horseEXP >= 5000 then 
                if Config.Debug then
                    print('^2[rex-horsetrainer] DEBUG: Horse maxed out at 5000 XP^7')
                end
                return 
            end

            if Config.Debug then
                print(('^3[rex-horsetrainer] DEBUG: Sending riding XP - Amount: %d^7'):format(Config.TrainerRidingXP))
            end
            TriggerServerEvent('rex-horsetrainer:server:updatexp', Config.TrainerRidingXP, 'ride')
        end)

        ::continue::
    end
end)

--------------------------------------------------------------------
-- Leading horse XP loop
--------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.LeadingWait)

        if not LocalPlayer.state['isLoggedIn'] then goto continue end
        if not CanTrainHorse() then goto continue end

        local ped = PlayerPedId()

        horse = GetLastMount(ped)
        horsePed = exports['rsg-horses']:CheckActiveHorse()

        if not horsePed or horsePed == 0 or horse == 0 then goto continue end
        if horse ~= horsePed or IsPedOnMount(ped) or IsPedStopped(horsePed) then goto continue end
        if not IsPedOnFoot(ped) then goto continue end
        if not IsPedLeadingHorse(horsePed) then goto continue end

        -- Strict anti-AFK / anti-whistle checks:
        -- 1) Player must actively be walking (not standing).
        -- 2) Horse must be close (lead-rope distance, not following via whistle).
        -- 3) Horse must be actually moving with the player.
        local pedSpeed   = GetEntitySpeed(ped)
        local horseSpd   = GetEntitySpeed(horsePed)
        local dist       = #(GetEntityCoords(ped) - GetEntityCoords(horsePed))
        if pedSpeed < 0.5 or horseSpd < 0.5 or dist > 4.0 then
            if Config.Debug then
                print(('^3[rex-horsetrainer] DEBUG: Lead rejected - pedSpd=%.2f horseSpd=%.2f dist=%.2f^7'):format(pedSpeed, horseSpd, dist))
            end
            goto continue
        end

        if Config.Debug then
            print(('^3[rex-horsetrainer] DEBUG: Leading XP trigger - horsePed: %s, leading: %s^7'):format(tostring(horsePed), tostring(IsPedLeadingHorse(horsePed))))
        end

        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
            if not data then
                print('^1[rex-horsetrainer] ERROR: GetActiveHorse callback returned nil^7')
                return
            end
            
            horseEXP = data.horsexp or 0
            if Config.Debug then
                print(('^3[rex-horsetrainer] DEBUG: Active horse XP: %d/5000^7'):format(horseEXP))
            end
            
            if horseEXP >= 5000 then
                if Config.Debug then
                    print('^2[rex-horsetrainer] DEBUG: Horse maxed out at 5000 XP^7')
                end
                return 
            end

            if Config.Debug then
                print(('^3[rex-horsetrainer] DEBUG: Sending leading XP - Amount: %d^7'):format(Config.TrainerLeadingXP))
            end
            TriggerServerEvent('rex-horsetrainer:server:updatexp', Config.TrainerLeadingXP, 'lead')
        end)

        ::continue::
    end
end)
