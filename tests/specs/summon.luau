local S = require("../../src/shared/Summon")
local D = require("../../src/shared/DataSchema")
local Settings = require("../../src/shared/Settings")
local Keybinds = require("../../src/shared/Keybinds")

-- Real roster (unit defs are plain tables; id = module name like Registry.load).
-- Unit modules use Roblox types, so read rarity/summonable from source.
local fs = require("@lune/fs")
local ROSTER = {}
for _, f in ipairs(fs.readDir("src/shared/Units")) do
	local id = f:match("^(%w+)%.luau$")
	if id and id ~= "init" then
		local src = fs.readFile("src/shared/Units/" .. f)
		table.insert(ROSTER, { id = id, rarity = src:match('rarity = "(%w+)"'), summonable = src:find("summonable = true", 1, true) ~= nil })
	end
end
table.sort(ROSTER, function(a, b) return a.id < b.id end)
assert(#ROSTER >= 4, "roster not found")

return function(t)
	local n = 0
	local function gen() n += 1; return "s" .. n end
	local function newData(gems)
		local d = D.migrate(nil, gen, {})
		d.gems = gems or 0
		return d
	end
	local function deps(seq)
		local i = 0
		return { rand = function() i += 1; return seq and seq[(i - 1) % #seq + 1] or math.random() end, genUid = gen, newUnit = D.newUnit }
	end

	t.test("base rates sum to 1; effective rates sum to 1", function()
		local sum = 0
		for _, r in ipairs(S.RARITIES) do sum += S.RATES[r] or 0 end
		t.near(sum, 1)
		local eff = S.effectiveRates(S.banner(123, ROSTER))
		local es = 0
		for _, p in pairs(eff) do es += p end
		t.near(es, 1)
	end)
	t.test("Mogumo is never in the pool / any banner / drops", function()
		for w = 0, 500 do
			local b = S.banner(w, ROSTER)
			assert(not table.find(b.units, "Mogumo"), "Mogumo in banner " .. w)
		end
		local b = S.banner(1, ROSTER)
		local pity = 0
		for _ = 1, 2000 do
			local id
			id, _, pity = S.roll(b, pity, math.random)
			assert(id ~= "Mogumo", "Mogumo dropped")
		end
	end)
	t.test("banner deterministic per 30-min window, built from summonable units", function()
		local t0 = 1800 * 1000
		t.eq(S.window(t0), S.window(t0 + 1799))
		assert(S.window(t0 + 1800) ~= S.window(t0))
		local a, b = S.banner(S.window(t0), ROSTER), S.banner(S.window(t0 + 1000), ROSTER)
		t.eq(table.concat(a.units, ","), table.concat(b.units, ","))
		t.eq(#a.units, 3) -- Basic, Rapid (Rare) + Sniper (Epic)
		t.eq(S.secondsLeft(t0 + 100), 1700)
	end)
	t.test("empty rarities pass rates down; top = highest rarity present (Epic)", function()
		local eff, top = S.effectiveRates(S.banner(5, ROSTER))
		t.eq(top, "Epic"); t.eq(eff.Mythic, nil); t.eq(eff.Legendary, nil)
		t.near(eff.Epic, S.RATES.Epic + S.RATES.Legendary + S.RATES.Mythic)
	end)
	t.test("pity guarantees top rarity at threshold and resets", function()
		local b = S.banner(9, ROSTER)
		local _, top = S.effectiveRates(b)
		local id, rarity, pity = S.roll(b, S.PITY_THRESHOLD - 1, function() return 0.999 end)
		t.eq(rarity, top); t.eq(pity, 0); assert(id)
		local _, r2, p2 = S.roll(b, 5, function() return 0.999 end) -- 0.999 -> lowest rarity
		t.eq(r2, "Rare"); t.eq(p2, 6)
		local _, r3, p3 = S.roll(b, 5, function() return 0.0 end) -- natural top -> reset
		t.eq(r3, top); t.eq(p3, 0)
	end)
	t.test("cost validation: tiers 1/10/50 only, gems price per roll", function()
		t.eq((S.check(2, 1e9)), "Invalid summon amount")
		t.eq((S.check("1", 1e9)), "Invalid summon amount")
		local why, cost = S.check(10, 500)
		t.eq(why, nil); t.eq(cost, 10 * S.COST_PER_ROLL)
		t.eq(select(2, S.check(50, 1e9)), 50 * S.COST_PER_ROLL)
	end)
	t.test("insufficient gems rejected, nothing changes", function()
		local d = newData(S.COST_PER_ROLL - 1)
		local units0 = 0
		for _ in pairs(d.units) do units0 += 1 end
		local why = S.apply(d, 1, S.banner(1, ROSTER), nil, deps())
		assert(why and why:find("Not enough Gems"), why)
		t.eq(d.gems, S.COST_PER_ROLL - 1); t.eq(d.summonPity, 0)
	end)
	t.test("x10: deducts gems, adds 10 units, pity persisted", function()
		local d = newData(500)
		local why, res = S.apply(d, 10, S.banner(1, ROSTER), nil, deps({ 0.9 }))
		t.eq(why, nil); t.eq(#res, 10); t.eq(d.gems, 500 - 10 * S.COST_PER_ROLL)
		local c = 0
		for _ in pairs(d.units) do c += 1 end
		t.eq(c, 10); t.eq(d.summonPity, 10)
	end)
	t.test("auto-sell threshold: at/below sold for gold, above kept", function()
		assert(S.shouldAutoSell("Rare", { on = true, max = "Rare" }))
		assert(not S.shouldAutoSell("Epic", { on = true, max = "Rare" }))
		assert(not S.shouldAutoSell("Rare", { on = false, max = "Mythic" }))
		assert(not S.shouldAutoSell("Rare", nil))
		local d = newData(500)
		-- 0.9 -> Rare rarity each roll
		local _, res, back = S.apply(d, 10, S.banner(1, ROSTER), { on = true, max = "Rare" }, deps({ 0.9 }))
		t.eq(back, 10 * S.SELL_GOLD.Rare); t.eq(d.gold, back); t.eq(d.gems, 0)
		for _, r in ipairs(res) do t.eq(r.sold, S.SELL_GOLD.Rare); t.eq(r.uid, nil) end
		t.eq(next(d.units), nil)
	end)
	t.test("sell value per rarity", function()
		t.eq(S.SELL_GOLD.Rare, 10); t.eq(S.SELL_GOLD.Epic, 20); t.eq(S.SELL_GOLD.Legendary, 40); t.eq(S.SELL_GOLD.Mythic, 100)
		local d = newData(0)
		d.units.a = D.newUnit("a", "Basic"); d.units.b = D.newUnit("b", "Sniper"); d.loadout = { "a" }
		local why, g = S.checkSell(d, "b", "Epic")
		t.eq(why, nil); t.eq(g, 20)
	end)
	t.test("sell blocked: not owned, on hotbar, placed, locked, last unit", function()
		local d = newData(0)
		d.units.a = D.newUnit("a", "Basic"); d.units.b = D.newUnit("b", "Rapid"); d.loadout = { "a" }
		assert(S.checkSell(d, "zzz", "Rare"))
		assert((S.checkSell(d, "a", "Rare")):find("hotbar"))
		assert((S.checkSell(d, "b", "Rare", { b = true })):find("placed"))
		d.units.b.locked = true
		assert((S.checkSell(d, "b", "Rare")):find("locked"))
		d.units.b = nil; d.loadout = {}
		assert((S.checkSell(d, "a", "Rare")):find("last unit"))
	end)
	t.test("starter: new account empty, claim grants Basic + 500 gems once", function()
		local d = D.migrate(nil, gen, { "Basic" })
		t.eq(next(d.units), nil); t.eq(d.starterChosen, false); t.eq(d.gems, 0); t.eq(d.gold, 0); t.eq(d.rerolls, 0)
		assert(S.claimStarter(d, "Mogumo", gen, D.newUnit))
		t.eq(S.claimStarter(d, "Basic", gen, D.newUnit), nil)
		t.eq(d.gems, 500); t.eq(#d.loadout, 1); t.eq(d.starterChosen, true)
		t.eq(S.claimStarter(d, "Basic", gen, D.newUnit), "Starter already chosen")
		t.eq(d.gems, 500)
		assert(S.STARTER_GEMS >= 10 * S.COST_PER_ROLL, "starter gems afford one x10")
	end)
	t.test("v4 accounts with units migrate as starterChosen", function()
		local d = D.migrate({ version = 4, gems = 3, units = { x = { uid = "x", unitId = "Rapid", level = 1, xp = 0 } }, loadout = { "x" }, stats = {} }, gen, { "Basic" })
		t.eq(d.starterChosen, true); t.eq(d.summonPity, 0); t.eq(d.units.x.unitId, "Rapid")
	end)
	t.test("settings: autoSell defaults off, threshold validated", function()
		local s = Settings.sanitize({}, Keybinds)
		t.eq(s.autoSell, false); t.eq(s.autoSellMax, "Rare"); t.eq(s.skipSummonAnim, false)
		local s2, p = Settings.sanitize({ autoSellMax = "Godly" }, Keybinds)
		t.eq(s2.autoSellMax, "Rare"); t.eq(#p, 1)
		t.eq(Settings.sanitize({ autoSellMax = "Epic", autoSell = true }, Keybinds).autoSellMax, "Epic")
	end)
end
