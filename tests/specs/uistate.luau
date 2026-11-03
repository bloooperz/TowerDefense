local fs = require("@lune/fs")
local UiState = require("../../src/shared/UiState")
return function(t)
	t.test("toggle on is green, off is neutral", function()
		t.eq(UiState.toggle(true).fill, "GREEN"); t.eq(UiState.toggle(true).text, "ON")
		t.eq(UiState.toggle(false).fill, "NEUTRAL"); t.eq(UiState.toggle(nil).text, "OFF")
	end)
	t.test("click flips and visual follows", function()
		t.eq(UiState.flip(true), false); t.eq(UiState.flip(false), true)
		t.eq(UiState.toggle(UiState.flip(false)).fill, "GREEN")
	end)
	t.test("map card selected is the same orange for every registered map", function()
		local n = 0
		for _, f in ipairs(fs.readDir("src/shared/Maps")) do
			if f ~= "init.luau" then
				n += 1
				local v = UiState.pickCard(true)
				t.eq(v.fill, "ORANGE"); t.eq(v.edge, "ORANGE_EDGE"); t.eq(v.thickness, 3)
			end
		end
		t.eq(n >= 2, true)
		local u = UiState.pickCard(false)
		t.eq(u.fill ~= "ORANGE" and u.edge ~= "ORANGE_EDGE", true)
	end)
	t.test("toggles and map picker paint through Shape.setFill", function()
		local s = fs.readFile("src/client/Settings/SettingsUI.luau")
		t.eq(s:find("paintToggle(b, want)", 1, true) ~= nil, true)
		t.eq(s:find("b.BackgroundColor3 = on and", 1, true), nil)
		local m = fs.readFile("src/client/MapSelect.luau")
		t.eq(m:find("h.setFill(PICK[v.fill])", 1, true) ~= nil, true)
		local sh = fs.readFile("src/client/UI/Shape.luau")
		t.eq(sh:find("tween:Cancel()", 1, true) ~= nil, true)
	end)
end
