-- Studio-only dev menu backend. Does NOTHING outside Studio: the remotes are not created
-- (Net studioOnly) and every handler re-checks IsStudio. Cheat state is in memory only and
-- never written to PlayerData/DataStore (attributes like Rerolls are display-only; saves use
-- the data table). EXCEPTION: the leveling test buttons (DevGrantUnitXp / DevGrantPlayerXp /
-- DevGiveItem / DevGiveUnit / DevGiveGold / DevGiveGems) intentionally write real progression so save/rejoin can be tested.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS.Shared
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Traits = require(Shared.Traits)
local Cash = require(Shared.Cash)
local Match = require(script.Parent.Match)
local Towers = require(script.Parent.Towers)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.Services.PlayerData)
local Items = require(Shared.Items)
local DevGrants = require(Shared.DevGrants)

local log = Log.new("Dev")
local Dev = {}
local INF_CASH, INF_REROLLS = 999999, 9999

local flags = { cash = false, rerolls = false, god = false }
local saved = { cash = {}, rerolls = {} } -- [plr] = pre-cheat value
local stateFolder

local function studio()
	return RunService:IsStudio()
end

local function publish()
	for k, v in pairs(flags) do
		stateFolder:SetAttribute(k, v) -- client menu reads these to show ON/OFF
	end
end

local function holdCash(plr)
	if flags.cash and Match.isInMatch(plr) and Cash.get(plr) < INF_CASH then
		if saved.cash[plr] == nil then
			saved.cash[plr] = Cash.get(plr)
		end
		Cash.of(plr).Value = INF_CASH
	end
end
local function holdRerolls(plr)
	if flags.rerolls and (plr:GetAttribute("Rerolls") or 0) < INF_REROLLS then
		if saved.rerolls[plr] == nil then
			saved.rerolls[plr] = plr:GetAttribute("Rerolls") or 0
		end
		plr:SetAttribute("Rerolls", INF_REROLLS)
	end
end

local function setFlag(name, on)
	if flags[name] == nil then
		return "Unknown cheat: " .. name
	end
	flags[name] = on
	if name == "god" then
		Match.dev.godMode = on
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if name == "cash" then
			if on then holdCash(plr) elseif saved.cash[plr] ~= nil then
				if Match.isInMatch(plr) then Cash.of(plr).Value = saved.cash[plr] end
				saved.cash[plr] = nil
			end
		elseif name == "rerolls" then
			if on then holdRerolls(plr) elseif saved.rerolls[plr] ~= nil then
				plr:SetAttribute("Rerolls", saved.rerolls[plr])
				saved.rerolls[plr] = nil
			end
		end
	end
	publish()
	log.info("cheat", name, on and "ON" or "OFF")
	return nil
end

-- Sandbox: the client picks a spot with the normal placement preview (cost/caps skipped) and
-- sends it; the server snaps it to the ground with a raycast and places the unit in the
-- CURRENT match (no in-match inventory exists; DataSchema units would persist). Custom stats are
-- stored as tower.overrides and resolved by Towers.resolveStats (survive ticks and upgrades).
-- Stat inputs <= 0 mean "use the level's normal stat".
local function groundAt(pos, size)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { World.runtime }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 50, pos.Z), Vector3.new(0, -200, 0), params)
	return hit and Vector3.new(math.round(pos.X), hit.Position.Y + size / 2, math.round(pos.Z))
end

local function sandbox(plr, unitId, traitId, damage, range, rate, level, pos)
	local u = Units.get(unitId)
	if not u then
		return "Unknown unit: " .. unitId
	end
	if not Traits.byId[traitId] then
		return "Unknown trait: " .. traitId
	end
	if not Match.isInMatch(plr) then
		return "Join a match first (sandbox places units in the match)"
	end
	if damage < 0 or range < 0 or rate < 0 then
		return "Stats must be >= 0 (0 = default)"
	end
	local at = groundAt(pos, u.size)
	if not at then
		return ("Sandbox: no ground under %d,%d"):format(pos.X, pos.Z)
	end
	level = math.clamp(math.floor(level), 1, UnitStats.maxLevel(u))
	local t = Towers.place(unitId, at, plr, {
		level = level,
		overrides = { damage = damage, range = range, rate = rate, trait = traitId },
	})
	t.spent, t.sandbox = 0, true
	t.part:SetAttribute("Spent", 0)
	t.part:SetAttribute("Sandbox", true)
	t.levelLabel.Text = ("Lv %d%s"):format(level, traitId ~= "None" and (" " .. traitId) or "")
	log.info(plr.Name, "sandbox", unitId, traitId, "lv", level, "at", tostring(at), "dmg", t.stats.damage, "rng", t.stats.range, "rate", t.stats.rate)
	return nil
