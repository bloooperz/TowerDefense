local Traits = require("../../src/shared/Traits")
return function(ctx)
	local t, eq, near = ctx.test, ctx.eq, ctx.near
	t("None trait leaves stats unchanged", function()
		local s = Traits.apply({ damage = 10, range = 20, rate = 1 }, "None")
		eq(s.damage, 10); eq(s.range, 20); eq(s.rate, 1)
	end)
	t("Celestial multiplies and does not mutate input", function()
		local base = { damage = 10, range = 20, rate = 1 }
		local s = Traits.apply(base, "Celestial")
		near(s.damage, 15); near(s.range, 22); near(s.rate, 0.8); eq(base.damage, 10)
	end)
	t("resolve: overrides replace level stats, <=0 falls back, trait on top", function()
		local base = { damage = 10, range = 20, rate = 1, ability = { x = 1 } }
		local s = Traits.resolve(base, { damage = 100, range = 0, rate = 0.5, trait = "Sharp" })
		near(s.damage, 115); eq(s.range, 20); near(s.rate, 0.5); eq(s.ability.x, 1)
	end)
	t("resolve: overrides persist across a level change (upgrade path)", function()
		local ov = { damage = 50, range = 30, rate = 2 }
		local lv2 = Traits.resolve({ damage = 14, range = 22, rate = 0.9, ability = {} }, ov)
		eq(lv2.damage, 50); eq(lv2.range, 30); eq(lv2.rate, 2)
	end)
	t("resolve: nil overrides returns base", function()
		local b = { damage = 1 }
		eq(Traits.resolve(b, nil), b)
	end)
	t("unknown trait is a no-op", function()
		eq(Traits.apply({ damage = 3 }, "Nope").damage, 3)
	end)
end
