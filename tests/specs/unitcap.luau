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
		t.eq(Summon.apply(d, 10, banner, { on = true, max = "Rare" }, deps) ~= nil, true)
		t.eq(Summon.autoSellCoversPool(banner, { on = true, max = "Epic" }), true)
		t.eq(Summon.autoSellCoversPool(banner, { on = false, max = "Mythic" }), false)
		t.eq(Summon.apply(d, 10, banner, { on = true, max = "Epic" }, deps), nil)
		t.eq(count(d), 95)
	end)
	t.test("custom cap via deps respected", function()
		t.eq(Summon.apply(data(5, 10000), 1, banner, nil, { rand = deps.rand, genUid = deps.genUid, newUnit = deps.newUnit, maxUnits = 5 }) ~= nil, true)
	end)
end
