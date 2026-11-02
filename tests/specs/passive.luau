local roblox = require("@lune/roblox")
local P = require("../../src/shared/Passive")
local US = require("../../src/shared/UnitStats")
local Color3 = roblox.Color3
local function loadUnit(name)
	-- unit defs use Color3; inject it via a sandboxed env
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	local src = fs.readFile("src/shared/Units/" .. name .. ".luau")
	return luau.load(src, { environment = { Color3 = Color3, Vector3 = roblox.Vector3 } })()
end
return function(ctx)
	local t, eq = ctx.test, ctx.eq
	for _, name in ipairs({ "Basic", "Sniper", "Rapid", "Mogumo" }) do
		local u = loadUnit(name)
		t("passive: " .. name .. " formats at every level without problems", function()
			if not P.has(u) then
				return -- no passive: button hidden
			end
			for lv = 1, US.maxLevel(u) do
				local st = US.at(u, lv)
				local nx = lv < US.maxLevel(u) and US.at(u, lv + 1) or nil
				local plain, rich, probs = P.describe(u, st, nx)
				eq(#probs, 0)
				assert(plain and not plain:find("[{}]"), plain)
				assert(rich and not plain:find("<font"), "plain must be plain")
			end
		end)
	end
	t("passive: Mogumo numbers per level + change preview", function()
		local u = loadUnit("Mogumo")
		local p1 = P.describe(u, US.at(u, 1))
		assert(p1:find("Every 4th attack") and p1:find("40 damage") and p1:find("Up to 2 dogs"), p1)
		local p4 = P.describe(u, US.at(u, 4))
		assert(p4:find("Every 3rd attack") and p4:find("140 damage") and p4:find("Up to 4 dogs"), p4)
		local _, rich = P.describe(u, US.at(u, 1), US.at(u, 2))
		assert(rich:find("40 → 60"), rich)
		assert(not rich:find("2 → 2"), rich)
	end)
	t("passive: missing describe / unknown placeholder reported", function()
		local _, _, a = P.describe({ name = "X", passive = { name = "N" } }, {})
		eq(#a, 1)
		local plain, _, b = P.describe({ name = "X", passive = { name = "N", describe = "hi {nope}" } }, { ability = {} })
		eq(plain, "hi ?"); eq(#b, 1)
	end)
	t("passive: function describe + ordinals", function()
		local u = { name = "F", passive = { name = "N", describe = function(s) return "d=" .. s.damage end } }
		local plain, rich = P.describe(u, { damage = 1 }, { damage = 2 })
		eq(plain, "d=1"); assert(rich:find("Next: d=2"))
		eq(P.ordinal(1), "1st"); eq(P.ordinal(12), "12th"); eq(P.ordinal(22), "22nd")
	end)
end
