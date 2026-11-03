local fs = require("@lune/fs")
local UM = require("../../src/shared/UnitModels")
return function(t)
	t.test("source: folder model wins, then placeholder, then cube fallback", function()
		t.eq(UM.source("Basic", true), "folder")
		t.eq(UM.source("Basic", false), "placeholder")
		t.eq(UM.source("Rapid", nil), "placeholder"); t.eq(UM.source("Sniper", false), "placeholder")
		t.eq(UM.source("Mogumo", false), "cube"); t.eq(UM.source("Mogumo", true), "folder")
		t.eq(UM.source(nil, false), "cube")
	end)
	t.test("scaleFor normalizes largest extent to target", function()
		t.eq(UM.scaleFor({ 2, 5, 1 }, 4.5), 0.9)
		t.eq(UM.scaleFor({ 10, 2, 2 }, 5), 0.5)
		t.eq(UM.scaleFor({ 0, 0, 0 }, 4), 1); t.eq(UM.scaleFor({ 1, 1, 1 }, 0), 1)
		t.eq(UM.frameDistance(2) > 2, true)
	end)
	t.test("placeholders: distinct, parts only, feet on ground, palette keys resolve", function()
		local names = {}
		for id, spec in pairs(UM.PLACEHOLDERS) do
			local set, minY, primary = {}, math.huge, 0
			for _, p in ipairs(spec.parts) do
				set[p.name] = true
				minY = math.min(minY, p.pos[2] - p.size[2] / 2)
				if type(p.color) == "string" then t.eq(spec.palette[p.color] ~= nil, true) end
				if p.primary then primary += 1 end
			end
			t.eq(minY, 0); t.eq(primary, 1)
			names[id] = set
		end
		t.eq(names.Basic.Rifle, true); t.eq(names.Rapid.BarrelL and names.Rapid.BarrelR, true); t.eq(names.Sniper.Scope, true)
	end)
	t.test("wiring: Towers/Card use the registry; no asset ids; Rojo Assets folder kept", function()
		local tw = fs.readFile("src/server/Towers.luau")
		t.eq(tw:find("UnitModels.kind(u)", 1, true) ~= nil, true)
		t.eq(tw:find("UnitModels.clone(u", 1, true) ~= nil, true)
		t.eq(tw:find('p:SetAttribute("UnitId", t.id)', 1, true) ~= nil, true) -- hitbox attrs intact
		local card = fs.readFile("src/client/UI/Card.luau")
		t.eq(card:find("UnitModels.clone(u", 1, true) ~= nil, true); t.eq(card:find("UnitModels.frame(cam, model)", 1, true) ~= nil, true)
		local um = fs.readFile("src/shared/UnitModels.luau")
		t.eq(um:find("InsertService", 1, true), nil); t.eq(um:find("rbxassetid", 1, true), nil)
		t.eq(um:find('d:IsA("BaseScript")', 1, true) ~= nil, true) -- scripts stripped
		local pj = fs.readFile("default.project.json")
		t.eq(pj:find('"UnitModels"', 1, true) ~= nil, true); t.eq(pj:find('"$path": "src/shared"', 1, true) ~= nil, true)
		t.eq(pj:find('"$ignoreUnknownInstances": true', 1, true) ~= nil, true)
	end)
end
