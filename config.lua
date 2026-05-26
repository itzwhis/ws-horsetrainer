Config = {}

Config.Debug = false

-------------------------
-- XP Settings
-------------------------
Config.MaxXPGain = 1000

-- XP is ONLY for jobs listed in Config.HorseTrainerStables.
-- Riding XP disabled (set to 0). Only "lead" and "jump" award XP now.
Config.TrainerRidingXP = 0
Config.RidingWait      = 5000

-- Leading on foot gives a small, weak XP tick.
Config.TrainerLeadingXP = 25
Config.LeadingWait      = 5000

-------------------------
-- Discord Webhook (XP audit log)
-------------------------
Config.Webhook = {
    Enabled  = true,
    URL      = '', -- <-- paste your Discord webhook URL here
    Username = 'Horse Trainer',
    Avatar   = 'https://i.imgur.com/3GTQhX5.png',
    Color    = 16753920, -- orange
}

-------------------------
-- Horse Trainer Stable Areas
-- Player must have the matching job name and be inside that stable radius.
-------------------------
Config.DefaultStableRadius = 70.0

Config.HorseTrainerStables = {
    valhorsetrainer = {
        label  = 'Valentine Stable',
        coords = vector3(-369.49, 787.57, 116.15),
        radius = 70.0,
    },
    rhohorsetrainer = {
        label  = 'Rhodes Stable',
        coords = vector3(1296.16, -1276.97, 76.92),
        radius = 70.0,
    },
    blkhorsetrainer = {
        label  = 'Blackwater Stable',
        coords = vector3(-784.07, -1275.93, 43.96),
        radius = 70.0,
    },
    strhorsetrainer = {
        label  = 'Strawberry Stable',
        coords = vector3(-1809.66, -355.95, 165.10),
        radius = 70.0,
    },
    stdenhorsetrainer = {
        label  = 'Saint Denis Stable',
        coords = vector3(2725.13, -1185.83, 47.10),
        radius = 70.0,
    },
}

-------------------------------------------------------------
-- Jump Training System (Course over real stable fences)
-------------------------------------------------------------
Config.JumpTraining = {
    Enabled              = true,

    -- Cooldown between two training runs per player (ms)
    Cooldown             = 60 * 1000,

    -- Max duration of a single course before auto-fail (ms)
    MaxRunDuration       = 90 * 1000,

    -- Required min altitude above ground (m) to count as a real jump
    MinJumpAltitude      = 0.6,

    -- Ring detection radius (m). 2D distance for the gate, Z handled separately.
    RingRadius           = 2.8,
    RingHeightTolerance  = 3.5,

    -- Minimum horse speed when crossing a ring (m/s)
    MinCrossingSpeed     = 5.0,

    -- XP layout: 4 jumps = 800 XP exactly (200 each, no bonuses).
    XPPerJump            = 200,
    XPPerfectBonus       = 0,
    XPCourseBonus        = 0,
    XPTimeTrialBonus     = 0,
    TimeTrialTarget      = 35 * 1000,

    -- ox_target interaction radius around the start point
    TargetRadius         = 1.6,

    Marker = {
        type     = 0x94FDAE17,
        scale    = vec3(2.6, 2.6, 1.2),
        rotation = vec3(0.0, 0.0, 0.0),
        color    = { r = 255, g = 140, b = 20, a = 220 },
        nextColor= { r = 80,  g = 220, b = 90, a = 220 },
    },

    Particle = {
        dict   = 'core',
        name   = 'ent_amb_fire_pit',
        scale  = 0.7,
    },

    Sounds = {
        success  = { name = 'Hud_Oob_Reverse', set = 'HUD_OPENING_SOUNDSET' },
        perfect  = { name = 'BANK_BAG_PICKUP', set = 'HUD_SHOP_GENERIC_SOUNDSET' },
        complete = { name = 'Award_Unlock',    set = 'HUD_AWARDS' },
        fail     = { name = 'Cancel',          set = 'HUD_SHOP_GENERIC_SOUNDSET' },
    },
}

-- Per-stable course definitions.
-- Each obstacle = { pos = vector3(...), heading = optional approach heading }
Config.JumpCourses = {
    valhorsetrainer = {
        startPoint = vector3(-382.24, 789.38, 115.91),
        blip = { sprite = -748118608, label = 'Valentine Jump Training' },
        obstacles = {
            { pos = vector3(-386.03, 792.34, 116.45) },
            { pos = vector3(-403.98, 781.84, 116.10) },
            { pos = vector3(-398.60, 765.19, 116.25) },
            { pos = vector3(-391.41, 765.46, 116.55) },
        },
    },

    -- NOTE: startPoint + obstacles below are placeholders near each stable.
    -- Use /jumpdev in-game to print exact coords and paste them here.
    rhohorsetrainer = {
        startPoint = vector3(1296.16, -1276.97, 76.92),
        blip = { sprite = -748118608, label = 'Rhodes Jump Training' },
        obstacles = {
            { pos = vector3(1300.0, -1282.0, 76.9) },
            { pos = vector3(1306.0, -1284.0, 76.9) },
            { pos = vector3(1312.0, -1282.0, 76.9) },
            { pos = vector3(1318.0, -1278.0, 76.9) },
        },
    },

    blkhorsetrainer = {
        startPoint = vector3(-784.07, -1275.93, 43.96),
        blip = { sprite = -748118608, label = 'Blackwater Jump Training' },
        obstacles = {
            { pos = vector3(-780.0, -1281.0, 43.9) },
            { pos = vector3(-774.0, -1283.0, 43.9) },
            { pos = vector3(-768.0, -1281.0, 43.9) },
            { pos = vector3(-762.0, -1277.0, 43.9) },
        },
    },

    strhorsetrainer = {
        startPoint = vector3(-1809.66, -355.95, 165.10),
        blip = { sprite = -748118608, label = 'Strawberry Jump Training' },
        obstacles = {
            { pos = vector3(-1814.0, -361.0, 165.0) },
            { pos = vector3(-1820.0, -363.0, 165.0) },
            { pos = vector3(-1826.0, -361.0, 165.0) },
            { pos = vector3(-1832.0, -357.0, 165.0) },
        },
    },

    stdenhorsetrainer = {
        startPoint = vector3(2725.13, -1185.83, 47.10),
        blip = { sprite = -748118608, label = 'Saint Denis Jump Training' },
        obstacles = {
            { pos = vector3(2729.0, -1191.0, 47.1) },
            { pos = vector3(2735.0, -1193.0, 47.1) },
            { pos = vector3(2741.0, -1191.0, 47.1) },
            { pos = vector3(2747.0, -1187.0, 47.1) },
        },
    },
}
