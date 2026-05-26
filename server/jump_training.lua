--[[
    rex-horsetrainer :: Jump Training (server)
    --------------------------------------------------
    - Validates jump XP server-side (anti-cheat: rate limit + stable zone).
    - Stores leaderboard times in `horse_jump_leaderboard` table.
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

local JT = Config.JumpTraining

-- per-player rate limiter for single-jump events
local lastJumpAt   = {}   -- src -> ms
local jumpsInRun   = {}   -- src -> count
local runStartedAt = {}   -- src -> ms

-- Ensure leaderboard table exists
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS horse_jump_leaderboard (
            citizenid   VARCHAR(50) PRIMARY KEY,
            name        VARCHAR(100),
            best_time   INT NOT NULL,
            total_jumps INT NOT NULL DEFAULT 0,
            updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
end)

local function playerInsideAnyCourse(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for _, course in pairs(Config.JumpCourses or {}) do
        if course.startPoint and #(coords - course.startPoint) <= 80.0 then
            return true
        end
    end
    return false
end

local function awardXP(src, amount, reason)
    if amount <= 0 then return end
    if RexAwardXP then
        RexAwardXP(src, amount, reason)
    end
    if Config.Debug then
        print(('^2[rex-horsetrainer:jump] +%d XP (%s) -> src %s^7'):format(amount, reason, src))
    end
end

-- ----------------------------------------------------------------
-- Single jump success
-- ----------------------------------------------------------------
RegisterNetEvent('rex-horsetrainer:server:jumpSuccess', function(payload)
    local src = source
    payload = payload or {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- anti-spam: minimum gap between two jump events
    local now = GetGameTimer()
    if lastJumpAt[src] and (now - lastJumpAt[src]) < 1200 then
        print(('^1[rex-horsetrainer:jump] rate-limit hit for %s^7'):format(src))
        return
    end
    lastJumpAt[src] = now

    if not playerInsideAnyCourse(src) then
        print(('^1[rex-horsetrainer:jump] %s sent jumpSuccess outside any course^7'):format(src))
        return
    end

    jumpsInRun[src]   = (jumpsInRun[src] or 0) + 1
    runStartedAt[src] = runStartedAt[src] or now
    if jumpsInRun[src] > 8 then return end -- absolute cap per run

    local xp = JT.XPPerJump + (payload.perfect and JT.XPPerfectBonus or 0)
    awardXP(src, xp, payload.perfect and 'perfect-jump' or 'jump')
end)

-- ----------------------------------------------------------------
-- Course complete
-- ----------------------------------------------------------------
RegisterNetEvent('rex-horsetrainer:server:jumpCourseComplete', function(data)
    local src = source
    data = data or {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not playerInsideAnyCourse(src) then return end

    local jumps     = tonumber(data.jumps)      or 0
    local duration  = tonumber(data.durationMs) or 0
    if jumps < 1 or jumps > 8 or duration < 3000 or duration > JT.MaxRunDuration + 2000 then
        return
    end

    local bonus = JT.XPCourseBonus + (data.timeTrial and JT.XPTimeTrialBonus or 0)
    awardXP(src, bonus, 'course-complete')

    -- leaderboard
    local citizenid = Player.PlayerData.citizenid
    local name = ('%s %s'):format(
        Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    MySQL.query.await([[
        INSERT INTO horse_jump_leaderboard (citizenid, name, best_time, total_jumps)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name        = VALUES(name),
            best_time   = LEAST(best_time, VALUES(best_time)),
            total_jumps = total_jumps + VALUES(total_jumps)
    ]], { citizenid, name, duration, jumps })

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Horse Training',
        description = ('Course bonus: +%d XP'):format(bonus),
        type = 'success',
    })

    jumpsInRun[src]   = nil
    runStartedAt[src] = nil
end)

-- ----------------------------------------------------------------
-- Leaderboard request
-- ----------------------------------------------------------------
RegisterNetEvent('rex-horsetrainer:server:requestLeaderboard', function()
    local src = source
    local rows = MySQL.query.await(
        'SELECT citizenid, name, best_time, total_jumps FROM horse_jump_leaderboard ORDER BY best_time ASC LIMIT 10')
    TriggerClientEvent('rex-horsetrainer:client:showLeaderboard', src, rows or {})
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastJumpAt[src]   = nil
    jumpsInRun[src]   = nil
    runStartedAt[src] = nil
end)
