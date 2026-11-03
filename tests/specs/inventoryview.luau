local IV = require("../../src/shared/InventoryView")
local defs = {
	basic = { name = "Basic", rarity = "Rare", damage = 20, rate = 0.5, range = 18, role = "DPS", cost = 50 },
	sniper = { name = "Sniper", rarity = "Epic", damage = 60, rate = 2, range = 40 },
}
local traits = { Swift = { id = "Swift", name = "Swift", rate = 0.85 }, Sharp = { id = "Sharp", name = "Sharp", damage = 1.15, desc = "Hits harder." } }
local get = function(id) return defs[id] end
return function(t)
	t.test("loading state when attribute missing", function()
		local vm = IV.cards(nil, get, traits)
		t.eq(vm.loading, true); t.eq(#vm.cards, 0); t.eq(vm.message, IV.LOADING)
	end)
	t.test("maps inventory to cards, equipped first", function()
		local vm = IV.cards({
			{ uid = "a", unitId = "basic", level = 3, trait = "Swift" },
			{ uid = "b", unitId = "sniper", level = 1, equipped = true },
			{ uid = "c", unitId = "ghost", level = 9, trait = "None" },
		}, get, traits)
		t.eq(vm.header, "Units: 3/100"); t.eq(vm.loading, false)
		t.eq(vm.cards[1].uid, "b"); t.eq(vm.cards[1].equipped, true)
		t.eq(vm.cards[2].name, "ghost"); t.eq(vm.cards[2].trait, nil)
		t.eq(vm.cards[3].levelText, "Lv. 3"); t.eq(vm.cards[3].trait.name, "Swift")
		t.eq(vm.cards[3].trait.desc, "Attack cooldown x0.85")
	end)
	t.test("empty inventory message", function()
		t.eq(IV.cards({}, get, traits).message, IV.EMPTY)
	end)
	t.test("detail has exactly Equip/Sell/Lock/View/Feed/Fuse", function()
		local card = IV.cards({ { uid = "a", unitId = "basic", level = 5, trait = "Sharp" } }, get, traits).cards[1]
		local d = IV.detail(card, defs.basic, false)
		t.eq(#d.buttons, 6)
		for i, a in ipairs({ "Equip", "Sell", "Lock", "View", "Feed", "Fuse" }) do t.eq(d.buttons[i].action, a) end
		t.eq(d.buttons[1].text, "Equip"); t.eq(d.levelText, "Lvl 5/80")
		t.eq(d.stats[1].value, "20"); t.eq(d.stats[2].value, "0.5s"); t.eq(d.stats[3].value, "18")
		t.eq(d.traitText, "Sharp"); t.eq(d.trait.desc, "Hits harder.")
		t.eq(d.extra[1].label, "Role")
	end)
	t.test("equipped shows Unequip label; no trait -> blank-safe", function()
		local card = IV.cards({ { uid = "z", unitId = "sniper", level = 1, equipped = true } }, get, traits).cards[1]
		local d = IV.detail(card, defs.sniper, true)
		t.eq(d.buttons[1].text, "Unequip"); t.eq(d.buttons[3].text, "Unlock")
		t.eq(d.traitText, "No trait"); t.eq(d.lockText, "LOCKED")
	end)
	t.test("lock toggle is client state", function()
		local l = IV.newLocks()
		t.eq(l.isLocked("a"), false); t.eq(l.toggle("a"), true); t.eq(l.isLocked("a"), true)
		t.eq(l.toggle("a"), false); t.eq(l.isLocked("b"), false)
	end)
	t.test("selection: select, reselect toggles off, close clears", function()
		local s = IV.newSelection()
		t.eq(s.get(), nil); t.eq(s.select("a"), "a"); t.eq(s.get(), "a")
		t.eq(s.select("b"), "b"); t.eq(s.select("b"), nil); t.eq(s.get(), nil)
		s.select("c"); t.eq(s.close(), true); t.eq(s.get(), nil); t.eq(s.close(), false)
	end)
end
