local UL = require("../../src/shared/UnitLevel")
local PL = require("../../src/shared/PlayerLevel")
local Items = require("../../src/shared/Items")
local MS = require("../../src/shared/Milestones")
local D = require("../../src/shared/DataSchema")
local serde = require("@lune/serde")

return function(t)
	local n = 0
	local function gen() n += 1; return "u" .. n end
	local function close(a, b, tol, msg)
		if math.abs(a - b) > tol then error((msg or "") .. " expected ~" .. b .. " got " .. a, 2) end
	end

	-- damage curve
	t.test("damage mult: L1 = 1x, L80 ~ 60x", function()
		t.near(UL.damageMult(1), 1); close(UL.damageMult(80), 60, 0.01)
		close(UL.damageMult(10), 3.25, 0.01); close(UL.damageMult(40), 19.07, 0.01)
	end)
	t.test("damage mult strictly increasing and clamped", function()
		for l = 2, 80 do
			assert(UL.damageMult(l) > UL.damageMult(l - 1), "not monotonic at " .. l)
		end
		t.eq(UL.damageMult(0), 1); close(UL.damageMult(200), 60, 0.01)
		-- early levels meaningful: L2 at least +0.15x
		assert(UL.damageMult(2) - 1 > 0.15)
	end)
	t.test("applyDamage: damage only, sandbox override absolute", function()
		local st = { damage = 1, range = 10, rate = 1 }
		local o = UL.applyDamage(st, 80)
		close(o.damage, 60, 0.01); t.eq(o.range, 10); t.eq(o.rate, 1); t.eq(st.damage, 1)
		t.eq(UL.applyDamage(st, 80, { damage = 5 }).damage, 1) -- override already resolved upstream
		close(UL.applyDamage(st, 80, { damage = 0 }).damage, 60, 0.01)
	end)

	-- XP curves
	t.test("unit xpToNext curve", function()
		t.eq(UL.xpToNext(1), 100); t.eq(UL.xpToNext(2), 121); t.eq(UL.xpToNext(79), 7744); t.eq(UL.xpToNext(80), 0)
		for l = 2, 79 do assert(UL.xpToNext(l) > UL.xpToNext(l - 1)) end
		t.eq(UL.totalXpFor(2), 100); t.eq(UL.totalXpFor(3), 221)
	end)
	t.test("player level curve + unlocks", function()
		t.eq(PL.levelForXp(0), 1); t.eq(PL.levelForXp(99), 1); t.eq(PL.levelForXp(100), 2); t.eq(PL.levelForXp(8100), 10)
		t.eq(PL.levelForXp(1e12), PL.MAX)
		for l = 1, 50 do t.eq(PL.levelForXp(PL.xpForLevel(l)), l) end
		local l, into, need = PL.progress(450); t.eq(l, 3); t.eq(into, 50); t.eq(need, 500)
		t.eq(PL.isUnlocked(9, "Trade"), false); t.eq(PL.isUnlocked(10, "Trade"), true)
		assert(PL.check(1, "Trade")); t.eq(PL.check(1, "Summon"), nil)
	end)

	-- XP sources
	t.test("stage XP: waves + win bonus, scale", function()
		t.eq(UL.stageXp({ wavesCleared = 10, won = true }), 400)
		t.eq(UL.stageXp({ wavesCleared = 3, won = false }), 60)
		t.eq(UL.stageXp({ wavesCleared = 10, won = true, rewardScale = 1.5 }), 600)
		t.eq(UL.stageXp({ wavesCleared = -4 }), 0)
	end)
	t.test("addXp overflow carries across levels", function()
		local u = { level = 1, xp = 50 }
		local lv, w = UL.addXp(u, 100 + 121 + 10) -- 50 + 231 = 281 = 100 + 121 + 60
		t.eq(lv, 2); t.eq(u.level, 3); t.eq(u.xp, 60); t.eq(w, 0)
	end)
	t.test("addXp caps at 80 and reports waste", function()
		local u = { level = 79, xp = 7000 }
		local lv, w = UL.addXp(u, 1000)
		t.eq(lv, 1); t.eq(u.level, 80); t.eq(u.xp, 0); t.eq(w, 256)
		local lv2, w2 = UL.addXp(u, 50); t.eq(lv2, 0); t.eq(w2, 50); t.eq(u.level, 80)
		local z = { level = 1, xp = 0 }; UL.addXp(z, 1e9); t.eq(z.level, 80); t.eq(z.xp, 0)
	end)
	t.test("XP food: validation + feed", function()
		local d = { units = { a = { uid = "a", unitId = "Basic", level = 1, xp = 0 } }, loadout = {}, items = {} }
		assert(Items.checkFeed(d, "a", "XpFoodS", 1, 80)) -- none owned
		Items.add(d, "XpFoodS", 3); t.eq(Items.count(d, "XpFoodS"), 3)
		assert(Items.checkFeed(d, "a", "Nope", 1, 80)); assert(Items.checkFeed(d, "zz", "XpFoodS", 1, 80))
		assert(Items.checkFeed(d, "a", "XpFoodS", 4, 80)); assert(Items.checkFeed(d, "a", "XpFoodS", 0, 80))
		assert(Items.checkFeed(d, "a", "XpFoodS", 1.5, 80))
		local why, it, xp = Items.checkFeed(d, "a", "XpFoodS", 2, 80)
		t.eq(why, nil); t.eq(it.id, "XpFoodS"); t.eq(xp, 1000)
		UL.addXp(d.units.a, xp); Items.add(d, "XpFoodS", -2)
		t.eq(Items.count(d, "XpFoodS"), 1); t.eq(UL.totalXp(d.units.a), 1000)
		Items.add(d, "XpFoodS", -5); t.eq(Items.count(d, "XpFoodS"), 0); t.eq(d.items.XpFoodS, nil)
		d.units.a.level = 80; assert(Items.checkFeed(d, "a", "XpFoodL", 1, 80))
	end)
	t.test("fuse: XP value and validation", function()
		local d = { units = {
			t = { uid = "t", unitId = "Basic", level = 1, xp = 0 },
			a = { uid = "a", unitId = "Basic", level = 2, xp = 20 },
			b = { uid = "b", unitId = "Basic", level = 1, xp = 0 },
			e = { uid = "e", unitId = "Basic", level = 1, xp = 0 },
			s = { uid = "s", unitId = "Sniper", level = 1, xp = 0 },
		}, loadout = { "t", "e" } }
		local why, xp = UL.checkFuse(d, "t", { "a", "b" })
		t.eq(why, nil); t.eq(xp, (300 + 60) + 300)
		assert(UL.checkFuse(d, "t", { "e" }), "equipped must be rejected")
		assert(UL.checkFuse(d, "t", { "t" }), "self must be rejected")
		assert(UL.checkFuse(d, "t", { "a", "a" }), "dupe uid rejected")
		assert(UL.checkFuse(d, "t", { "s" }), "other unitId rejected")
		assert(UL.checkFuse(d, "t", { "ghost" })); assert(UL.checkFuse(d, "t", {})); assert(UL.checkFuse(d, "nope", { "a" }))
		d.units.t.level = 80; assert(UL.checkFuse(d, "t", { "a" }))
	end)

	-- milestones
	t.test("milestone claim: pays once, no double claims, level gate", function()
		local d = { gems = 0, rerolls = 0, items = {}, milestones = {} }
		assert(MS.check(d, 1, 5)); assert(MS.check(d, 99, 4)) -- locked / no milestone
		t.eq(MS.pending(d, 5), 3)
		t.eq(MS.claim(d, 5, 5, Items.add), nil)
		t.eq(d.gems, 150); t.eq(d.rerolls, 1); t.eq(Items.count(d, "XpFoodM"), 1)
		assert(MS.claim(d, 5, 5, Items.add), "double claim must fail"); t.eq(d.gems, 150)
		t.eq(MS.pending(d, 5), 2); t.eq(d.milestones["5"], true)
	end)

	-- persistence
	t.test("save/load JSON round-trip keeps levels, items, milestones", function()
		local d = D.default(gen, { "Basic" })
		local uid = d.loadout[1]
		UL.addXp(d.units[uid], 5000); Items.add(d, "XpFoodL", 2); MS.claim(d, 3, 2, Items.add)
		local back = D.migrate(serde.decode("json", serde.encode("json", d)), gen, { "Basic" })
		t.eq(back.version, D.VERSION); t.eq(back.units[uid].level, d.units[uid].level); t.eq(back.units[uid].xp, d.units[uid].xp)
		t.eq(Items.count(back, "XpFoodL"), 2); t.eq(Items.count(back, "XpFoodS"), 2); t.eq(MS.isClaimed(back, 2), true)
	end)
	t.test("v3 -> v4 migration: lifetime unit xp converted, items/milestones added", function()
		local old = { version = 3, gems = 1, xp = 450, units = {
			x = { uid = "x", unitId = "Basic", level = 4, xp = 500 }, -- old: lv floor(500/150)+1 = 4, 50 into
			y = { uid = "y", unitId = "Rapid", level = 50, xp = 99999 },
			bad = "junk",
		}, loadout = { "x", "x", "y" }, stats = {}, settings = {} }
		local d = D.migrate(old, gen, { "Basic" })
		t.eq(d.version, 4); t.eq(type(d.items), "table"); t.eq(type(d.milestones), "table")
		t.eq(d.units.x.level, 4); t.eq(d.units.x.xp, 50); t.eq(d.units.bad, nil)
		t.eq(d.units.y.level, 50)
		UL.normalize(d.units.y) -- server normalizes after migrate
		assert(d.units.y.level >= 50 and d.units.y.level <= 80)
		t.eq(#d.loadout, 2) -- duplicate uid removed
	end)
	t.test("v1 -> v4 chain still works", function()
		local d = D.migrate({ version = 1, coins = 7, owned = { "Rapid" } }, gen, { "Basic" })
		t.eq(d.version, 4); t.eq(d.gems, 7); t.eq(d.units[d.loadout[1]].level, 1); t.eq(type(d.items), "table")
	end)
end
