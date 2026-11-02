--!strict
-- PURE: what the lobby loadout cards show, including the "data not loaded yet" defaults.
-- loadoutAttr/levelsAttr are the raw player attributes ("Basic,Sniper" / "3,1"); nil = not
-- replicated yet -> starter loadout, every card "Lv 1", loading = true (placeholder portraits).
local LoadoutView = {}

export type Slot = { id: string?, level: number, loading: boolean }

local function split(s: string?): { string }
	local out = {}
	for v in string.gmatch(s or "", "[^,]+") do
		table.insert(out, v)
	end
	return out
end

function LoadoutView.slots(loadoutAttr: string?, levelsAttr: string?, starter: { string }, size: number): { Slot }
	local loading = loadoutAttr == nil
	local ids = loading and table.clone(starter) or split(loadoutAttr)
	local levels = split(levelsAttr)
	local out = {}
	for i = 1, size do
		local lv = (not loading) and tonumber(levels[i]) or 1
		table.insert(out, { id = ids[i], level = math.max(1, math.floor(lv or 1)), loading = loading })
	end
	return out
end

-- Level bar text + fill fraction for a raw Xp attribute (nil before data arrives -> Level 1, 0/N).
function LoadoutView.levelBar(xp: number?, progress: (number) -> (number, number, number)): (string, number)
	local l, into, need = progress(tonumber(xp) or 0)
	if need <= 0 then
		return ("Level %d [MAX]"):format(l), 1
	end
	return ("Level %d [%d/%d]"):format(l, into, need), math.clamp(into / need, 0, 1)
end

return LoadoutView
