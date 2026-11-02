-- Global constants. Content (units, enemies, maps, modes) lives in its own registries.
local Config = {}

-- WORLD
Config.MAP_ORIGIN = Vector3.new(1000, 0, 0)
Config.TRACK_TOP = 1.1 -- Y of the track surface (relative to map origin)
Config.GROUND_TOP = 0.5 -- Y of the ground surface (relative to map origin)
Config.FLY_HEIGHT = 6 -- extra height for flying enemies
Config.LOBBY_SPAWN = Vector3.new(0, 3, 0)
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
Config.STARTER_LOADOUT = { "Basic", "Sniper", "Rapid", "Mogumo" }

-- SERVER
Config.TICK_RATE = 0.1 -- seconds between server simulation ticks

-- Bump on notable pushes; server + client print it so stale Studio scripts are obvious.
Config.BUILD = "foundation-2"

return Config
