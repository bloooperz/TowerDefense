-- Map registry + helpers (world-space path, placement validity).
local Config = require(script.Parent.Config)
local Path = require(script.Parent.Path)
local PlacementRules = require(script.Parent.PlacementRules)
local Maps = require(script.Parent.Registry).load(script)

local cache = {}

-- World-space Path for a map (cached). Waypoints are relative XZ; Y = track surface.
function Maps.path(map)
	if not cache[map.id] then
		local pts = {}
		for _, w in ipairs(map.waypoints) do
			table.insert(pts, Config.MAP_ORIGIN + Vector3.new(w.X, Config.TRACK_TOP, w.Z))
		end
		cache[map.id] = Path.new(pts)
	end
	return cache[map.id]
end

function Maps.spawnPoint(map)
	return Config.MAP_ORIGIN + map.spawnOffset
end

-- Same rule on client (preview) and server (authority). Returns reason or nil.
function Maps.placementReason(map, pos: Vector3, size: number): string?
	return PlacementRules.spotReason(map, map and Maps.path(map), Config.MAP_ORIGIN, pos, size)
end

return Maps
