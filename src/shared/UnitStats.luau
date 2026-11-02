--!strict
-- PURE unit stat helpers.
local UnitStats = {}

function UnitStats.maxLevel(u): number
	return 1 + (u.upgrades and #u.upgrades or 0)
end

function UnitStats.maxPlaced(u): number
	return u.maxPlaced or 99
end

-- Absolute stats at a level: upgrades set values; omitted = unchanged.
function UnitStats.at(u, level: number)
	local ability = {}
	for k, v in pairs(u.abilityConfig or {}) do
		ability[k] = v
	end
	local st = { damage = u.damage, range = u.range, rate = u.rate, ability = ability }
	for i = 1, level - 1 do
		local up = u.upgrades and u.upgrades[i]
		if not up then
			break
		end
		for _, k in ipairs({ "damage", "range", "rate" }) do
			if up[k] ~= nil then
				st[k] = up[k]
			end
		end
		for k, v in pairs(up.ability or {}) do
			st.ability[k] = v
		end
	end
	return st
end

-- Cost to go from `level` to level + 1, or nil at max.
function UnitStats.upgradeCost(u, level: number): number?
	local up = u.upgrades and u.upgrades[level]
	return up and up.cost
end

return UnitStats
