local os = require "os"
local cqueues = require "cqueues"
local websocket = require "http.websocket"
local http_request = require "http.request"

local json = require "json"
local fifo = require "cqueue_fifo"

local env = require "env"
local discord_ws_messages = require "discord_ws_messages"

local Discord = {
    cq = cqueues.new(),             -- cqueue queue for concurrency 
    connected = false,              -- is connected to discord Gateway ? 
    ws = nil,                       -- websocket instance 
    ws_sending_queue = fifo:new(),  -- message to send queue 
    heartbeat = { 
        interval = -1,
        last_sequence = nil,
        clock = os.time()           -- clock instance for heartbeat computation
    },
    ws_events_mapping = {           -- websocket events function mapping
        [10] = function(self, payload) self:on_connect(payload) end,
        [0] = function(self, payload) self:on_guild_event(payload) end
    },
    guild_events_mapping = {        -- guild related events function mapping
        ["READY"] = function(self, payload) self:on_guild_ready(payload) end,
        ["GUILD_CREATE"] = function(self, payload) self:on_guild_create(payload) end,
        ["MESSAGE_CREATE"] = function(self, payload) self:on_guild_message_create(payload) end
    },
    commands_mapping = {            -- commands mapping
        ["example"] = function(self, payload) self:on_example_command(payload) end
    }
}

-- send discord message on specified channel (using HTTP POST)
function Discord:send_message(channel_id, message)
    local uri = env.DISCORD_API_URL.."/channels/"..channel_id.."/messages"
    local req = http_request.new_from_uri(uri)
    req.headers:upsert(":method", "POST")
    req.headers:upsert("authorization", "Bot "..env.BOT_TOKEN)
    req.headers:upsert("content-type", "application/json")
    req:set_body(
        json.encode{
            content = message,
            tts = false
        }
    )

    local headers, stream = req:go()
    print(assert(stream:get_body_as_string()))
end

-- send message to discord websocket gateway
function Discord:flush_ws_message_queue()
    repeat
		local msg = self.ws_sending_queue:get()
        if msg then
            msg = json.encode(msg)
            print(msg)
            self.ws:send(msg, "text")
		end
	until not msg
end

-- connect to discord gateway
function Discord:connect(gateway_url)
    self.ws = websocket.new_from_uri(gateway_url)
    self.ws:connect()
    self.connected = true
end

-- start websocket polling in a loop
function Discord:start()
    if not self.connected then error("Not connected to Discord gateway") end
    
    -- websocket reception 
    self.cq:wrap(function()
        while 1 do
            local payload, opcode = self.ws:receive()
            if payload ~= nil then
                -- for debug purpose
                self:process(json.decode(payload))
            end
            cqueues.sleep(1)
        end
    end)
    
    -- websocket send
    self.cq:wrap(function()
        while 1 do
            cqueues.sleep(1)
            self:flush_ws_message_queue()
        end
    end)

    -- heartbeat generator
    self.cq:wrap(function()
        while 1 do    
            cqueues.sleep(1)
            self:send_heartbeat()
        end
    end)

    -- process all job in cqueue 
    while not self.cq:empty() do
        local ok, err = self.cq:step()
        if not ok then
            error("cqueue: " .. err)
        end
    end
end

function Discord:send_heartbeat()
    -- if heartbeat unknow
    if self.heartbeat.interval == -1 then return false end
    local now = os.time()
    if (now - self.heartbeat.clock >= self.heartbeat.interval/1000) then
        self.heartbeat.clock = now
        self.ws_sending_queue:put(discord_ws_messages.heartbeat(self.heartbeat.last_sequence))
    end
end

-- process a Discord ws payload
function Discord:process(payload)
    -- set heartbeat last sequence number
    self.heartbeat.last_sequence = payload.s or self.heartbeat.last_sequence 
    _ = self.ws_events_mapping[payload.op] and self.ws_events_mapping[payload.op](self, payload)
end

function Discord:disconnect()
    self.ws:close()
    self.connected = false
end

function Discord.get_lua_code(content)
    -- use regex to match ```lua code here```
    return string.match(content, "```lua(.-)```")
end

function Discord.run_code(code)
    -- TODO : Sandbox load function
    return pcall(load(code))
end

-- WS EVENTS
-- on connect event op = 10
function Discord:on_connect(payload)
    self.heartbeat.interval = payload.d.heartbeat_interval or error("Not a connection payload")

    -- send identity message op = 2
    self.ws_sending_queue:put(discord_ws_messages.identity)
end

-- on guild event dispatched op = 0
function Discord:on_guild_event(payload)
    if payload.t == nil then return false end
    _ = self.guild_events_mapping[payload.t] and self.guild_events_mapping[payload.t](self, payload)
end

-- GUILD EVENTS
function Discord:on_guild_ready(payload)
    print("Ready event")
end

function Discord:on_guild_create(payload)
    print("Guild create event")
end

function Discord:on_guild_message_create(payload)
    print(json.encode(payload.d))
    -- check if the message is for the bot
    if #payload.d.mentions > 0 and payload.d.mentions[1].bot == true and payload.d.mentions[1].id == env.BOT_CLIENT_ID then
        -- check if the message is a command
        local command_words = {}
        for word in payload.d.content:gmatch("%w+") do table.insert(command_words, word) end
        if self.commands_mapping[command_words[2]] ~= nil then
            self.commands_mapping[command_words[2]](self, payload)
        else
            local code_to_compute = self.get_lua_code(payload.d.content) 
            if code_to_compute ~= nil then
                local ok, proc = self.run_code(code_to_compute)
                if ok and proc ~= nil and proc ~= "" then
                    self:send_message(payload.d.channel_id,"<@!"..payload.d.author.id.."> here is your result : ```shell\n" .. proc.."```")
                else
                    self:send_message(payload.d.channel_id, "<@!"..payload.d.author.id.."> Mmmmh, you have error in your code, normal your not a robot !")
                end
            else
                self:send_message(payload.d.channel_id, "<@!"..payload.d.author.id.."> Bip boops, I can't understand your request, please send valid Lua code.")
            end
        end
    end
end

-- COMMAND EVENTS
function Discord:on_example_command(payload)
    self:send_message(payload.d.channel_id, 
"<@!"..payload.d.author.id..">"..[[
 Here it's an example on how to tell me to compute Lua Code :
<@!709388123519451226> ```lua
return "Hello World !"```
the result : ```shell
    Hello World !
```
]]
    )
end

function Discord:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return Discord