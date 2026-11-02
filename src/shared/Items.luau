--!strict
-- PURE item/material registry. Inventory lives in PlayerData as items = { [id] = count }.
-- kind "unitXp": consumable XP food fed to an owned unit (server remote UseItem, validated).
local Items = {}

Items.LIST = {
	{ id = "XpFoodS", name = "Small XP Snack", kind = "unitXp", xp = 500, color = Color3 and Color3.fromRGB(120, 220, 120) or nil },
	{ id = "XpFoodM", name = "XP Bento", kind = "unitXp", xp = 2500, color = Color3 and Color3.fromRGB(80, 160, 255) or nil },
	{ id = "XpFoodL", name = "XP Feast", kind = "unitXp", xp = 10000, color = Color3 and Color3.fromRGB(200, 90, 255) or nil },
}
Items.MAX_STACK = 9999
Items.MAX_USE = 99 -- per request

local byId = {}
for i, it in ipairs(Items.LIST) do
	it.order = i
	byId[it.id] = it
end

function Items.get(id: string)
	return byId[id]
end

function Items.count(d, id: string): number
	return (d.items and d.items[id]) or 0
end

-- Add (or remove with negative n) in place; clamps to 0..MAX_STACK. Returns new count.
function Items.add(d, id: string, n: number): number
	assert(byId[id], "unknown item " .. tostring(id))
	d.items = d.items or {}
	local c = math.clamp(Items.count(d, id) + math.floor(n), 0, Items.MAX_STACK)
	d.items[id] = c > 0 and c or nil
	return c
end

-- Validate using `count` XP food `itemId` on unit `uid`. Returns (reason) or (nil, item, totalXp).
function Items.checkFeed(d, uid: string, itemId: string, count: number, maxLevel: number)
	local it = byId[itemId]
	if not it or it.kind ~= "unitXp" then
		return "Unknown XP item"
	end
	if count ~= count or count < 1 or count > Items.MAX_USE or math.floor(count) ~= count then
		return ("Use 1-%d items at a time"):format(Items.MAX_USE)
	end
	local u = d.units[uid]
	if not u then
		return "Unit not found"
	end
	if (u.level or 1) >= maxLevel then
		return "Unit is already max level"
	end
	if Items.count(d, itemId) < count then
		return ("Not enough %s (have %d)"):format(it.name, Items.count(d, itemId))
	end
	return nil, it, it.xp * count
end

return Items
