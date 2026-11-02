-- Placeholder trait table (no trait system exists yet; DataSchema has unit.trait = nil).
-- Pure data + helper; used by the Studio dev sandbox. Multipliers apply to placed-unit stats.
local Traits = {}

Traits.list = {
	{ id = "None", name = "None" },
	{ id = "Swift", name = "Swift", rate = 0.85 }, -- rate is seconds between attacks: lower = faster
	{ id = "Sharp", name = "Sharp", damage = 1.15 },
	{ id = "Hawkeye", name = "Hawkeye", range = 1.2 },
	{ id = "Golden", name = "Golden", damage = 1.1, range = 1.1, rate = 0.9 },
	{ id = "Celestial", name = "Celestial", damage = 1.5, range = 1.1, rate = 0.8 },
}
Traits.byId = {}
for _, t in ipairs(Traits.list) do
	Traits.byId[t.id] = t
end

-- Returns a new stats table with the trait's multipliers applied.
function Traits.apply(stats, traitId)
	local t = Traits.byId[traitId]
	local out = table.clone(stats)
	if t then
		for _, k in ipairs({ "damage", "range", "rate" }) do
			if t[k] and out[k] then
				out[k] *= t[k]
			end
		end
	end
	return out
end

return Traits
