--!strict
-- PURE wave generator. Returns { groups = { {enemy, count, delay} }, hpMult, bonus, total }.
-- Maps may override with `waves = { [n] = { groups = ... } }`.
local Waves = {}

Waves.BOSS_EVERY = 10

function Waves.generate(wave: number, opts)
	opts = opts or {}
	local hpScale = opts.hpScale or 1
	local groups = {}
	table.insert(groups, { enemy = "Basic", count = 3 + wave * 2, delay = 1 })
	if wave >= 3 then
		table.insert(groups, { enemy = "Fast", count = 2 + wave // 2, delay = 0.6 })
	end
	if wave >= 4 and wave % 2 == 0 then
		table.insert(groups, { enemy = "Flying", count = 1 + wave // 3, delay = 1.2 })
	end
	if wave >= 5 then
		table.insert(groups, { enemy = "Tank", count = 1 + (wave - 5) // 2, delay = 2 })
	end
	local isBoss = wave % Waves.BOSS_EVERY == 0 or (opts.maxWaves ~= nil and wave == opts.maxWaves)
	if isBoss then
		table.insert(groups, { enemy = "Boss", count = 1, delay = 0 })
	end
	local total = 0
	for _, g in ipairs(groups) do
		total += g.count
	end
	return {
		groups = groups,
		hpMult = (1 + (wave - 1) * 0.15) * hpScale,
		speedMult = 1 + math.min(wave * 0.02, 0.5),
		bonus = 25 + wave * 5,
		total = total,
		boss = isBoss,
	}
end

return Waves
