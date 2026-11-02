-- Shared settings: read by both server and client.
local Config = {}

-- MAP LAYOUT (map is far away from the lobby)
Config.MAP_ORIGIN = Vector3.new(1000, 0, 0)
Config.START = Config.MAP_ORIGIN + Vector3.new(-80, 2.6, 0)
Config.FINISH = Config.MAP_ORIGIN + Vector3.new(80, 2.6, 0)
Config.LENGTH = (Config.FINISH - Config.START).Magnitude
Config.DIR = (Config.FINISH - Config.START).Unit
Config.TRACK_WIDTH = 8
Config.MAP_SPAWN = Config.MAP_ORIGIN + Vector3.new(-60, 4, 25)

-- LOBBY
Config.LOBBY_SPAWN = Vector3.new(0, 3, 0)
Config.PORTAL_POS = Vector3.new(0, 0.6, -30)
Config.PORTAL_SIZE = 14

-- ECONOMY
Config.START_CASH = 200
Config.KILL_REWARD = 10
Config.BASE_HEALTH = 20

-- UNITS (hotbar is built from this list, in order; keys 1-6)
Config.UNITS = {
	-- `upgrades`: levels 2..N. Each sets ABSOLUTE stats (omitted = unchanged).
	-- `ability` inside an upgrade overrides keys of abilityConfig.
	{
		name = "Basic", maxPlaced = 4, cost = 50, size = 3, range = 18, damage = 20, rate = 0.5,
		upgrades = {
			{ cost = 60, damage = 28, range = 20 },
			{ cost = 100, damage = 40, range = 22, rate = 0.45 },
			{ cost = 175, damage = 60, range = 25, rate = 0.4 },
		},
	},
	{
		name = "Sniper", maxPlaced = 3, cost = 120, size = 3, range = 45, damage = 80, rate = 2.0,
		upgrades = {
			{ cost = 130, damage = 120 },
			{ cost = 220, damage = 180, range = 55, rate = 1.8 },
			{ cost = 350, damage = 280, range = 65, rate = 1.6 },
		},
	},
	{
		name = "Rapid", maxPlaced = 4, cost = 90, size = 2, range = 14, damage = 6, rate = 0.12,
		upgrades = {
			{ cost = 100, damage = 8 },
			{ cost = 170, damage = 11, range = 16, rate = 0.1 },
			{ cost = 280, damage = 15, range = 18, rate = 0.08 },
		},
	},
	-- Unique unit: 1 per player. `ability` = module name in src/server/Abilities.
	{
		name = "Mogumo",
		cost = 150,
		size = 3,
		range = 22,
		damage = 15,
		rate = 0.8,
		unique = true, -- shows a star; the cap below is what limits it
		maxPlaced = 1,
		topper = Color3.new(0, 0, 0), -- thin slab on top marks a unique unit
		ability = "Mogumo",
		abilityConfig = {
			every = 4, -- every Nth attack spawns a dog
			maxDogs = 2, -- per Mogumo
			dogDamage = 40,
			dogSpeed = 20, -- studs/s, runs backward toward enemy spawn
			dogLifetime = 3, -- seconds
			dogRadius = 3, -- hit distance
		},
		upgrades = {
			{ cost = 150, damage = 22, ability = { dogDamage = 60 } },
			{ cost = 250, damage = 30, range = 25, ability = { dogDamage = 90, maxDogs = 3 } },
			{ cost = 400, damage = 42, range = 28, rate = 0.65, ability = { dogDamage = 140, maxDogs = 4, every = 3 } },
		},
	},
}

Config.VOTE_COUNTDOWN = 30 -- seconds after first player enters the map
Config.TARGET_MODES = { "First", "Last", "Strongest", "Weakest", "Closest" }

Config.SELL_REFUND = 0.5 -- fraction of total spent

function Config.maxLevel(u)
	return 1 + (u.upgrades and #u.upgrades or 0)
end

-- Stats for a unit at a level: { damage, range, rate, ability = {...} }
function Config.statsAt(u, level: number)
	local st = { damage = u.damage, range = u.range, rate = u.rate, ability = table.clone(u.abilityConfig or {}) }
	for i = 1, level - 1 do
		local up = u.upgrades and u.upgrades[i]
		if not up then
			break
		end
		for _, k in ipairs({ "damage", "range", "rate" }) do
			if up[k] then
				st[k] = up[k]
			end
		end
		for k, v in pairs(up.ability or {}) do
			st.ability[k] = v
		end
	end
	return st
end

-- WAVES
function Config.waveInfo(wave: number)
	return {
		count = 4 + wave * 2,
		hp = 50 + wave * 20,
		speed = 8 + wave * 0.5,
		spawnDelay = 1,
		bonus = 25 + wave * 5,
	}
end
Config.WAVE_BREAK = 4

-- Max copies of a unit one player can have placed (default 99).
function Config.maxPlaced(u)
	return u.maxPlaced or 99
end

-- Placement rule, shared so client preview and server check agree.
function Config.isValidPlacement(pos: Vector3, size: number): boolean
	local rel = pos - Config.MAP_ORIGIN
	return math.abs(rel.Z) >= Config.TRACK_WIDTH / 2 + size / 2
		and math.abs(rel.X) <= 100
		and math.abs(rel.Z) <= 60
end

return Config
