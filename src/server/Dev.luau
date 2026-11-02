-- Studio-only dev menu backend. Does NOTHING outside Studio: the remotes are not created
-- (Net studioOnly) and every handler re-checks IsStudio. Cheat state is in memory only and
-- never written to PlayerData/DataStore (attributes like Rerolls are display-only; saves use
-- the data table).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Traits = require(Shared.Traits)
local Cash = require(Shared.Cash)
local Match = require(script.Parent.Match)
local Towers = require(script.Parent.Towers)

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

-- Sandbox: places the unit directly in the CURRENT match at the player's feet (no inventory
-- yet; DataSchema units would persist). Free, ignores placement rules / caps. Stat inputs <= 0
-- mean "use the level's normal stat". Trait multipliers apply on top.
local function sandbox(plr, unitId, traitId, damage, range, rate, level)
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
	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return "No character"
	end
	level = math.clamp(math.floor(level), 1, UnitStats.maxLevel(u))
	local p = hrp.Position + hrp.CFrame.LookVector * 4
	local pos = Vector3.new(math.round(p.X), Config.MAP_ORIGIN.Y + Config.GROUND_TOP + u.size / 2, math.round(p.Z))
	local t = Towers.place(unitId, pos, plr)
	local st = UnitStats.at(u, level)
	st.damage = damage > 0 and damage or st.damage
	st.range = range > 0 and range or st.range
	st.rate = rate > 0 and rate or st.rate
	t.stats = Traits.apply(st, traitId)
	t.stats.ability = st.ability
	if t.ability then
		t.ability.cfg = t.stats.ability
	end
	t.level, t.spent, t.sandbox = level, 0, true
	t.part:SetAttribute("Level", level)
	t.part:SetAttribute("Spent", 0)
	t.part:SetAttribute("Trait", traitId)
	t.part:SetAttribute("Sandbox", true)
	t.levelLabel.Text = ("Lv %d%s"):format(level, traitId ~= "None" and (" " .. traitId) or "")
	log.info(plr.Name, "sandbox", unitId, traitId, "lv", level, "dmg", t.stats.damage, "rng", t.stats.range, "rate", t.stats.rate)
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
