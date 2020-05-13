# Lua-Solver
![example](https://raw.githubusercontent.com/thewrath/lua-solver/master/assets/bot-mini.png)
## Discord lua interpreter
Lua-solver is a Discord bot capable of interpreting the Lua code you send to it.

## How to use
Simply send a message mentioning the bot with lua code between 6 backquotes :

![example](https://raw.githubusercontent.com/thewrath/lua-solver/master/assets/example.PNG)

## How to install
Firstly, create bot with [Discord developer portal](https://discord.com/developers/applications).

Create Oauth2 link with "Send messages" right, add the bot to your server.

Clone this repository, add ```env.lua``` file with this content : 

```lua
return {
    DISCORD_GATEWAY_URI = "wss://gateway.discord.gg/?v=6&encoding=json",
    DISCORD_API_URL = "https://discordapp.com/api",
    BOT_TOKEN = "your-bot-token",
    BOT_CLIENT_ID = "your-bot-client-id"
}
```
Now you can launch the bot with ```lua main.lua```

## TODO

- Add commands (help, library, ...)
- Return print call (display like in lua interpreter)
- Return error message
- Create special file to store discord message

## Thank to

- [cqueue](http://25thandclement.com/~william/projects/cqueues.html#source)
- [lua http](https://daurnimator.github.io/lua-http/0.3/)
- [json.lua](https://github.com/rxi/json.lua)
- [lua](https://lua.org)
