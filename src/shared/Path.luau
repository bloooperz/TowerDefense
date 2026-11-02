--!strict
-- PURE polyline math. Works with any Vector3-like type supporting + - * .Magnitude .Unit :Dot .X .Z
-- (Roblox Vector3 or lune's). No Instance access, so it is unit-testable.
local Path = {}
Path.__index = Path

export type Segment = { a: any, b: any, dir: any, len: number, start: number }

function Path.new(points: { any })
	assert(#points >= 2, "Path needs at least 2 points")
	local segs: { Segment } = {}
	local total = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len > 0 then
			table.insert(segs, { a = a, b = b, dir = (b - a).Unit, len = len, start = total })
			total += len
		end
	end
	return setmetatable({ points = points, segs = segs, length = total }, Path)
end

-- Segment containing distance d (binary search).
function Path:segmentAt(d: number): Segment
	local segs = self.segs
	local lo, hi = 1, #segs
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if segs[mid].start <= d then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return segs[lo]
end

-- Position and travel direction at distance d (clamped to [0, length]).
function Path:positionAt(d: number)
	d = math.clamp(d, 0, self.length)
	local s = self:segmentAt(d)
	return s.a + s.dir * (d - s.start), s.dir
end

-- Nearest point on the path to pos, measured in XZ only.
-- Returns (distance along path, horizontal offset from path).
function Path:nearest(pos): (number, number)
	local bestAlong, bestOff = 0, math.huge
	for _, s in ipairs(self.segs) do
		local vx, vz = s.b.X - s.a.X, s.b.Z - s.a.Z
		local l2 = vx * vx + vz * vz
		local f = 0
		if l2 > 0 then
			f = math.clamp(((pos.X - s.a.X) * vx + (pos.Z - s.a.Z) * vz) / l2, 0, 1)
		end
		local ox, oz = pos.X - (s.a.X + vx * f), pos.Z - (s.a.Z + vz * f)
		local off = math.sqrt(ox * ox + oz * oz)
		if off < bestOff then
			bestOff, bestAlong = off, s.start + f * s.len
		end
	end
	return bestAlong, bestOff
end

return Path
