-- Match flow (one match per server for now):
--   idle --(portal + ChooseMap)--> waiting --(all vote / countdown)--> running --> over --> idle
-- Match info replicates through attributes on ReplicatedStorage.MatchInfo (see ARCHITECTURE.md).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Maps = require(Shared.Maps)
local Modes = require(Shared.Modes)
local Enemies = require(Shared.Enemies)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Waves = require(Shared.Waves)
local Rewards = require(Shared.Rewards)
local World = require(script.Parent.World)
local EnemySim = require(script.Parent.Enemies)
local Combat = require(script.Parent.Combat)
local Towers = require(script.Parent.Towers)
local PlayerData = require(script.Parent.Services.PlayerData)
local Log = require(Shared.Log)
local PlacementRules = require(Shared.PlacementRules)
local log = Log.new("Match")

local Match = {}
local inMatch = {} -- [player] = true
local votes = {}
local state = "idle" -- idle | waiting | running | over
local map, mode
local baseHealth, wave, enemiesLeft, wavesCleared = Config.BASE_HEALTH, 0, 0, 0
local startedAt = 0
local matchToken = 0
local info
local insidePortal = {} -- [player] = true while standing in the portal (edge detect)
local offeredAt = {} -- [player] = os.clock() when we last offered pick/join (valid OFFER_WINDOW)
local OFFER_WINDOW = 120

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function sync()
	info:SetAttribute("MatchState", state)
	info:SetAttribute("MapId", map and map.id or "")
	info:SetAttribute("ModeId", mode and mode.id or "")
	info:SetAttribute("MaxWaves", mode and mode.maxWaves or 0)
	info:SetAttribute("Wave", wave)
	info:SetAttribute("EnemiesLeft", enemiesLeft)
	info:SetAttribute("BaseHP", baseHealth)
	info:SetAttribute("BaseMaxHP", Config.BASE_HEALTH)
	info:SetAttribute("Votes", count(votes))
	info:SetAttribute("InMatch", count(inMatch))
	if World.baseLabel and World.baseLabel.Parent then
		World.baseLabel.Text = "HP " .. math.max(baseHealth, 0) .. "/" .. Config.BASE_HEALTH
	end
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
	if char and char:FindFirstChild("HumanoidRootPart") then
		char:PivotTo(CFrame.new(pos + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))))
	end
end

local runWaves

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
	if inMatch[plr] then
		return "Already in the match"
	end
	if state ~= "waiting" then
		return "No open match to join (" .. state .. ")"
	end
	inMatch[plr] = true
	plr:SetAttribute("Voted", false)
	local c = getCash(plr)
	if c then
		c.Value = Config.START_CASH
	end
	moveTo(plr, Maps.spawnPoint(map))
	Net.fire("MatchState", plr, state)
	log.info(plr.Name, "joined", map.id, mode.id)
	sync()
	return nil
end

local function leaveMatch(plr)
	if not inMatch[plr] then
		return
	end
	inMatch[plr] = nil
	votes[plr] = nil
	plr:SetAttribute("Voted", false)
	Towers.removeOwner(plr)
	moveTo(plr, Config.LOBBY_SPAWN)
	Net.fire("MatchState", plr, "lobby")
	sync()
end

local function resetMatch()
	matchToken += 1
	for plr in pairs(inMatch) do
		moveTo(plr, Config.LOBBY_SPAWN)
		plr:SetAttribute("Voted", false)
		Net.fire("MatchState", plr, "lobby")
	end
	table.clear(inMatch)
	table.clear(votes)
	EnemySim.clear()
	Towers.clear()
	Combat.resetStats()
	World.clearMap()
	map, mode = nil, nil
	baseHealth, wave, enemiesLeft, wavesCleared = Config.BASE_HEALTH, 0, 0, 0
	state = "idle"
	info:SetAttribute("Countdown", 0)
	info:SetAttribute("WaveTotal", 0)
	World.portalLabel.Text = "Step in to play!"
	sync()
end

local function chooseMap(plr, mapId, modeId)
	if state ~= "idle" then
		return "A match is already open"
	end
	if not offeredAt[plr] or os.clock() - offeredAt[plr] > OFFER_WINDOW then
		return "Step into the portal first"
	end
	local m, md = Maps.get(mapId), Modes.get(modeId)
	if not m then
		return "Unknown map " .. mapId
	end
	if not md then
		return "Unknown mode " .. modeId
	end
	local ok, path = Log.try("Match", "buildMap " .. mapId, World.buildMap, m)
	if not ok then
		World.clearMap()
		return "Failed to build map"
	end
	map, mode = m, md
	EnemySim.setPath(path, map.id)
	offeredAt[plr] = nil
	log.info(plr.Name, "opened match", map.id, mode.id)
	state = "waiting"
	World.portalLabel.Text = ("%s (%s) - step in to join!"):format(map.name, mode.name)
	startCountdown()
	sync()
	return joinMatch(plr)
end

