-- Run with: lune run tests/run
local roblox = require("@lune/roblox")
local V = roblox.Vector3

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end
local function near(a, b, msg)
	if math.abs(a - b) > 1e-6 then
		error((msg or "") .. " expected ~" .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

local ctx = { test = test, eq = eq, near = near, V = V }
for _, spec in ipairs({ "path", "damage", "status", "waves", "rewards", "dataschema", "unitstats", "placement", "enemylife" }) do
	print(spec)
	require("./specs/" .. spec)(ctx)
end
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
