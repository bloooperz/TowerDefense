--!strict
-- PURE level-up milestone rewards. Claimed set lives in PlayerData as milestones = { ["<level>"] = true }
-- (string keys so DataStore treats it as a dictionary).
-- reward = { gems?, rerolls?, items? = { [itemId] = n } }
local Milestones = {}

Milestones.LIST = {
	{ level = 2, gems = 50, items = { XpFoodS = 2 } },
	{ level = 3, gems = 75, items = { XpFoodS = 3 } },
	{ level = 5, gems = 150, rerolls = 1, items = { XpFoodM = 1 } },
	{ level = 10, gems = 300, items = { XpFoodM = 3 } },
	{ level = 15, gems = 400, rerolls = 2, items = { XpFoodL = 1 } },
	{ level = 20, gems = 600, items = { XpFoodL = 2 } },
	{ level = 30, gems = 1000, rerolls = 5, items = { XpFoodL = 3 } },
	{ level = 50, gems = 2500, items = { XpFoodL = 10 } },
}

local byLevel = {}
for _, m in ipairs(Milestones.LIST) do
	byLevel[m.level] = m
end

function Milestones.get(level: number)
	return byLevel[level]
end

function Milestones.isClaimed(d, level: number): boolean
	return d.milestones ~= nil and d.milestones[tostring(level)] == true
end

-- nil if claimable, else reason.
function Milestones.check(d, playerLevel: number, level: number): string?
	local m = byLevel[level]
	if not m then
		return "No milestone at level " .. tostring(level)
	end
	if Milestones.isClaimed(d, level) then
		return "Milestone already claimed"
	end
	if playerLevel < level then
		return ("Reach player level %d first"):format(level)
	end
	return nil
end

-- Marks claimed and pays out in place. addItem(d, id, n) is passed in (keeps this module pure).
function Milestones.claim(d, playerLevel: number, level: number, addItem)
	local why = Milestones.check(d, playerLevel, level)
	if why then
		return why
	end
	local m = byLevel[level]
	d.milestones = d.milestones or {}
	d.milestones[tostring(level)] = true
	d.gems = (d.gems or 0) + (m.gems or 0)
	d.rerolls = (d.rerolls or 0) + (m.rerolls or 0)
	for id, n in pairs(m.items or {}) do
		addItem(d, id, n)
	end
	return nil
end

-- Count of reached-but-unclaimed milestones (for a badge).
function Milestones.pending(d, playerLevel: number): number
	local n = 0
	for _, m in ipairs(Milestones.LIST) do
		if m.level <= playerLevel and not Milestones.isClaimed(d, m.level) then
			n += 1
		end
	end
	return n
end

return Milestones