local function finish(won)
	state = "over"
	sync()
	local elapsed = os.clock() - startedAt
	for plr in pairs(inMatch) do
		local d = PlayerData.get(plr)
		local clearKey = map.id .. ":" .. mode.id
		local r = Rewards.compute({
			wavesCleared = wavesCleared,
			won = won,
			rewardScale = mode.rewardScale,
			firstClear = d and not d.clears[clearKey],
		})
		local st = Combat.stats[plr] or { kills = 0, damage = 0 }
		PlayerData.grant(plr, {
			gems = r.gems,
			xp = r.xp,
			unitXp = r.unitXp,
			stats = {
				matches = 1,
				wins = won and 1 or 0,
				kills = st.kills,
				damage = math.floor(st.damage),
				wavesCleared = wavesCleared,
			},
			bestWave = wavesCleared,
			clear = won and clearKey or nil,
		})
		Net.fire("Results", plr, {
			won = won,
			waves = wavesCleared,
			time = math.floor(elapsed),
			gems = r.gems,
			xp = r.xp,
			kills = st.kills,
			damage = math.floor(st.damage),
			mapName = map.name,
			modeName = mode.name,
		})
	end
	World.baseLabel.Text = won and "VICTORY" or "GAME OVER"
	local token = matchToken
	task.delay(Config.RESULTS_TIMEOUT, function()
		if token == matchToken and state == "over" then
			resetMatch()
		end
	end)
end

local function alive()
	return baseHealth > 0 and next(inMatch) ~= nil and state == "running"
end

local function runWavesInner()
	state = "running"
	matchToken += 1
	startedAt = os.clock()
	info:SetAttribute("Countdown", 0)
	World.portalLabel.Text = "Match in progress..."
	for plr in pairs(inMatch) do
		Net.fire("MatchState", plr, "running")
	end
	sync()
	while alive() do
		wave += 1
		local w = (map.waves and map.waves[wave]) or Waves.generate(wave, { hpScale = mode.hpScale, maxWaves = mode.maxWaves })
		enemiesLeft = w.total
		info:SetAttribute("WaveTotal", w.total)
		sync()
		Towers.broadcast("onWaveStart", wave)
		for _, g in ipairs(w.groups) do
			local def = Enemies.get(g.enemy)
			for _ = 1, g.count do
				if not alive() then
					break
				end
				if def then
					Log.try("Match", "spawn " .. g.enemy, EnemySim.spawn, def, { hpMult = w.hpMult, speedMult = w.speedMult })
				else
					log.error("wave", wave, "unknown enemy id", g.enemy)
					enemiesLeft = math.max(enemiesLeft - 1, 0)
				end
				task.wait(g.delay)
			end
		end
		repeat
			task.wait(0.25)
		until EnemySim.count() == 0 or not alive()
		if not alive() then
			break
		end
		wavesCleared = wave
		payMatch(w.bonus)
		if mode.maxWaves and wave >= mode.maxWaves then
			break
		end
		task.wait(Config.WAVE_BREAK)
	end
	EnemySim.clear()
	if not next(inMatch) then
		resetMatch()
		return
	end
	finish(baseHealth > 0 and mode.maxWaves ~= nil and wavesCleared >= mode.maxWaves)
end

function runWaves()
	local ok = Log.try("Match", "runWaves", runWavesInner)
	if not ok then
		for plr in pairs(inMatch) do
			Net.fire("Notify", plr, "Match crashed - returning to lobby", "error")
		end
		resetMatch()
	end
end

local function ownedTower(plr, id)
	if (state ~= "waiting" and state ~= "running") or not inMatch[plr] then
		return nil
	end
	local t = Towers.byId[id]
	if t and t.alive and t.owner == plr then
		return t
	end
	return nil
end

