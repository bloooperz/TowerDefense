-- Global constants. Content (units, enemies, maps, modes) lives in its own registries.
local Config = {}

-- WORLD
Config.MAP_ORIGIN = Vector3.new(1000, 0, 0)
Config.TRACK_TOP = 1.1 -- Y of the track surface (relative to map origin)
Config.GROUND_TOP = 0.5 -- Y of the ground surface (relative to map origin)
Config.FLY_HEIGHT = 6 -- extra height for flying enemies
Config.LOBBY_SPAWN = Vector3.new(0, 3, 15) -- on the plaza, facing the portal (LobbyMap puts the SpawnLocation here)
Config.PORTAL_POS = Vector3.new(0, 0.6, -30)
Config.PORTAL_SIZE = 14

-- MATCH ECONOMY (in-match gold, shown as Cash)
Config.START_CASH = 200
Config.KILL_REWARD = 10 -- fallback when an enemy has no `reward`
Config.BASE_HEALTH = 20
Config.SELL_REFUND = 0.5
Config.WAVE_BREAK = 4
Config.VOTE_COUNTDOWN = 30
Config.RESULTS_TIMEOUT = 25 -- seconds before the map auto-resets after a match ends
Config.TARGET_MODES = { "First", "Last", "Strongest", "Weakest", "Closest" }

-- LOADOUT / PROGRESSION
Config.LOADOUT_SIZE = 6
Config.STARTER_LOADOUT = { "Basic" } -- loading placeholder cards + safety refill only (new accounts pick via shared/Summon.STARTERS)

-- SERVER
Config.TICK_RATE = 0.1 -- seconds between server simulation ticks

-- Bump on notable pushes; server + client print it so stale Studio scripts are obvious.
Config.BUILD = "foundation-2"

-- Display metadata (lobby/hotbar cards). Combat ignores these for now.
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(170, 170, 180),
	Rare = Color3.fromRGB(60, 140, 255),
	Epic = Color3.fromRGB(170, 70, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 60, 120),
}
Config.DAMAGE_TYPE_COLORS = { Physical = Color3.fromRGB(230, 120, 50), Magical = Color3.fromRGB(150, 90, 255) }
Config.ELEMENT_COLORS = {
	Fire = Color3.fromRGB(255, 90, 40), Ice = Color3.fromRGB(140, 220, 255), Lightning = Color3.fromRGB(255, 230, 60),
	Shadow = Color3.fromRGB(150, 70, 200), Water = Color3.fromRGB(40, 130, 255), Wind = Color3.fromRGB(150, 240, 180),
	Earth = Color3.fromRGB(170, 120, 60), Light = Color3.fromRGB(255, 250, 200),
}

return Config
