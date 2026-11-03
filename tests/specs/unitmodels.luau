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
		t.eq(names.Rapid.BarrelL and names.Rapid.BarrelR, true); t.eq(names.Sniper.Scope, true)
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
	t.test("Basic placeholder: stocky dark-haired summoner (mix, colors, proportions, blade)", function()
		local b = UM.PLACEHOLDERS.Basic
		t.eq(#b.parts >= 40 and #b.parts <= 70, true)
		local pal = b.palette
		t.eq(pal.skin[1] >= 220 and pal.skin[2] >= 200, true)
		t.eq(table.concat(pal.hair, ","), "18,18,22"); t.eq(table.concat(pal.jacket, ","), "38,40,52")
		t.eq(table.concat(pal.pants, ","), "28,28,34"); t.eq(table.concat(pal.trim, ","), "70,70,80")
		t.eq(table.concat(pal.blade, ","), "110,116,126"); t.eq(pal.fuller[1] < pal.blade[1], true)
		local by, kinds = {}, { block = 0, wedge = 0, cylinder = 0 }
		local hx0, hx1, hy0, hy1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(b.parts) do
			by[p.name] = p
			kinds[p.shape or "block"] += 1
			if p.color == "hair" then
				hx0, hx1 = math.min(hx0, p.pos[1]), math.max(hx1, p.pos[1])
				hy0, hy1 = math.min(hy0, p.pos[2]), math.max(hy1, p.pos[2])
				if p.name:find("Spike") or p.name:find("Fringe") then t.eq(p.shape, "wedge"); t.eq(p.size[2] <= 0.45, true) end
			end
		end
		t.eq(kinds.block >= 20 and kinds.wedge >= 10 and kinds.cylinder >= 5, true)
		t.eq(hx1 - hx0 > hy1 - hy0, true) -- hair wider than tall
		t.eq(by.SpikeOutL1 ~= nil and by.SpikeOutR2 ~= nil, true)
		local function span(name) return math.abs(by[name].pos[1]) + by[name].size[1] / 2 end
		local ratio = 2 * span("LeftShoulder") / by.Belt.size[1]
		t.eq(ratio >= 1.25 and ratio <= 1.4, true) -- shoulders ~1.3x belt
		t.eq(by.Head.size[1] >= 1.3 and by.Head.size[1] <= 1.4, true) -- ~1.1-1.15x of 1.2
		t.eq(by.CollarFrontL.pos[2] + by.CollarFrontL.size[2] / 2 < by.Head.pos[2] - by.Head.size[2] / 4, true) -- below mid-face
		for _, n in ipairs({ "LapelL", "LapelR", "LeftPantCuff", "RightPantCuff" }) do t.eq(by[n].shape, "wedge") end
		for _, n in ipairs({ "Pommel", "Buckle", "Wrap1", "Wrap2" }) do t.eq(by[n].shape, "cylinder") end
		t.eq(by.LeftCuff.color, "trim"); t.eq(by.Hem.color, "trim"); t.eq(by.CollarEdge.color, "trim")
		t.eq(by.Head.color, "skin"); t.eq(by.LeftHand.color, "skin"); t.eq(by.Torso.color, "jacket")
		t.eq(by.Blade1.size[1], 0.2); t.eq(by.Guard.size[1] >= 0.8, true)
		t.eq(by.Blade1.rot[1] ~= by.Blade3.rot[1], true); t.eq(by.Blade1.rot[2] ~= 0, true) -- curved, out to the side
		t.eq(by.Rifle, nil); t.eq(by.Helmet, nil)
		local src = fs.readFile("src/shared/UnitModels.luau")
		t.eq(src:find("rbxassetid", 1, true), nil); t.eq(src:find("MeshPart", 1, true), nil)
		t.eq(src:find("Enum.PartType.Cylinder", 1, true) ~= nil, true)
	end)
end
