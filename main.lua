local env = require "env"
local Discord = require "discord"

function run_code(chunk) 
    local execution = load(chunk) 
    return execution()
end

-- websocket communication with Discord
local discord = Discord:new()

discord:connect(env.DISCORD_GATEWAY_URI)
discord:start()

discord:disconnect()
