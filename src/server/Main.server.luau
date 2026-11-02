-- Server entry point. Order matters: remotes -> data -> world -> match -> simulation tick.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

Net.initServer()

local info = Instance.new("Folder")
info.Name = "MatchInfo"
info.Parent = RS

require(script.Parent.Services.PlayerData).init()
require(script.Parent.World).buildLobby()
require(script.Parent.Match).init(info)

-- Fixed-rate simulation: statuses, DoTs, regen, leaks, tower attacks, ability ticks.
local Combat = require(script.Parent.Combat)
local Towers = require(script.Parent.Towers)
local acc = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	acc += dt
	while acc >= Config.TICK_RATE do
		acc -= Config.TICK_RATE
		Combat.tick(Config.TICK_RATE)
		Towers.tick(Config.TICK_RATE)
	end
end)
