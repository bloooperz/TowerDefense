local fs = require("@lune/fs")
local Summon = require("../../src/shared/Summon")
local Limits = require("../../src/shared/Limits")
local InventoryView = require("../../src/shared/InventoryView")

local LIST = { { id = "A", rarity = "Common", summonable = true }, { id = "B", rarity = "Rare", summonable = true }, { id = "C", rarity = "Epic", summonable = true } }
local function data(n, gems)
	local d = { gems = gems, gold = 0, units = {}, summonPity = 0 }
	for i = 1, n do
		d.units["u" .. i] = { uid = "u" .. i }
	end
	return d
end
local k = 0
local deps = { rand = function() return 0.5 end, genUid = function() k += 1; return "n" .. k end, newUnit = function(uid, id) return { uid = uid, id = id } end }
local function count(d) local c = 0; for _ in pairs(d.units) do c += 1 end; return c end

return function(t)
	local banner = Summon.banner(1, LIST)
	local cost1 = Summon.COST_PER_ROLL
	t.test("cap is 100 and shared by UI and server", function()
		t.eq(Limits.MAX_UNITS, 100)
		t.eq(InventoryView.MAX_UNITS, Limits.MAX_UNITS)
		t.eq(Summon.MAX_UNITS, Limits.MAX_UNITS)
		t.eq(fs.readFile("src/shared/Config.luau"):find("Config.MAX_UNITS = require(script.Parent.Limits).MAX_UNITS", 1, true) ~= nil, true)
		t.eq(fs.readFile("src/server/Services/PlayerData.luau"):find("maxUnits = Config.MAX_UNITS", 1, true) ~= nil, true)
	end)
	t.test("under cap succeeds", function()
		local d = data(99, cost1)
		t.eq(Summon.apply(d, 1, banner, nil, deps), nil)
		t.eq(count(d), 100); t.eq(d.gems, 0)
	end)
	t.test("at cap rejected, no charge", function()
		local d = data(100, 10000)
		t.eq(Summon.apply(d, 1, banner, nil, deps), "Inventory full (100/100). Sell units to make room.")
		t.eq(d.gems, 10000); t.eq(count(d), 100)
	end)
	t.test("over cap rejected, units kept", function()
		local d = data(150, 10000)
		t.eq(Summon.apply(d, 1, banner, nil, deps), "Inventory full (150/100). Sell units to make room.")
		t.eq(count(d), 150); t.eq(d.gems, 10000)
	end)
	t.test("multi-summon needing more room rejected whole, no charge", function()
		local d = data(95, 10 * cost1)
		t.eq(Summon.apply(d, 10, banner, nil, deps), "Not enough room: need 10 free slots, you have 5")
		t.eq(d.gems, 10 * cost1); t.eq(count(d), 95); t.eq(d.summonPity, 0)
	end)
	t.test("partial auto-sell still needs full room; full-pool auto-sell does not", function()
		local d = data(95, 10 * cost1)
		-- 79041f8 rejected this (threshold didn't cover Epic); now rolls (all Rare at rand 0.5) are auto-sold first, so it fits
		t.eq(Summon.apply(d, 10, banner, { on = true, max = "Rare" }, deps), nil)
		t.eq(count(d), 95)
		d.gems = 10 * cost1
		t.eq(Summon.autoSellCoversPool(banner, { on = true, max = "Epic" }), true)
		t.eq(Summon.autoSellCoversPool(banner, { on = false, max = "Mythic" }), false)
		t.eq(Summon.apply(d, 10, banner, { on = true, max = "Epic" }, deps), nil)
		t.eq(count(d), 95)
	end)
	-- stubbed rolls: first `epics` rolls draw Epic (rand 0 on the rarity call), the rest Rare (0.9)
	local function stub(epics)
		local calls = 0
		return function()
			calls += 1
			local roll, rarityCall = (calls + 1) // 2, calls % 2 == 1
			if rarityCall and roll <= epics then
				return 0
			end
			return 0.9
		end
	end
	local function depsWith(rand) return { rand = rand, genUid = deps.genUid, newUnit = deps.newUnit } end
	t.test("x50 auto-sell Rare near cap succeeds when kept units fit", function()
		local d = data(95, 50 * cost1)
		t.eq(Summon.apply(d, 50, banner, { on = true, max = "Rare" }, depsWith(stub(3))), nil)
		t.eq(count(d), 98); t.eq(d.gems, 0)
		t.eq(d.gold, 47 * (Summon.SELL_GOLD.Rare or 0))
	end)
	t.test("x50 auto-sell Rare rejected whole when kept exceed room", function()
		local d = data(95, 50 * cost1)
		d.summonPity = 7
		t.eq(Summon.apply(d, 50, banner, { on = true, max = "Rare" }, depsWith(stub(6))), "Not enough room: need 6 free slots, you have 5")
		t.eq(d.gems, 50 * cost1); t.eq(d.summonPity, 7); t.eq(count(d), 95); t.eq(d.gold, 0)
	end)
	t.test("custom cap via deps respected", function()
		t.eq(Summon.apply(data(5, 10000), 1, banner, nil, { rand = deps.rand, genUid = deps.genUid, newUnit = deps.newUnit, maxUnits = 5 }) ~= nil, true)
	end)
end
