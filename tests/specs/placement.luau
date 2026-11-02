local P = require("../../src/shared/PlacementRules")
local Path = require("../../src/shared/Path")
return function(t)
	local V = t.V
	local unit = { id = "Basic", cost = 100 }
	local function ctx(over)
		local c = { state = "waiting", inMatch = true, inLoadout = true, unit = unit, cash = 500, placed = 0, maxPlaced = 5, overlaps = false, spotReason = nil }
		for k, v in pairs(over or {}) do
			c[k] = v
		end
		return c
	end
	t.test("placement ok", function()
		t.eq(P.reason(ctx()), nil)
		t.eq(P.reason(ctx({ state = "running" })), nil)
	end)
	t.test("placement rejections in priority order", function()
		t.eq(P.reason(ctx({ inMatch = false })), "You're not in a match")
		t.eq(P.reason(ctx({ state = "idle" })), "Can't place right now (idle)")
		t.eq(P.reason(ctx({ state = "over" })), "Can't place right now (over)")
		t.eq(P.reason(ctx({ unit = false })), "Unknown unit")
		t.eq(P.reason(ctx({ inLoadout = false })), "Unit not in your loadout")
		t.eq(P.reason(ctx({ placed = 5 })), "Limit reached!")
		t.eq(P.reason(ctx({ cash = 99 })), "Not enough money!")
		t.eq(P.reason(ctx({ spotReason = "Out of bounds" })), "Out of bounds")
		t.eq(P.reason(ctx({ overlaps = true })), "Overlaps another unit")
		t.eq(P.reason(ctx({ cash = 0, overlaps = true })), "Not enough money!")
	end)
	local map = { bounds = V.new(100, 0, 60), trackWidth = 8 }
	local origin = V.new(0, 0, 0)
	local path = Path.new({ V.new(-100, 0, 0), V.new(100, 0, 0) })
	t.test("spot: valid off-track", function()
		t.eq(P.spotReason(map, path, origin, V.new(0, 0, 10), 2), nil)
	end)
	t.test("spot: too close to track", function()
		t.eq(P.spotReason(map, path, origin, V.new(0, 0, 4), 2), "Too close to the track")
	end)
	t.test("spot: out of bounds", function()
		t.eq(P.spotReason(map, path, origin, V.new(0, 0, 61), 2), "Out of bounds")
		t.eq(P.spotReason(map, path, origin, V.new(101, 0, 10), 2), "Out of bounds")
	end)
	t.test("spot: no map", function()
		t.eq(P.spotReason(nil, path, origin, V.new(0, 0, 10), 2), "No map loaded")
	end)
	t.test("spot respects map origin", function()
		local o = V.new(500, 0, 500)
		local p2 = Path.new({ V.new(400, 0, 500), V.new(600, 0, 500) })
		t.eq(P.spotReason(map, p2, o, V.new(500, 0, 510), 2), nil)
	end)
end
