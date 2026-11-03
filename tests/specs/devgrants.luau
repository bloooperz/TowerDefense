local DG = require("../../src/shared/DevGrants")
local S = require("../../src/shared/Summon")
local fs = require("@lune/fs")
return function(t)
	t.test("gems amount matches starter gems", function()
		t.eq(DG.GEMS, S.STARTER_GEMS); t.eq(DG.GEMS, 500)
	end)
	t.test("studio grant goes through grant fn and adds 500 gems", function()
		local d = { gems = 120 }
		local calls = 0
		local why = DG.giveGems(true, true, function(g)
			calls += 1
			d.gems += g.gems or 0 -- same arithmetic as PlayerData.grant
		end)
		t.eq(why, nil); t.eq(calls, 1); t.eq(d.gems, 620)
	end)
	t.test("refused outside Studio / before data loads; no grant", function()
		local called = false
		t.eq(DG.giveGems(false, true, function() called = true end), "Dev menu is Studio-only")
		t.eq(DG.giveGems(true, false, function() called = true end), "Your data hasn't loaded yet")
		t.eq(called, false)
	end)
	t.test("Dev.luau uses the real PlayerData.grant path; remote is studioOnly", function()
		local dev = fs.readFile("src/server/Dev.luau")
		t.eq(dev:find('Net.on%("DevGiveGems", guard%(') ~= nil, true)
		t.eq(dev:find("DevGrants.giveGems%(studio%(%)") ~= nil, true)
		t.eq(dev:find("PlayerData.grant%(plr, g%)") ~= nil, true)
		local net = fs.readFile("src/shared/Net.luau")
		t.eq(net:find("DevGiveGems = { dir = \"c2s\", args = {}, rate = 4, studioOnly = true }", 1, true) ~= nil, true)
	end)
end
