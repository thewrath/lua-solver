local os = require "os"
local env = require "env"

local discord_ws_messages = {}

discord_ws_messages.identity = {
    op = 2,
    d = {
        token = env.BOT_TOKEN,
        properties = {
            ["$os"] = "linux",
            ["$browser"] = "disco",
            ["$device"] = "disco"
        },
        compress = false,
        large_threshold = 250,
        guild_subscriptions = false,
        presence = {
            game = {
                name = "Coding for you",
                type = 1
            },
            status = "online",
            since = os.time(os.date("!*t")),
            afk = false
        },
        intents = (1 << 0) | (1 << 9) | (1 << 12)
    }
}

discord_ws_messages.heartbeat = function (last_sequence)
    return {
        op = 1,
        d = last_sequence
    }
end

return discord_ws_messages