-- Match flow (one match per server for now):
--   idle --(portal + ChooseMap)--> waiting --(all vote / countdown)--> running --> over --> idle
-- Match info replicates through attributes on ReplicatedStorage.MatchInfo (see ARCHITECTURE.md).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Summon = require(Shared.Summon)
local Maps = require(Shared.Maps)
local Modes = require(Shared.Modes)
local Enemies = require(Shared.Enemies)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Waves = require(Shared.Waves)
local Rewards = require(Shared.Rewards)
local UnitLevel = require(Shared.UnitLevel)
local World = require(script.Parent.World)
local EnemySim = require(script.Parent.Enemies)
local Combat = require(script.Parent.Combat)
local Towers = require(script.Parent.Towers)
local PlayerData = require(script.Parent.Services.PlayerData)
local Log = require(Shared.Log)
local PlacementRules = require(Shared.PlacementRules)
local Cash = require(Shared.Cash)
local log = Log.new("Match")
local netlog = Log.new("Net")

local Match = {}
-- Studio dev hooks (server/Dev.luau). godMode: leaks don't hurt the base. skipToken bumps abort the current wave.
Match.dev = { godMode = false, skipToken = 0 }
local inMatch = {} -- [player] = true
local votes = {}
local restartVotes = {} -- [player] = true; separate from the start vote (see Settings > Restart)
local state = "idle" -- idle | waiting | running | over
local map, mode
local baseHealth, wave, enemiesLeft, wavesCleared = Config.BASE_HEALTH, 0, 0, 0
local startedAt = 0
local matchToken = 0
local info
local insidePortal = {} -- [player] = true while standing in the portal (edge detect)
local offeredAt = {} -- [player] = os.clock() when we last offered pick/join (valid OFFER_WINDOW)
local OFFER_WINDOW = 120

-- Waits `sec` but returns early (true) when a dev skip bumps Match.dev.skipToken past `skipAt`.
local function waitOrSkip(sec, skipAt)
	local t0 = os.clock()
	while os.clock() - t0 < sec do
		if Match.dev.skipToken ~= skipAt then
			return true
		end
		task.wait(math.min(0.05, sec))
	end
	return Match.dev.skipToken ~= skipAt
end

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
	return Cash.of(plr) -- attribute-backed handle; leaderstats.Cash is a match-only mirror
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
local openMatch

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
	local pd = PlayerData.get(plr)
	if not (pd and pd.starterChosen) then
		return "Choose your starter unit first"
	end
	if state ~= "waiting" then
		return "No open match to join (" .. state .. ")"
	end
	inMatch[plr] = true
	plr:SetAttribute("Voted", false)
	getCash(plr).Value = Config.START_CASH
	Cash.setVisible(plr, true)
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
	restartVotes[plr] = nil
	plr:SetAttribute("Voted", false)
	Towers.removeOwner(plr)
	Cash.setVisible(plr, false)
	getCash(plr).Value = 0
	moveTo(plr, Config.LOBBY_SPAWN)
	Net.fire("MatchState", plr, "lobby")
	sync()
end

local function resetMatch()
	matchToken += 1
	for plr in pairs(inMatch) do
		moveTo(plr, Config.LOBBY_SPAWN)
		plr:SetAttribute("Voted", false)
		Cash.setVisible(plr, false)
		getCash(plr).Value = 0
		Net.fire("MatchState", plr, "lobby")
	end
	table.clear(inMatch)
	table.clear(votes)
	table.clear(restartVotes)
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

function openMatch(m, md)
	local ok, path = Log.try("Match", "buildMap " .. m.id, World.buildMap, m)
	if not ok then
		World.clearMap()
		return "Failed to build map"
	end
	map, mode = m, md
	EnemySim.setPath(path, map.id)
	state = "waiting"
	World.portalLabel.Text = ("%s (%s) - step in to join!"):format(map.name, mode.name)
	startCountdown()
	sync()
	return nil
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
	local err = openMatch(m, md)
	if err then
		return err
	end
	offeredAt[plr] = nil
	log.info(plr.Name, "opened match", map.id, mode.id)
	return joinMatch(plr)
end

