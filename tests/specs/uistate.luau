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
	t.test("upgrade button: affordability from current cash + next cost, painted via setFill", function()
		t.eq(UiState.upgradeButton(100, 60).fill, "GREEN"); t.eq(UiState.upgradeButton(100, 60).enabled, true)
		t.eq(UiState.upgradeButton(59, 60).fill, "GREY"); t.eq(UiState.upgradeButton(59, 60).enabled, false)
		t.eq(UiState.upgradeButton(60, 60).fill, "GREEN"); t.eq(UiState.upgradeButton(nil, 60).fill, "GREY")
		t.eq(UiState.upgradeButton(999, nil).text, "MAX LEVEL"); t.eq(UiState.upgradeButton(999, nil).fill, "GREY")
		-- after an upgrade: cash 40 left, next tier costs 100 -> grey at once
		t.eq(UiState.upgradeButton(40, 100).fill, "GREY")
		local fs = require("@lune/fs")
		local s = fs.readFile("src/client/UnitPanel.luau")
		t.eq(s:find("Shape.get(gui.upgrade).setFill(", 1, true) ~= nil, true)
		t.eq(s:find("gui.upgrade.BackgroundColor3", 1, true), nil) -- no direct writes the tween can clobber
		t.eq(s:find("unitPart.AttributeChanged:Connect(refresh)", 1, true) ~= nil, true) -- level change
		t.eq(s:find("cashValue.Changed:Connect", 1, true) ~= nil, true) -- cash change
	end)
end
