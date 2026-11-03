local RL = require("../../src/shared/RateLimit")
local fs = require("@lune/fs")
local function devSkipRate()
	return tonumber(fs.readFile("src/shared/Net.luau"):match("DevSkipWave = {[^\n]-rate = (%d+)"))
end
return function(t)
	t.test("DevSkipWave rate is 15 (own per-remote bucket)", function()
		t.eq(devSkipRate(), 15)
	end)
	t.test("8 clicks/sec for 5 s: never rejected", function()
		local l, rate, rejected = RL.new(), devSkipRate(), 0
		for i = 0, 39 do
			if not l.allow("p:DevSkipWave", rate, i / 8) then rejected += 1 end
		end
		t.eq(rejected, 0)
	end)
	t.test("instant burst of 15 ok, 16th dropped", function()
		local l = RL.new()
		for _ = 1, 15 do t.eq(l.allow("k", 15, 100), true) end
		t.eq(l.allow("k", 15, 100), false)
	end)
	t.test("runaway loop (1000/s for 1 s) capped near 30", function()
		local l, ok = RL.new(), 0
		for i = 0, 999 do
			if l.allow("k", 15, i / 1000) then ok += 1 end
		end
		t.eq(ok <= 31 and ok >= 29, true)
	end)
	t.test("buckets are per key (dev skip does not drain gameplay remotes)", function()
		local l = RL.new()
		for _ = 1, 15 do l.allow("p:DevSkipWave", 15, 0) end
		t.eq(l.allow("p:DevSkipWave", 15, 0), false)
		t.eq(l.allow("p:Vote", 3, 0), true)
		l.forget("p:DevSkipWave"); t.eq(l.allow("p:DevSkipWave", 15, 0), true)
	end)
	t.test("Match skip interrupts spawn gaps and the wave break", function()
		local m = fs.readFile("src/server/Match.luau")
		t.eq(m:find("waitOrSkip(g.delay, skipAt)", 1, true) ~= nil, true)
		t.eq(m:find("waitOrSkip(Config.WAVE_BREAK, Match.dev.skipToken)", 1, true) ~= nil, true)
		t.eq(m:find("task.wait(Config.WAVE_BREAK)", 1, true), nil)
	end)
end