-- Restart: same map + mode, same players, fresh state (back to "waiting" -> normal start vote/countdown).
local function restartMatch()
	local players, m, md = {}, map, mode
	for plr in pairs(inMatch) do
		table.insert(players, plr)
	end
	log.info("restarting", m.id, md.id, "with", #players, "players")
	resetMatch()
	local err = openMatch(m, md)
	if err then
		for _, plr in ipairs(players) do
			Net.fire("Notify", plr, "Restart failed: " .. err, "error")
		end
		return
	end
	for _, plr in ipairs(players) do
		if plr.Parent then
			local e = joinMatch(plr)
			if e then
				Net.fire("Notify", plr, e, "error")
			else
				Net.fire("Notify", plr, "Match restarted", "info")
			end
		end
	end
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
		local unitXp = UnitLevel.stageXp({ wavesCleared = wavesCleared, won = won, rewardScale = mode.rewardScale })
		local unitReport = PlayerData.grant(plr, {
			gems = r.gems,
			xp = r.xp,
			unitXp = unitXp,
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
			unitXp = unitXp,
			units = unitReport, -- { [uid] = { unitId, gained, levels, level } }
			level = plr:GetAttribute("Level"),
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
	local myToken = matchToken
	local function live()
		return alive() and matchToken == myToken
	end
	startedAt = os.clock()
	info:SetAttribute("Countdown", 0)
	World.portalLabel.Text = "Match in progress..."
	for plr in pairs(inMatch) do
		Net.fire("MatchState", plr, "running")
	end
	sync()
	while live() do
		wave += 1
		local w = (map.waves and map.waves[wave]) or Waves.generate(wave, { hpScale = mode.hpScale, maxWaves = mode.maxWaves })
		enemiesLeft = w.total
		info:SetAttribute("WaveTotal", w.total)
		sync()
		Towers.broadcast("onWaveStart", wave)
		local skipAt = Match.dev.skipToken
		for _, g in ipairs(w.groups) do
			if Match.dev.skipToken ~= skipAt then
				break
			end
			local def = Enemies.get(g.enemy)
			for _ = 1, g.count do
				if not live() or Match.dev.skipToken ~= skipAt then
					break
				end
				if def then
					Log.try("Match", "spawn " .. g.enemy, EnemySim.spawn, def, { hpMult = w.hpMult, speedMult = w.speedMult })
				else
					log.error("wave", wave, "unknown enemy id", g.enemy)
					enemiesLeft = math.max(enemiesLeft - 1, 0)
				end
				waitOrSkip(g.delay, skipAt) -- dev skip interrupts the spawn gap
			end
		end
		repeat
			if Match.dev.skipToken ~= skipAt then
				EnemySim.clear() -- skip landed after spawning finished
			end
			task.wait(Match.dev.skipToken ~= skipAt and 0 or 0.25)
		until EnemySim.count() == 0 or not live()
		if not live() then
			break
		end
		wavesCleared = wave
		payMatch(w.bonus)
		if mode.maxWaves and wave >= mode.maxWaves then
			break
		end
		waitOrSkip(Config.WAVE_BREAK, Match.dev.skipToken) -- dev skip during the break starts the next wave now
	end
	if matchToken ~= myToken then
		return -- restarted/reset while we were running; the new match owns state now
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

-- Dev: abort the current wave (stop spawning, clear enemies); the loop then advances normally.
function Match.devSkipWave()
	if state ~= "running" then
		return "No wave running (" .. state .. ")"
	end
	Match.dev.skipToken += 1
	EnemySim.clear()
	enemiesLeft = 0
	sync()
	return nil
end
function Match.isInMatch(plr)
	return inMatch[plr] == true and (state == "waiting" or state == "running")
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
		if not Match.dev.godMode then
			baseHealth -= e.boss and 5 or 1
		end
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
		-- lobby column: Level (mirrors the Level attribute). Cash is added only in a match.
		local lv = Instance.new("IntValue")
		lv.Name, lv.Value, lv.Parent = "Level", plr:GetAttribute("Level") or 1, ls
		plr:GetAttributeChangedSignal("Level"):Connect(function()
			lv.Value = plr:GetAttribute("Level") or 1
		end)
		plr:SetAttribute("Cash", 0)
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
		local d = PlayerData.get(plr)
		if not (d and d.starterChosen) then
			return "Choose your starter unit first"
		end
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

	-- Settings > Restart. Solo: immediate. Multiplayer: simple majority (> half) of players in the match;
	-- clicking again withdraws your vote. Votes clear on reset/restart and when a voter leaves.
	Net.on("SaveSettings", function(plr, json)
		return PlayerData.saveSettings(plr, json)
	end)

	Net.on("RequestRestart", function(plr)
		if not inMatch[plr] then
			return "Only in a match"
		end
		if not map or not mode then
			return "Nothing to restart"
		end
		restartVotes[plr] = not restartVotes[plr] or nil
		local n, need = count(restartVotes), math.floor(count(inMatch) / 2) + 1
		if n >= need then
			restartMatch()
			return nil
		end
		for p in pairs(inMatch) do
			Net.fire("Notify", p, ("%s %s restart (%d/%d)"):format(plr.Name, restartVotes[plr] and "voted to" or "withdrew", n, need), "info")
		end
		return nil
	end)

	-- Settings > Leave: allowed in any state; leaveMatch removes the player's towers.
	Net.on("LeaveMatch", function(plr)
		if not inMatch[plr] then
			return "Only in a match"
		end
		restartVotes[plr] = nil
		leaveMatch(plr)
		if not next(inMatch) then
			resetMatch()
		end
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
		Towers.place(unitId, pos, plr, nil, PlayerData.unitLevelFor(plr, unitId))
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

	Net.on("UseItem", function(plr, uid, itemId, count)
		local why, u, before = PlayerData.feedUnit(plr, uid, itemId, count)
		if why then
			return why
		end
		Net.fire("Notify", plr, ("%s Lv %d -> %d"):format(u.unitId, before, u.level), "info")
		return nil
	end)

	Net.on("FuseUnits", function(plr, targetUid, csv)
		local feed = {}
		for uid in string.gmatch(csv, "[^,]+") do
			table.insert(feed, uid)
		end
		local why, u, before = PlayerData.fuseUnits(plr, targetUid, feed)
		if why then
			return why
		end
		Net.fire("Notify", plr, ("Fused %d into %s: Lv %d -> %d"):format(#feed, u.unitId, before, u.level), "info")
		return nil
	end)

	local lastSummon = {} -- [userId] = os.clock() of the last successful summon
	Players.PlayerRemoving:Connect(function(p)
		lastSummon[p.UserId] = nil
	end)
	Net.on("Summon", function(plr, tier)
		if not Summon.cooldownReady(lastSummon[plr.UserId], os.clock()) then
			return nil -- inside the 0.5s cooldown: silently ignored (no toast)
		end
		local why, results, back = PlayerData.summon(plr, tier)
		if why then
			return why
		end
		lastSummon[plr.UserId] = os.clock()
		local d = PlayerData.get(plr)
		Net.fire("SummonResult", plr, { results = results, gems = d and d.gems or 0, gold = d and d.gold or 0, pity = d and d.summonPity or 0, back = back })
		return nil
	end)

	Net.on("ClaimStarter", function(plr, unitId)
		netlog.info("ClaimStarter received from", plr.Name, unitId)
		local ok, why = Log.try("Match", "claimStarter", PlayerData.claimStarter, plr, unitId)
		if not ok then
			why = "Server error (ClaimStarter)"
		end
		Net.fire("ClaimStarterResult", plr, why == nil, why) -- always reply, success or reason
		if why then
			netlog.warn("ClaimStarter rejected for", plr.Name, ":", why)
			return why
		end
		netlog.info("ClaimStarter granted", unitId, "to", plr.Name, "-> replied ok")
		Net.fire("Notify", plr, ("Starter chosen: %s (+%d Gems)"):format(unitId, require(Shared.Summon).STARTER_GEMS), "info")
		return nil
	end)

	Net.on("SellOwnedUnit", function(plr, uid)
		local why, u, gold = PlayerData.sellUnit(plr, uid)
		if why then
			return why
		end
		Net.fire("Notify", plr, ("Sold %s for %d Gold"):format(u.unitId, gold), "info")
		return nil
	end)

	Net.on("ClaimMilestone", function(plr, level)
		local why = PlayerData.claimMilestone(plr, level)
		if why then
			return why
		end
		Net.fire("Notify", plr, ("Milestone Lv %d claimed!"):format(level), "info")
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
