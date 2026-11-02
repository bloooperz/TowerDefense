-- Every Net.on/send/fire/fireAll/listen name in src exists in shared/Net.DEFS with the right direction,
-- so client and server always agree on remote names (one shared definition table).
local fs = require("@lune/fs")
local function walk(dir, out)
	for _, n in ipairs(fs.readDir(dir)) do
		local p = dir .. "/" .. n
		if fs.isDir(p) then walk(p, out) elseif n:match("%.luau$") then table.insert(out, p) end
	end
	return out
end
return function(t)
	t.test("Net remote names/directions consistent across client + server", function()
		local src = fs.readFile("src/shared/Net.luau")
		local defs = {}
		for line in src:gmatch("[^\n]+") do
			local name, dir = line:match('^%s*(%a+) = {%s*dir = "(%w+)"')
			if name then defs[name] = dir end
		end
		t.eq(defs.ClaimStarter, "c2s"); t.eq(defs.ClaimStarterResult, "s2c")
		local want = { on = "c2s", send = "c2s", fire = "s2c", fireAll = "s2c", listen = "s2c" }
		local n = 0
		for _, p in ipairs(walk("src", {})) do
			for fn, name in fs.readFile(p):gmatch('Net%.(%a+)%("(%a+)"') do
				if want[fn] then
					n += 1
					assert(defs[name], p .. ": Net." .. fn .. '("' .. name .. '") not in Net.DEFS')
					t.eq(defs[name], want[fn], p .. " " .. fn .. " " .. name)
				end
			end
		end
		assert(n > 20, "scanned calls")
		t.eq(fs.readFile("src/client/Lobby/StarterUI.luau"):find('Net.listen("ClaimStarterResult"', 1, true) ~= nil, true)
		t.eq(fs.readFile("src/server/Match.luau"):find('Net.fire("ClaimStarterResult"', 1, true) ~= nil, true)
	end)
end