function Match.init(infoFolder)
	info = infoFolder
	Combat.onLeak(function(e)
		baseHealth -= e.boss and 5 or 1
		enemiesLeft = math.max(enemiesLeft - 1, 0)
		sync()
	end)
	Combat.onKill(function(e, source)
		payMatch(e.def.reward or Config.KILL_REWARD)
		enemiesLeft = math.max(enemiesLeft - 1, 0)
		info:SetAttribute("EnemiesLeft", enemiesLeft)
		Towers.broadcast("onEnemyKilled", e, source)
	end)
	info:SetAttribute("WaveTotal", 0)
	info:SetAttribute("Countdown", 0)
	sync()

	local function onPlayerAdded(plr)
		if plr:FindFirstChild("leaderstats") then return end
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("IntValue")
		c.Name, c.Value, c.Parent = "Cash", Config.START_CASH, ls
		ls.Parent = plr
		plr.CharacterAdded:Connect(function(char)
			if inMatch[plr] and map then
				char:WaitForChild("HumanoidRootPart")
				task.wait(0.1)
				moveTo(plr, Maps.spawnPoint(map))
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- players who joined before this init ran (common in Studio) would otherwise never get leaderstats
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		insidePortal[plr], offeredAt[plr] = nil, nil
		if inMatch[plr] then
			inMatch[plr], votes[plr] = nil, nil
			Towers.removeOwner(plr)
			sync()
			if state == "waiting" or state == "over" then
				if not next(inMatch) then
					resetMatch()
				elseif state == "waiting" and count(votes) >= count(inMatch) then
					tryStart()
				end
			end
		end
	end)

	-- Offer pick (idle) / join (waiting); used by the portal and the lobby Play button.
	local function offer(plr)
		if state == "idle" then
			offeredAt[plr] = os.clock()
			Net.fire("OpenMapSelect", plr, { kind = "pick" })
		elseif state == "waiting" then
			offeredAt[plr] = os.clock()
			Net.fire("OpenMapSelect", plr, { kind = "join", mapName = map.name, modeName = mode.name, players = count(inMatch) })
		else
			return "Match in progress - wait for it to end"
		end
		return nil
	end
	Net.on("RequestPlay", function(plr)
		if inMatch[plr] then
			return "You're already in a match"
		end
		return offer(plr)
	end)

	-- Portal (edge-triggered on entering the circle). Nobody is teleported here:
	--   idle    -> offer the map/mode picker (ChooseMap confirms)
	--   waiting -> offer a join prompt (JoinMatch confirms)
	--   running/over -> toast "in progress"
	task.spawn(function()
		while true do
			task.wait(0.25)
			Log.try("Match", "portal", function()
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					local inside = false
					if root and not inMatch[plr] then
						local d = root.Position - Config.PORTAL_POS
						inside = Vector2.new(d.X, d.Z).Magnitude <= Config.PORTAL_SIZE / 2 and math.abs(d.Y) < 8
					end
					if inside and not insidePortal[plr] then
						local why = offer(plr)
						if why then
							Net.fire("Notify", plr, why, "info")
						end
					end
					insidePortal[plr] = inside or nil
				end
			end)
		end
	end)

	Net.on("ChooseMap", chooseMap)

	Net.on("JoinMatch", function(plr)
		if not offeredAt[plr] or os.clock() - offeredAt[plr] > OFFER_WINDOW then
			return "Step into the portal first"
		end
		offeredAt[plr] = nil
		return joinMatch(plr)
	end)

	Net.on("Vote", function(plr)
		if not inMatch[plr] then
			return "You're not in a match"
		end
		if state ~= "waiting" then
			return "Voting is closed"
		end
		setVote(plr, not votes[plr])
		return nil
	end)

	Net.on("ReturnToLobby", function(plr)
		if not inMatch[plr] then
			return "You're not in a match"
		end
		if state == "running" then
			return "Can't leave mid-match yet"
		end
		if state == "over" then
			leaveMatch(plr)
			if not next(inMatch) then
				resetMatch()
			end
		elseif state == "waiting" then
			leaveMatch(plr)
			if not next(inMatch) then
				resetMatch()
			end
		end
	end)

	Net.on("PlaceUnit", function(plr, unitId, pos)
		local u = Units.get(unitId)
		local cash = getCash(plr)
		local size = u and u.size or 0
		pos = Vector3.new(math.round(pos.X), Config.MAP_ORIGIN.Y + Config.GROUND_TOP + size / 2, math.round(pos.Z))
		local spot = nil
		if u then
			spot = map and Maps.placementReason(map, pos, size) or (not map and "No map loaded" or nil)
		end
		local why = PlacementRules.reason({
			state = state,
			inMatch = inMatch[plr] == true,
			inLoadout = table.find(PlayerData.loadoutIds(plr), unitId) ~= nil,
			unit = u,
			cash = cash and cash.Value or 0,
			placed = u and Towers.countFor(plr, unitId) or 0,
			maxPlaced = u and UnitStats.maxPlaced(u) or 0,
			spotReason = spot,
			overlaps = u ~= nil and Towers.overlaps(pos, size),
		})
		if why then
			return why .. (" [%s @ %d,%d]"):format(unitId, pos.X, pos.Z)
		end
		cash.Value -= u.cost
		Towers.place(unitId, pos, plr)
		return nil
	end)

	Net.on("UpgradeUnit", function(plr, id)
		local t = ownedTower(plr, id)
		local cash = getCash(plr)
		if not t or not cash then
			return "Unit not found"
		end
		local cost = Towers.upgradeCost(t)
		if not cost then
			return "Already max level"
		end
		if cash.Value < cost then
			return "Not enough money!"
		end
		cash.Value -= cost
		Towers.upgrade(t)
	end)

	Net.on("SellUnit", function(plr, id)
		local t = ownedTower(plr, id)
		local cash = getCash(plr)
		if not t or not cash then
			return "Unit not found"
		end
		cash.Value += Towers.sell(t)
		return nil
	end)

	Net.on("SetTargeting", function(plr, id, m)
		local t = ownedTower(plr, id)
		if not t then
			return "Unit not found"
		end
		if not table.find(Config.TARGET_MODES, m) then
			return "Unknown targeting " .. m
		end
		t.part:SetAttribute("Targeting", m)
		return nil
	end)
end

return Match
