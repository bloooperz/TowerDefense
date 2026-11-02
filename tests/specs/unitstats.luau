local U = require("../../src/shared/UnitStats")
return function(t)
	local u = { damage = 10, range = 5, rate = 1, abilityConfig = { a = 1 },
		upgrades = { { cost = 5, damage = 20 }, { cost = 9, range = 8, ability = { a = 2 } } } }
	t.test("stats accumulate", function()
		local s = U.at(u, 3)
		t.eq(s.damage, 20); t.eq(s.range, 8); t.eq(s.rate, 1); t.eq(s.ability.a, 2)
		t.eq(u.abilityConfig.a, 1) -- not mutated
	end)
	t.test("max level and costs", function()
		t.eq(U.maxLevel(u), 3); t.eq(U.upgradeCost(u, 1), 5); t.eq(U.upgradeCost(u, 3), nil)
	end)
end
