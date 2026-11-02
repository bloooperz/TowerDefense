-- Match flow: portal -> map, START button, waves, game over -> lobby.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = require(script.Parent.World)
local Enemies = require(script.Parent.Enemies)
local Towers = require(script.Parent.Towers)

local Match = {}
local inMatch = {} -- [player] = true
local state = "idle" -- idle | waiting | running
local baseHealth, wave = Config.BASE_HEALTH, 0
local remotes

local function updateLabel(text)
	World.baseLabel.Text = text or ("Wave " .. wave .. " | Base HP: " .. baseHealth)
end

local function getCash(plr)
	local ls = plr:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Cash")
end

local function payMatch(n)
	for plr in pairs(inMatch) do
		local c = getCash(plr)
		if c then
			c.Value += n
		end
	end
end

local function moveTo(plr, pos)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		char:PivotTo(CFrame.new(pos + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))))
	end
end

local function joinMatch(plr)
	if inMatch[plr] or state == "running" then
		return
	end
	inMatch[plr] = true
	if state == "idle" then
		state = "waiting"
	end
	local c = getCash(plr)
	if c then
		c.Value = Config.START_CASH
	end
	moveTo(plr, Config.MAP_SPAWN)
	remotes.MatchState:FireClient(plr, state)
end

local function resetMatch()
	for plr in pairs(inMatch) do
		moveTo(plr, Config.LOBBY_SPAWN)
		remotes.MatchState:FireClient(plr, "lobby")
	end
	table.clear(inMatch)
	Enemies.clear()
	Towers.clear()
	baseHealth, wave = Config.BASE_HEALTH, 0
	state = "idle"
	World.portalLabel.Text = "Step in to play!"
	updateLabel()
end

local function runWaves()
	state = "running"
	World.portalLabel.Text = "Match in progress..."
	for plr in pairs(inMatch) do
		remotes.MatchState:FireClient(plr, "running")
	end
	while baseHealth > 0 and next(inMatch) do
		wave += 1
		updateLabel()
		local info = Config.waveInfo(wave)
		for _ = 1, info.count do
			if baseHealth <= 0 or not next(inMatch) then
				break
			end
			Enemies.spawn(info.hp, info.speed)
			task.wait(info.spawnDelay)
		end
		repeat
			task.wait(0.5)
		until Enemies.count() == 0 or baseHealth <= 0 or not next(inMatch)
		if baseHealth <= 0 or not next(inMatch) then
			break
		end
		payMatch(info.bonus)
		task.wait(Config.WAVE_BREAK)
	end
	if baseHealth <= 0 then
		updateLabel("GAME OVER - survived " .. (wave - 1) .. " waves")
		task.wait(4)
	end
	resetMatch()
end

function Match.init(r)
	remotes = r

	Enemies.onLeak = function()
		baseHealth -= 1
		updateLabel()
	end
	Enemies.onKill = function()
		payMatch(Config.KILL_REWARD)
	end
	updateLabel()

	Players.PlayerAdded:Connect(function(plr)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("IntValue")
		c.Name, c.Value, c.Parent = "Cash", Config.START_CASH, ls
		ls.Parent = plr

		plr.CharacterAdded:Connect(function(char)
			if inMatch[plr] then
				char:WaitForChild("HumanoidRootPart")
				task.wait(0.1)
				moveTo(plr, Config.MAP_SPAWN)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		inMatch[plr] = nil
		if state == "waiting" and not next(inMatch) then
			resetMatch()
		end
	end)

	-- Portal: check players standing in the circle
	task.spawn(function()
		while true do
			task.wait(0.25)
			if state ~= "running" then
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if root and not inMatch[plr] then
						local d = root.Position - Config.PORTAL_POS
						if Vector2.new(d.X, d.Z).Magnitude <= Config.PORTAL_SIZE / 2 and math.abs(d.Y) < 8 then
							joinMatch(plr)
						end
					end
				end
			end
		end
	end)

	remotes.StartGame.OnServerEvent:Connect(function(plr)
		if inMatch[plr] and state == "waiting" then
			task.spawn(runWaves)
		end
	end)

	remotes.PlaceUnit.OnServerEvent:Connect(function(plr, index, pos)
		if not inMatch[plr] or state == "idle" then
			return
		end
		if typeof(index) ~= "number" or typeof(pos) ~= "Vector3" then
			return
		end
		local u = Config.UNITS[index]
		local cash = getCash(plr)
		if not u or not cash or cash.Value < u.cost then
			return
		end
		pos = Vector3.new(math.round(pos.X), Config.MAP_ORIGIN.Y + 0.5 + u.size / 2, math.round(pos.Z))
		if not Config.isValidPlacement(pos, u.size) or Towers.overlaps(pos, u.size) then
			return
		end
		cash.Value -= u.cost
		Towers.place(index, pos)
	end)
end

return Match
