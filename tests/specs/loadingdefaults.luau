local LV = require("../../src/shared/LoadoutView")
local PL = require("../../src/shared/PlayerLevel")
local fs = require("@lune/fs")
local STARTER = { "Basic", "Sniper", "Rapid", "Mogumo" }

return function(t)
	t.test("cards before Loadout replicates: starter units, Lv 1, loading", function()
		local s = LV.slots(nil, nil, STARTER, 6)
		t.eq(#s, 6)
		for i = 1, 4 do
			t.eq(s[i].id, STARTER[i]); t.eq(s[i].level, 1); t.eq(s[i].loading, true)
		end
		t.eq(s[5].id, nil); t.eq(s[6].id, nil) -- empty slots stay "+"
	end)
	t.test("cards after data: real ids + levels, missing/garbage levels -> 1", function()
		local s = LV.slots("Sniper,Basic", "12,x", STARTER, 6)
		t.eq(s[1].id, "Sniper"); t.eq(s[1].level, 12); t.eq(s[1].loading, false)
		t.eq(s[2].level, 1); t.eq(s[3].id, nil)
		local s2 = LV.slots("Basic", nil, STARTER, 6) -- levels not arrived yet
		t.eq(s2[1].level, 1); t.eq(s2[1].loading, false)
		t.eq(LV.slots("", "", STARTER, 6)[1].id, nil) -- empty loadout is real data, not loading
	end)
	t.test("level bar defaults to Level 1 [0/N] with empty fill", function()
		local text, frac = LV.levelBar(nil, PL.progress)
		t.eq(text, "Level 1 [0/100]"); t.eq(frac, 0)
		local t2, f2 = LV.levelBar(450, PL.progress)
		t.eq(t2, "Level 3 [50/500]"); t.near(f2, 0.1)
		local t3, f3 = LV.levelBar(1e12, PL.progress)
		t.eq(t3, ("Level %d [MAX]"):format(PL.MAX)); t.eq(f3, 1)
	end)
	t.test("PlayerLevel exposes the functions client/server call", function()
		for _, fn in ipairs({ "progress", "levelForXp", "xpForLevel", "check", "isUnlocked" }) do
			t.eq(type(PL[fn]), "function")
		end
	end)
	t.test("client UI factories default Text to empty (no Roblox 'Label')", function()
		for _, p in ipairs({ "src/client/UI/Theme.luau", "src/client/Style.luau", "src/client/UI/Shape.luau", "src/client/UnitPanel.luau" }) do
			assert(fs.readFile(p):find('o.Text = ""', 1, true), p .. " factory missing Text default")
		end
		-- raw Instance.new text objects must set Text right away
		for _, p in ipairs({ "src/client/Hotbar.luau", "src/client/Placement.luau", "src/client/Settings/ClientSettings.luau" }) do
			local src = fs.readFile(p)
			for var, rest in src:gmatch('local (%w+) = Instance%.new%("Text%a+"%)\n([^\n]*\n[^\n]*\n[^\n]*\n[^\n]*)') do
				assert(rest:find(var .. ".Text", 1, true), p .. ": " .. var .. " has no starting Text")
			end
		end
	end)
end
