--[[
    rex-horsetrainer :: Discord Webhook
    -----------------------------------
    Sends an embed every time a horse gains XP, showing:
      - Trainer (player) name
      - Horse name
      - XP source (lead / jump / course)
      - XP delta and progression: "from <old> to <new> / 5000"
]]

RexWebhook = {}

local function escape(s)
    if type(s) ~= 'string' then return tostring(s) end
    return s:gsub('`', "'"):gsub('\n', ' ')
end

function RexWebhook.SendXP(data)
    if not Config.Webhook or not Config.Webhook.Enabled then return end
    local url = Config.Webhook.URL
    if not url or url == '' then return end

    local playerName = escape(data.playerName or 'Unknown')
    local horseName  = escape(data.horseName  or 'Unknown')
    local action     = escape(data.action     or 'xp')
    local amount     = tonumber(data.amount)  or 0
    local oldXP      = tonumber(data.oldXP)   or 0
    local newXP      = tonumber(data.newXP)   or 0
    local citizenid  = escape(data.citizenid  or '-')

    local actionLabel = ({
        lead   = 'Lead Horse (rope)',
        ride   = 'Ride Horse',
        jump   = 'Jump Obstacle',
        course = 'Course Complete',
    })[data.action] or action

    local embed = {{
        title       = 'Horse Training — XP Gained',
        color       = Config.Webhook.Color or 16753920,
        description = ('**Trainer:** %s\n**Horse:** %s\n**Action:** %s'):format(playerName, horseName, actionLabel),
        fields = {
            { name = 'XP Gained',   value = ('+%d XP'):format(amount),           inline = true },
            { name = 'Progress',    value = ('from %d to %d / 5000'):format(oldXP, newXP), inline = true },
            { name = 'CitizenID',   value = citizenid,                            inline = true },
        },
        footer = { text = ('rex-horsetrainer • %s'):format(os.date('%Y-%m-%d %H:%M:%S')) },
    }}

    PerformHttpRequest(url, function(status)
        if status ~= 204 and status ~= 200 and Config.Debug then
            print(('^1[rex-horsetrainer:webhook] HTTP %s^7'):format(tostring(status)))
        end
    end, 'POST', json.encode({
        username   = Config.Webhook.Username or 'Horse Trainer',
        avatar_url = Config.Webhook.Avatar,
        embeds     = embed,
    }), { ['Content-Type'] = 'application/json' })
end
