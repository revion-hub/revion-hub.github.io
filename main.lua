setclipboard("discord.gg/S68ANu2MFe")

local WindUI = loadstring(game:HttpGet(
	"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()
local placeId = game.PlaceId

local success, message = pcall(function()
  loadstring(game:HttpGet('https://raw.githubusercontent.com/revion-hub/revion-hub.github.io/refs/heads/main/'..placeId..'/main.lua'))()
end)

if not success then
  WindUI:Notify({
	  Title = "revion.lol/discord",
	  Content = "Join our Discord server to see which games Revion Hub supports.",
	  Duration = 20,
  })

  warn('Revion Hub error:', message)
end