end

local function resetAll()
	for name in pairs(flags) do
		setFlag(name, false)
	end
	local n = 0
	for i = #Towers.placed, 1, -1 do
		local t = Towers.placed[i]
		if t.sandbox and t.alive then
			Towers.sell(t)
			n += 1
		end
	end
	log.info("reset all: cheats off, removed", n, "sandbox units")
	return nil
end

local function guard(fn)
	return function(plr, ...)
		if not studio() then
			return "Dev menu is Studio-only"
		end
		return fn(plr, ...)
	end
end

function Dev.init()
	if not studio() then
		return
	end
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "DevState"
	stateFolder.Parent = RS
	publish()
	Net.on("DevSandbox", guard(sandbox))
	Net.on("DevToggle", guard(function(_, name, on)
		return setFlag(name, on)
	end))
	Net.on("DevSkipWave", guard(function()
		return Match.devSkipWave()
	end))
	Net.on("DevReset", guard(resetAll))
	Net.on("DevGrantUnitXp", guard(function(plr, xp)
		if xp <= 0 or xp > 1e7 then
			return "XP must be 1..10,000,000"
		end
		PlayerData.devGrantUnitXp(plr, math.floor(xp))
		Net.fire("Notify", plr, ("+%d XP to equipped units"):format(xp), "info")
	end))
	Net.on("DevGrantPlayerXp", guard(function(plr, xp)
		if xp <= 0 or xp > 1e7 then
			return "XP must be 1..10,000,000"
		end
		PlayerData.devGrantPlayerXp(plr, math.floor(xp))
		Net.fire("Notify", plr, ("+%d player XP"):format(xp), "info")
	end))
	Net.on("DevGiveItem", guard(function(plr, itemId, n)
		if not Items.get(itemId) then
			return "Unknown item " .. itemId
		end
		if n < 1 or n > 999 then
			return "Count must be 1..999"
		end
		return PlayerData.devGiveItem(plr, itemId, math.floor(n))
	end))
	Net.on("DevGiveGold", guard(function(plr, n)
		if n < 1 or n > 1e7 then
			return "Gold must be 1..10,000,000"
		end
		Net.fire("Notify", plr, ("+%d Gold"):format(n), "info")
		return PlayerData.devGiveGold(plr, math.floor(n))
	end))
	Net.on("DevGiveGems", guard(function(plr)
		-- real grant path (same as stage rewards): PlayerData.grant { gems } -> save + Gems attribute
		local why = DevGrants.giveGems(studio(), PlayerData.get(plr) ~= nil, function(g)
			PlayerData.grant(plr, g)
		end)
		if why then
			log.warn(plr.Name, "DevGiveGems refused:", why)
			return why
		end
		log.info(plr.Name, "dev +" .. DevGrants.GEMS, "gems")
		Net.fire("Notify", plr, ("+%d Gems"):format(DevGrants.GEMS), "info")
		return nil
	end))
	Net.on("DevGiveUnit", guard(function(plr, unitId)
		if not Units.get(unitId) then
			return "Unknown unit " .. unitId
		end
		return PlayerData.devGiveUnit(plr, unitId)
	end))
	local function watch(plr)
		plr:GetAttributeChangedSignal("Cash"):Connect(function()
			holdCash(plr)
		end)
		plr:GetAttributeChangedSignal("Rerolls"):Connect(function()
			holdRerolls(plr)
		end)
		holdRerolls(plr)
	end
	Players.PlayerAdded:Connect(watch)
	for _, plr in ipairs(Players:GetPlayers()) do
		watch(plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		saved.cash[plr], saved.rerolls[plr] = nil, nil
	end)
	log.info("Studio dev menu backend ready")
end

return Dev
