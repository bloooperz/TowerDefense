-- Server entry point. Order matters: remotes -> data -> world -> match -> simulation tick.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local log = Log.new("Main")

log.info("server starting, build", Config.BUILD)
Net.initServer()
do
	local dup = require(Shared.Diagnostics).duplicates({ game:GetService("ServerScriptService"), RS, game:GetService("StarterPlayer"), game:GetService("ReplicatedFirst"), game:GetService("StarterGui") }, { "Server", "Client", "LobbyUI", "Match", "Remotes", "Shared" })
	for n, list in pairs(dup) do
		log.warn("DUPLICATE '" .. n .. "' in the place (" .. #list .. " copies): " .. table.concat(list, " | "))
	end
end

local info = Instance.new("Folder")
info.Name = "MatchInfo"
info:SetAttribute("Build", Config.BUILD)
info.Parent = RS

Log.try("Main", "PlayerData.init", require(script.Parent.Services.PlayerData).init)
Log.try("Main", "World.buildLobby", require(script.Parent.World).buildLobby)
Log.try("Main", "LobbyMap.init", require(script.Parent.LobbyMap).init)
Log.try("Main", "Match.init", require(script.Parent.Match).init, info)
Log.try("Main", "Dev.init", require(script.Parent.Dev).init) -- no-op outside Studio
table.sort(Net.connected)
log.info("build", Config.BUILD, "remotes connected (" .. #Net.connected .. "):", table.concat(Net.connected, ", "))

-- Fixed-rate simulation: statuses, DoTs, regen, leaks, tower attacks, ability ticks.
local Combat = require(script.Parent.Combat)
local Towers = require(script.Parent.Towers)
local acc = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	acc = math.min(acc + dt, 1) -- don't spiral after a long hitch
	while acc >= Config.TICK_RATE do
		acc -= Config.TICK_RATE
		Log.try("Main", "Combat.tick", Combat.tick, Config.TICK_RATE)
		Log.try("Main", "Towers.tick", Towers.tick, Config.TICK_RATE)
	end
end)
log.info("server ready")
