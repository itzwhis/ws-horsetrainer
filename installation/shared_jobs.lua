-- Add these jobs to your rsg-core shared/jobs.lua (RSGShared.Jobs = { ... })
-- Each job name MUST match a key in Config.HorseTrainerStables in config.lua.

valhorsetrainer = {
    label = 'Valentine Horse Trainer',
    type = 'horsetrainer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Recruit',        payment = 5  },
        ['1'] = { name = 'Horse Trainer',  payment = 10 },
        ['2'] = { name = 'Master Trainer', isboss = true, payment = 15 },
    },
},

rhohorsetrainer = {
    label = 'Rhodes Horse Trainer',
    type = 'horsetrainer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Recruit',        payment = 5  },
        ['1'] = { name = 'Horse Trainer',  payment = 10 },
        ['2'] = { name = 'Master Trainer', isboss = true, payment = 15 },
    },
},

blkhorsetrainer = {
    label = 'Blackwater Horse Trainer',
    type = 'horsetrainer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Recruit',        payment = 5  },
        ['1'] = { name = 'Horse Trainer',  payment = 10 },
        ['2'] = { name = 'Master Trainer', isboss = true, payment = 15 },
    },
},

strhorsetrainer = {
    label = 'Strawberry Horse Trainer',
    type = 'horsetrainer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Recruit',        payment = 5  },
        ['1'] = { name = 'Horse Trainer',  payment = 10 },
        ['2'] = { name = 'Master Trainer', isboss = true, payment = 15 },
    },
},

stdenhorsetrainer = {
    label = 'Saint Denis Horse Trainer',
    type = 'horsetrainer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Recruit',        payment = 5  },
        ['1'] = { name = 'Horse Trainer',  payment = 10 },
        ['2'] = { name = 'Master Trainer', isboss = true, payment = 15 },
    },
},
