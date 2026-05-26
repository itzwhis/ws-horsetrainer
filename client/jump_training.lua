--[[
    rex-horsetrainer :: Jump Training Course
    --------------------------------------------------
    - Uses EXISTING stable fences in the map (no extra props).
    - Spawns a glowing ring marker + flame particle above each obstacle.
    - Validates real jumps (horse airborne + speed + altitude) before
      awarding XP. Walking through the ring without jumping is ignored.
    - Includes: cooldown, perfect-jump bonus, time-trial, course bonus,
      progress UI, sounds, multi-course config, leaderboard hook.
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Wait until shared Config table from config.lua is loaded
while not Config or not Config.JumpTraining do Wait(0) end

local JT          = Config.JumpTraining
local Courses     = Config.JumpCourses or {}

local activeRun   = nil           -- runtime state of an in-progress course
local lastRunAt   = 0             -- last finish/cancel time (cooldown)
local startBlips  = {}            -- per-course blip handles
local promptStart = nil           -- ox_lib / RedM prompt to start course

-- =================================================================
-- Utility
-- =================================================================
local function dbg(fmt, ...)
    if Config.Debug then
        print(('^3[rex-horsetrainer:jump] ' .. fmt .. '^7'):format(...))
    end
end

local function notify(msg, type)
    lib.notify({ title = 'Horse Training', description = msg, type = type or 'inform', duration = 4000 })
end

local function playSound(s)
    if not s then return end
    Citizen.InvokeNative(0x67C540AA08E4A6F5, s.name, s.set) -- PLAY_SOUND_FRONTEND
end

local function getActiveHorsePed()
    local ok, ped = pcall(function() return exports['rsg-horses']:CheckActiveHorse() end)
    if ok and ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
    return nil
end

local function getPlayerJobCourse()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local jobName = PlayerData and PlayerData.job and PlayerData.job.name
    if not jobName then return nil end
    return Courses[jobName], jobName
end

-- =================================================================
-- Blips + start prompt
-- =================================================================
CreateThread(function()
    if not JT.Enabled then return end
    for jobName, course in pairs(Courses) do
        if course.startPoint and course.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, course.startPoint.x, course.startPoint.y, course.startPoint.z)
            SetBlipSprite(blip, course.blip.sprite or -748118608, true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, course.blip.label or 'Jump Training') -- SET_BLIP_NAME_FROM_PLAYER_STRING
            startBlips[jobName] = blip
        end
    end
end)

-- =================================================================
-- Real-jump detection
-- A "real jump" = horse off the ground (not on a slope-walk),
-- altitude above ground >= MinJumpAltitude, and speed high enough.
-- =================================================================
local function isHorseRealJumping(horsePed)
    if not horsePed then return false, 0.0, 0.0 end
    local pos     = GetEntityCoords(horsePed)
    local speed   = GetEntitySpeed(horsePed)
    if speed < JT.MinCrossingSpeed then return false, 0.0, speed end

    -- IS_PED_JUMPING
    local jumping = Citizen.InvokeNative(0x4B7620C47217126C, horsePed)
    -- IS_ENTITY_IN_AIR
    local inAir   = IsEntityInAir(horsePed)

    local _, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
    local altitude   = pos.z - (groundZ or pos.z)

    local real = (jumping or inAir) and altitude >= JT.MinJumpAltitude
    return real, altitude, speed
end

-- =================================================================
-- Marker / particle rendering per obstacle
-- =================================================================
local function drawObstacleMarker(obstacle, isCurrent)
    local p = obstacle.pos
    local r, g, b = 255, 50, 50
    if isCurrent then r, g, b = 50, 255, 120 end
    Citizen.InvokeNative(0x2A32FAA57B937173,
        0xEC032ADD, -- MARKER_RING
        p.x, p.y, p.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        1.50, 1.50, 1.00,
        r, g, b, 200,
        false, false, 2, true, 0, 0, false)
end

local function startParticle(obstacle)
    if obstacle._ptfx then return end
    local dict = JT.Particle.dict
    RequestNamedPtfxAsset(dict)
    local tries = 0
    while not HasNamedPtfxAssetLoaded(dict) and tries < 50 do Wait(20); tries = tries + 1 end
    if not HasNamedPtfxAssetLoaded(dict) then return end
    Citizen.InvokeNative(0x6C38AF3693A69A91, dict) -- UseParticleFxAsset (RedM)
    local p = obstacle.pos
    obstacle._ptfx = Citizen.InvokeNative(0xF56B8137DF10135D, -- START_PARTICLE_FX_LOOPED_AT_COORD
        JT.Particle.name, p.x, p.y, p.z + 1.2,
        0.0, 0.0, 0.0, JT.Particle.scale, false, false, false, false)
end

local function stopParticle(obstacle)
    if obstacle._ptfx then
        StopParticleFxLooped(obstacle._ptfx, false)
        obstacle._ptfx = nil
    end
end

-- =================================================================
-- Progress UI (lightweight DrawText3D + bottom HUD via ox_lib)
-- =================================================================
local function drawProgressHud(run)
    local p = run.currentObstacle and run.course.obstacles[run.currentObstacle] and run.course.obstacles[run.currentObstacle].pos
    if not p then return end
    local elapsed = GetGameTimer() - run.startedAt
    local remaining = math.max(0, JT.MaxRunDuration - elapsed)
    SetTextScale(0.34, 0.34)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(true)
    Citizen.InvokeNative(0xADA9255D, 1) -- _SET_TEXT_FONT_FOR_CURRENT_COMMAND
    local txt = ('Jump %d/%d   |   %.1fs'):format(run.currentObstacle, #run.course.obstacles, remaining / 1000)
    SetDrawOrigin(p.x, p.y, p.z + 3.2, 0)
    Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', txt, Citizen.ResultAsLong())
    Citizen.InvokeNative(0xCD015E5BB0D96A57, 0.0, 0.0)
    ClearDrawOrigin()
end

-- =================================================================
-- Run lifecycle
-- =================================================================
local function endRun(success, reason)
    if not activeRun then return end
    for _, ob in ipairs(activeRun.course.obstacles) do stopParticle(ob) end

    local duration = GetGameTimer() - activeRun.startedAt
    if success then
        playSound(JT.Sounds.complete)
        local timeTrial = duration <= JT.TimeTrialTarget
        TriggerServerEvent('rex-horsetrainer:server:jumpCourseComplete', {
            jumps        = activeRun.jumpsDone,
            perfectJumps = activeRun.perfectJumps,
            durationMs   = duration,
            timeTrial    = timeTrial,
        })
        notify(('Course complete! %d jumps in %.1fs%s'):format(
            activeRun.jumpsDone, duration / 1000, timeTrial and ' (Time Trial!)' or ''), 'success')
    else
        playSound(JT.Sounds.fail)
        notify(('Training cancelled: %s'):format(reason or 'unknown'), 'error')
    end

    lastRunAt = GetGameTimer()
    activeRun = nil
end

local function startRun(course)
    if activeRun then return notify('Already in a training run', 'error') end
    if GetGameTimer() - lastRunAt < JT.Cooldown then
        local left = math.ceil((JT.Cooldown - (GetGameTimer() - lastRunAt)) / 1000)
        return notify(('Cooldown: wait %ds'):format(left), 'error')
    end

    local ped = PlayerPedId()
    if not IsPedOnMount(ped) then return notify('Mount your horse first', 'error') end
    local horsePed = getActiveHorsePed()
    if not horsePed or GetMount(ped) ~= horsePed then
        return notify('You must be on your active horse', 'error')
    end

    activeRun = {
        course          = course,
        currentObstacle = 1,
        jumpsDone       = 0,
        perfectJumps    = 0,
        startedAt       = GetGameTimer(),
        wasAirborne     = false,
    }
    for _, ob in ipairs(course.obstacles) do startParticle(ob) end
    notify('Training started — jump through the rings!', 'inform')
    dbg('Course started, obstacles=%d', #course.obstacles)
end

-- =================================================================
-- Main per-frame loop while a run is active
-- =================================================================
CreateThread(function()
    while true do
        if activeRun then
            local ped      = PlayerPedId()
            local horsePed = getActiveHorsePed()

            -- Safety: must stay mounted on own horse
            if not horsePed or not IsPedOnMount(ped) or GetMount(ped) ~= horsePed then
                endRun(false, 'dismounted')
                goto cont
            end

            -- Timeout
            if GetGameTimer() - activeRun.startedAt > JT.MaxRunDuration then
                endRun(false, 'time up')
                goto cont
            end

            -- Render all obstacle markers
            for i, ob in ipairs(activeRun.course.obstacles) do
                drawObstacleMarker(ob, i == activeRun.currentObstacle)
            end
            drawProgressHud(activeRun)

            -- Check current ring crossing + real jump
            local target = activeRun.course.obstacles[activeRun.currentObstacle]
            if target then
                local hp = GetEntityCoords(horsePed)
                local dx, dy, dz = hp.x - target.pos.x, hp.y - target.pos.y, hp.z - (target.pos.z + 1.0)
                local dist2D = math.sqrt(dx*dx + dy*dy)

                local real, altitude, speed = isHorseRealJumping(horsePed)

                -- Track airborne transition so the player can only "score" once per jump
                if real and not activeRun.wasAirborne then
                    activeRun.wasAirborne = true
                end

                if dist2D <= JT.RingRadius and math.abs(dz) <= JT.RingHeightTolerance then
                    if real and activeRun.wasAirborne then
                        local perfect = altitude >= (JT.MinJumpAltitude * 1.8) and speed >= (JT.MinCrossingSpeed * 1.3)
                        activeRun.jumpsDone = activeRun.jumpsDone + 1
                        if perfect then activeRun.perfectJumps = activeRun.perfectJumps + 1 end

                        TriggerServerEvent('rex-horsetrainer:server:jumpSuccess', { perfect = perfect })
                        playSound(perfect and JT.Sounds.perfect or JT.Sounds.success)
                        notify(('Jump %d/%d%s'):format(
                            activeRun.currentObstacle, #activeRun.course.obstacles,
                            perfect and ' — PERFECT!' or ''), 'success')

                        stopParticle(target)
                        activeRun.currentObstacle = activeRun.currentObstacle + 1
                        activeRun.wasAirborne     = false

                        if activeRun.currentObstacle > #activeRun.course.obstacles then
                            endRun(true)
                        end
                    end
                else
                    -- reset airborne flag once well past the ring & back on ground
                    if not real then activeRun.wasAirborne = false end
                end
            end

            Wait(0)
        else
            Wait(500)
        end
        ::cont::
    end
end)

-- =================================================================
-- Start-point interaction (ox_target sphere zone)
-- The E key is reserved by RedM for mount/dismount, so we use
-- ox_target's eye/peek system instead of a keypress prompt.
-- =================================================================
local registeredZones = {}

local function hasJobForCourse(jobName)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    return PlayerData and PlayerData.job and PlayerData.job.name == jobName
end

local function registerStartZones()
    if not JT.Enabled then return end
    if not exports.ox_target then return end

    for jobName, course in pairs(Courses) do
        if course.startPoint then
            local id = ('rex_horsetrainer_start_%s'):format(jobName)
            local zoneId = exports.ox_target:addSphereZone({
                coords = course.startPoint,
                radius = JT.TargetRadius or 1.6,
                debug  = Config.Debug,
                options = {
                    {
                        name   = id .. '_start',
                        label  = 'Start Jump Training',
                        icon   = 'fas fa-horse',
                        canInteract = function() return hasJobForCourse(jobName) and not activeRun end,
                        onSelect = function() startRun(course) end,
                    },
                    {
                        name   = id .. '_leaderboard',
                        label  = 'View Leaderboard',
                        icon   = 'fas fa-trophy',
                        canInteract = function() return hasJobForCourse(jobName) end,
                        onSelect = function()
                            TriggerServerEvent('rex-horsetrainer:server:requestLeaderboard')
                        end,
                    },
                },
            })
            registeredZones[#registeredZones+1] = zoneId
        end
    end
end

CreateThread(registerStartZones)

-- =================================================================
-- Leaderboard receiver
-- =================================================================
RegisterNetEvent('rex-horsetrainer:client:showLeaderboard', function(rows)
    if not rows or #rows == 0 then
        return notify('No leaderboard entries yet', 'inform')
    end
    local lines = {}
    for i, r in ipairs(rows) do
        lines[#lines+1] = ('%d. %s — %.2fs (%d jumps)'):format(i, r.name or r.citizenid, r.best_time/1000, r.total_jumps or 0)
    end
    lib.alertDialog({
        header = 'Jump Training — Leaderboard',
        content = table.concat(lines, '\n'),
        centered = true,
    })
end)

-- =================================================================
-- Cleanup on resource stop
-- =================================================================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if activeRun then
        for _, ob in ipairs(activeRun.course.obstacles) do stopParticle(ob) end
    end
    for _, b in pairs(startBlips) do RemoveBlip(b) end
    if exports.ox_target then
        for _, zid in ipairs(registeredZones) do
            pcall(function() exports.ox_target:removeZone(zid) end)
        end
    end
end)

-- =================================================================
-- Dev helper: /jumpdev prints player coords (for placing obstacles)
-- =================================================================
RegisterCommand('jumpdev', function()
    local p = GetEntityCoords(PlayerPedId())
    print(('vector3(%.2f, %.2f, %.2f)'):format(p.x, p.y, p.z))
end, false)
