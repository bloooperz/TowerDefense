-- Helpers for reading this player's placed units from workspace.Runtime.
local Players = game:GetService("Players")

local MyUnits = {}

function MyUnits.list()
	local out = {}
	local runtime = workspace:FindFirstChild("Runtime")
	if not runtime then
		return out
	end
	local me = Players.LocalPlayer.UserId
	for _, p in ipairs(runtime:GetChildren()) do
		if p:GetAttribute("UnitId") and p:GetAttribute("OwnerId") == me then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a:GetAttribute("UnitId") < b:GetAttribute("UnitId")
	end)
	return out
end

function MyUnits.count(unitIndex)
	local n = 0
	for _, p in ipairs(MyUnits.list()) do
		if p:GetAttribute("UnitIndex") == unitIndex then
			n += 1
		end
	end
	return n
end

-- True if a square of `size` at pos overlaps any placed unit (anyone's).
function MyUnits.overlapsAny(pos, size)
	local runtime = workspace:FindFirstChild("Runtime")
	if not runtime then
		return false
	end
	for _, p in ipairs(runtime:GetChildren()) do
		if p:GetAttribute("UnitId") then
			local minDist = (p.Size.X + size) / 2
			local d = p.Position - pos
			if math.abs(d.X) < minDist and math.abs(d.Z) < minDist then
				return true
			end
		end
	end
	return false
end

return MyUnits
