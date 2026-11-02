-- Server entry point. Order matters: remotes -> data -> world -> match -> simulation tick.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local log = Log.new("Main")

log.info("server starting, build", Config.BUILD)
Net.initServer()

local info = Instance.new("Folder")
info.Name = "MatchInfo"
info:SetAttribute("Build", Config.BUILD)
info.Parent = RS

Log.try("Main", "PlayerData.init", require(script.Parent.Services.PlayerData).init)
Log.try("Main", "World.buildLobby", require(script.Parent.World).buildLobby)
Log.try("Main", "LobbyMap.init", require(script.Parent.LobbyMap).init)
Log.try("Main", "Match.init", require(script.Parent.Match).init, info)

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
