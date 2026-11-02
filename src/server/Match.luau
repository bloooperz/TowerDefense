-- Match flow: portal -> map, vote start / countdown, waves, game over -> lobby.
-- Global match info is replicated through attributes on ReplicatedStorage.MatchInfo:
--   MatchState, Wave, WaveTotal, EnemiesLeft, BaseHP, BaseMaxHP, Countdown, Votes, InMatch
-- Each player's own vote is the "Voted" attribute on their Player.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = require(script.Parent.World)
local Enemies = require(script.Parent.Enemies)
local Towers = require(script.Parent.Towers)

local Match = {}
local inMatch = {} -- [player] = true
local votes = {} -- [player] = true
local state = "idle" -- idle | waiting | running
local baseHealth, wave, enemiesLeft = Config.BASE_HEALTH, 0, 0
local matchToken = 0 -- bumps on reset so old countdowns stop
local remotes, info

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function sync()
	info:SetAttribute("MatchState", state)
	info:SetAttribute("Wave", wave)
	info:SetAttribute("EnemiesLeft", enemiesLeft)
	info:SetAttribute("BaseHP", baseHealth)
	info:SetAttribute("BaseMaxHP", Config.BASE_HEALTH)
	info:SetAttribute("Votes", count(votes))
	info:SetAttribute("InMatch", count(inMatch))
	World.baseLabel.Text = "HP " .. math.max(baseHealth, 0) .. "/" .. Config.BASE_HEALTH
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

local runWaves -- forward declared

local function tryStart()
	if state == "waiting" and next(inMatch) then
		task.spawn(runWaves)
	end
end

local function startCountdown()
	matchToken += 1
	local token = matchToken
	task.spawn(function()
		for t = Config.VOTE_COUNTDOWN, 0, -1 do
			if token ~= matchToken or state ~= "waiting" then
				return
			end
			info:SetAttribute("Countdown", t)
			if t == 0 then
				tryStart()
				return
			end
			task.wait(1)
		end
	end)
end

local function setVote(plr, v)
	votes[plr] = v or nil
	plr:SetAttribute("Voted", v)
	sync()
	if state == "waiting" and next(inMatch) and count(votes) >= count(inMatch) then
		tryStart()
	end
end

local function joinMatch(plr)
	if inMatch[plr] or state == "running" then
		return
	end
	inMatch[plr] = true
	if state == "idle" then
		state = "waiting"
		startCountdown()
	end
	plr:SetAttribute("Voted", false)
	local c = getCash(plr)
	if c then
		c.Value = Config.START_CASH
	end
	moveTo(plr, Config.MAP_SPAWN)
	remotes.MatchState:FireClient(plr, state)
	sync()
end

local function resetMatch()
	matchToken += 1
	for plr in pairs(inMatch) do
		moveTo(plr, Config.LOBBY_SPAWN)
		plr:SetAttribute("Voted", false)
		remotes.MatchState:FireClient(plr, "lobby")
	end
	table.clear(inMatch)
	table.clear(votes)
	Enemies.clear()
	Towers.clear()
	baseHealth, wave, enemiesLeft = Config.BASE_HEALTH, 0, 0
	state = "idle"
	info:SetAttribute("Countdown", 0)
	info:SetAttribute("WaveTotal", 0)
	World.portalLabel.Text = "Step in to play!"
	sync()
end

function runWaves()
	state = "running"
	matchToken += 1 -- stop countdown
	info:SetAttribute("Countdown", 0)
	World.portalLabel.Text = "Match in progress..."
	for plr in pairs(inMatch) do
		remotes.MatchState:FireClient(plr, "running")
	end
	sync()
	while baseHealth > 0 and next(inMatch) do
		wave += 1
		local w = Config.waveInfo(wave)
		enemiesLeft = w.count
		info:SetAttribute("WaveTotal", w.count)
		sync()
		for _ = 1, w.count do
			if baseHealth <= 0 or not next(inMatch) then
				break
			end
			Enemies.spawn(w.hp, w.speed)
			task.wait(w.spawnDelay)
		end
		repeat
			task.wait(0.5)
		until Enemies.count() == 0 or baseHealth <= 0 or not next(inMatch)
		if baseHealth <= 0 or not next(inMatch) then
			break
		end
		payMatch(w.bonus)
		task.wait(Config.WAVE_BREAK)
	end
	if baseHealth <= 0 then
		World.baseLabel.Text = "GAME OVER"
		info:SetAttribute("MatchState", "over")
		task.wait(4)
	end
	resetMatch()
end

function Match.init(r, infoFolder)
	remotes, info = r, infoFolder

	Enemies.onLeak = function()
		baseHealth -= 1
		enemiesLeft = math.max(enemiesLeft - 1, 0)
		sync()
	end
	Enemies.onKill = function()
		payMatch(Config.KILL_REWARD)
		enemiesLeft = math.max(enemiesLeft - 1, 0)
		info:SetAttribute("EnemiesLeft", enemiesLeft)
	end
	info:SetAttribute("WaveTotal", 0)
	info:SetAttribute("Countdown", 0)
	sync()

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
		votes[plr] = nil
		sync()
		if state == "waiting" then
			if not next(inMatch) then
				resetMatch()
			elseif count(votes) >= count(inMatch) then
				tryStart()
			end
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

	-- StartGame now toggles this player's vote.
	remotes.StartGame.OnServerEvent:Connect(function(plr)
		if inMatch[plr] and state == "waiting" then
			setVote(plr, not votes[plr])
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
		if Towers.countFor(plr, index) >= Config.maxPlaced(u) then
			return
		end
		cash.Value -= u.cost
		Towers.place(index, pos, plr)
	end)

	local function ownedTower(plr, id)
		if state == "idle" or not inMatch[plr] or typeof(id) ~= "number" then
			return nil
		end
		local t = Towers.byId[id]
		if t and t.alive and t.owner == plr then
			return t
		end
		return nil
	end

	remotes.UpgradeUnit.OnServerEvent:Connect(function(plr, id)
		local t = ownedTower(plr, id)
		local cash = getCash(plr)
		if not t or not cash then
			return
		end
		local cost = Towers.upgradeCost(t)
		if not cost or cash.Value < cost then
			return
		end
		cash.Value -= cost
		Towers.upgrade(t)
	end)

	remotes.SellUnit.OnServerEvent:Connect(function(plr, id)
		local t = ownedTower(plr, id)
		local cash = getCash(plr)
		if not t or not cash then
			return
		end
		cash.Value += Towers.sell(t)
	end)

	remotes.SetTargeting.OnServerEvent:Connect(function(plr, id, mode)
		local t = ownedTower(plr, id)
		if t and typeof(mode) == "string" and table.find(Config.TARGET_MODES, mode) then
			t.part:SetAttribute("Targeting", mode)
		end
	end)
end

return Match
