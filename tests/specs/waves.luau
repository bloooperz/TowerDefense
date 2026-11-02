local W = require("../../src/shared/Waves")
return function(t)
	t.test("wave 1 is basics only", function()
		local w = W.generate(1)
		t.eq(#w.groups, 1); t.eq(w.groups[1].enemy, "Basic"); t.eq(w.total, 5)
	end)
	t.test("boss on wave 10 and on story final", function()
		t.eq(W.generate(10).boss, true)
		t.eq(W.generate(7, { maxWaves = 7 }).boss, true)
		t.eq(W.generate(7).boss, false)
	end)
	t.test("hp scales", function()
		t.eq(W.generate(5).hpMult > W.generate(1).hpMult, true)
	end)
	t.test("total matches groups", function()
		for wave = 1, 30 do
			local w = W.generate(wave)
			local n = 0
			for _, g in ipairs(w.groups) do n += g.count end
			t.eq(w.total, n)
		end
	end)
end
