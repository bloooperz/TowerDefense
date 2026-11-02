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
	{ name = "Basic", cost = 50, size = 3, range = 18, damage = 20, rate = 0.5 },
	{ name = "Sniper", cost = 120, size = 3, range = 45, damage = 80, rate = 2.0 },
	{ name = "Rapid", cost = 90, size = 2, range = 14, damage = 6, rate = 0.12 },
	-- Unique unit: 1 per player. `ability` = module name in src/server/Abilities.
	{
		name = "Mogumo",
		cost = 150,
		size = 3,
		range = 22,
		damage = 15,
		rate = 0.8,
		unique = true,
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
	},
}

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

-- Placement rule, shared so client preview and server check agree.
function Config.isValidPlacement(pos: Vector3, size: number): boolean
	local rel = pos - Config.MAP_ORIGIN
	return math.abs(rel.Z) >= Config.TRACK_WIDTH / 2 + size / 2
		and math.abs(rel.X) <= 100
		and math.abs(rel.Z) <= 60
end

return Config
