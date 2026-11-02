--!strict
-- PURE placement rules shared by client preview and server authority.
-- Returns nil if OK, else a player-facing reason string.
local PlacementRules = {}

-- Spot rule: inside map bounds and far enough from the track centerline (XZ).
-- map: { bounds, trackWidth }, path: Path, origin: Vector3-like
function PlacementRules.spotReason(map, path, origin, pos, size: number): string?
	if not map or not path then
		return "No map loaded"
	end
	local rx, rz = pos.X - origin.X, pos.Z - origin.Z
	if math.abs(rx) > map.bounds.X or math.abs(rz) > map.bounds.Z then
		return "Out of bounds"
	end
	local _, off = path:nearest(pos)
	if off < map.trackWidth / 2 + size / 2 then
		return "Too close to the track"
	end
	return nil
end

-- ctx: { state, inMatch, inLoadout, unit, cash, placed, maxPlaced, overlaps, spotReason }
function PlacementRules.reason(ctx): string?
	if not ctx.inMatch then
		return "You're not in a match"
	end
	if ctx.state ~= "waiting" and ctx.state ~= "running" then
		return "Can't place right now (" .. tostring(ctx.state) .. ")"
	end
	if not ctx.unit then
		return "Unknown unit"
	end
	if not ctx.inLoadout then
		return "Unit not in your loadout"
	end
	if ctx.placed >= ctx.maxPlaced then
		return "Limit reached!"
	end
	if ctx.cash < ctx.unit.cost then
		return "Not enough money!"
	end
	if ctx.spotReason then
		return ctx.spotReason
	end
	if ctx.overlaps then
		return "Overlaps another unit"
	end
	return nil
end

return PlacementRules
