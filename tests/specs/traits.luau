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
	t("unknown trait is a no-op", function()
		eq(Traits.apply({ damage = 3 }, "Nope").damage, 3)
	end)
end
