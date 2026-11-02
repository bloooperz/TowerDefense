-- Damage pipeline: every hit goes through Combat.damage so armor, shields, crits,
-- stats attribution and kill hooks are handled in exactly one place.
local Shared = game:GetService("ReplicatedStorage").Shared
local Damage = require(Shared.Damage)
local StatusLogic = require(Shared.StatusLogic)
local Enemies = require(script.Parent.Enemies)
local Log = require(Shared.Log)

local Combat = {}
Combat.stats = {} -- [player] = { damage, kills }
local killListeners, leakListeners = {}, {}

function Combat.onKill(fn)
	table.insert(killListeners, fn)
end
function Combat.onLeak(fn)
	table.insert(leakListeners, fn)
end

local function statsFor(plr)
	if not plr then
		return nil
	end
	local s = Combat.stats[plr]
	if not s then
		s = { damage = 0, kills = 0 }
		Combat.stats[plr] = s
	end
	return s
end
Combat.statsFor = statsFor

function Combat.resetStats()
	table.clear(Combat.stats)
end

-- source: { player?, tower?, mult?, armorPen?, critChance?, critMult?, dot? }
-- Returns damage dealt to shield+hp.
function Combat.damage(e, base, source)
	if not e.alive or base <= 0 then
		return 0
	end
	source = source or {}
	local amount = Damage.compute(base, {
		mult = source.mult,
		armor = e.armor,
		armorPen = source.armorPen,
		critChance = source.dot and 0 or source.critChance,
		critMult = source.critMult,
		roll = math.random(),
	})
	local before = e.hp + e.shield
	e.shield, e.hp = Damage.applyToPools(amount, e.shield, e.hp)
	local dealt = before - math.max(e.hp, 0) - e.shield
	local s = statsFor(source.player)
	if s then
		s.damage += dealt
	end
	if e.hp <= 0 then
		Enemies.remove(e)
		if s then
			s.kills += 1
		end
		for _, fn in ipairs(killListeners) do
			task.spawn(Log.try, "Combat", "onKill listener", fn, e, source)
		end
	else
		Enemies.updateBar(e)
	end
	return dealt
end

-- Server simulation tick: statuses, DoTs, regen, leaks.
function Combat.tick(dt)
	if not Enemies.path then
		return
	end
	local t = Enemies.now()
	for e in pairs(Enemies.list) do
		if StatusLogic.prune(e.status, t) then
			Enemies.checkpoint(e)
		end
		for _, dot in ipairs(StatusLogic.dots(e.status, t)) do
			Combat.damage(e, dot.dps * dt, { player = dot.source, dot = true })
		end
		if e.alive and e.regen > 0 and e.hp < e.maxHp then
			e.hp = math.min(e.maxHp, e.hp + e.regen * dt)
			Enemies.updateBar(e)
		end
		if e.alive and Enemies.distance(e, t) >= Enemies.path.length then
			Enemies.remove(e)
			for _, fn in ipairs(leakListeners) do
				Log.try("Combat", "onLeak listener", fn, e)
			end
		end
	end
end

return Combat
