-- PlayerData session-lock + save-retry logic, loaded with stubbed Roblox services + a mock DataStore.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SHARED = { "Config", "DataSchema", "UnitLevel", "PlayerLevel", "Items", "Milestones", "Settings", "Keybinds", "Log", "Net", "Summon", "Units" }

local function newEnv()
	local warns = {}
	local shared = {}
	for _, n in ipairs(SHARED) do
		shared[n] = { __mod = n }
	end
	local cache = {}
	local function req(m)
		if type(m) == "table" and m.__mod == "Config" then
			return { STARTER_LOADOUT = { "Basic", "Sniper", "Rapid", "Mogumo" }, LOADOUT_SIZE = 6 }
		elseif type(m) == "table" and m.__mod == "Units" then
			return { list = {}, get = function() return nil end }
		elseif type(m) == "table" and m.__mod then
			cache[m.__mod] = cache[m.__mod] or require("../../src/shared/" .. m.__mod)
			return cache[m.__mod]
		end
		error("unexpected require")
	end
	local signal = { Connect = function() end }
	local services = {
		Players = { PlayerAdded = signal, PlayerRemoving = signal, GetPlayers = function() return {} end },
		RunService = { IsStudio = function() return true end },
		HttpService = {
			GenerateGUID = function() return tostring(math.random(1, 1e9)) end,
			JSONEncode = function() return "[]" end,
		},
		ReplicatedStorage = { Shared = shared },
		DataStoreService = { GetDataStore = function() error("no API access") end },
		ServerStorage = {},
	}
	local game = { JobId = "", GetService = function(_, n) return services[n] end, BindToClose = function() end }
	local env = setmetatable({
		game = game,
		require = req,
		warn = function(...) table.insert(warns, table.concat({ ... }, " ")) end,
		print = function() end,
		Instance = { new = function() return { Event = signal, Fire = function() end } end },
		Random = { new = function() return { NextNumber = function() return math.random() end } end },
	}, { __index = _G })
	local PD = luau.load(fs.readFile("src/server/Services/PlayerData.luau"), { debugName = "PlayerData", environment = env, injectGlobals = true })()
	local slept = {}
	PD._sleep = function(s) table.insert(slept, s); PD.__now += s end
	PD.__now = 0
	PD._clock = function() return PD.__now end
	return PD, warns, slept
end

-- Fake DataStore: `failN` UpdateAsync calls throw first.
local function fakeStore(failN)
	local mem, calls = {}, 0
	return {
		mem = mem,
		calls = function() return calls end,
		UpdateAsync = function(_, k, fn)
			calls += 1
			if failN > 0 then
				failN -= 1
				error("502: DataStore request failed")
			end
			local new = fn(mem[k])
			if new ~= nil then mem[k] = new end
			return mem[k]
		end,
	}
end

local function fakePlayer()
	return { Name = "P", UserId = 1, Parent = true, kicked = nil, Kick = function(self, m) self.kicked = m end, SetAttribute = function() end, GetAttribute = function() end }
end

return function(t)
	t.test("save retries with exponential backoff then succeeds", function()
		local PD, warns, slept = newEnv()
		local st = fakeStore(0)
		PD._test.setStore(st)
		local plr = fakePlayer()
		local d = PD._test.load(plr)
		assert(d, "loaded")
		PD._test.profiles[plr] = d
		st.mem["u_1"] = st.mem["u_1"] -- keep
		local st2 = fakeStore(2); st2.mem["u_1"] = st.mem["u_1"]
		PD._test.setStore(st2)
		t.eq(PD._test.save(plr, true), "ok")
		t.eq(#slept, 2); t.eq(slept[1], 1); t.eq(slept[2], 2)
		t.eq(st2.mem["u_1"].lock, nil, "released")
	end)
	t.test("save gives up after SAVE_ATTEMPTS and logs", function()
		local PD, warns = newEnv()
		local st = fakeStore(0); PD._test.setStore(st)
		local plr = fakePlayer()
		PD._test.profiles[plr] = PD._test.load(plr)
		local bad = fakeStore(99); PD._test.setStore(bad)
		t.eq(PD._test.save(plr, false), "failed")
		t.eq(bad.calls(), PD.SAVE_ATTEMPTS)
	end)
	t.test("save respects shutdown deadline", function()
		local PD = newEnv()
		local st = fakeStore(0); PD._test.setStore(st)
		local plr = fakePlayer()
		PD._test.profiles[plr] = PD._test.load(plr)
		local bad = fakeStore(99); PD._test.setStore(bad)
		t.eq(PD._test.save(plr, true, PD._clock() + 2.5), "failed")
		t.eq(bad.calls(), 2, "1s fits, 2s would exceed budget")
	end)
	t.test("load never steals a live lock; gives up as 'locked'", function()
		local PD = newEnv()
		local st = fakeStore(0); PD._test.setStore(st)
		st.mem["u_1"] = { data = nil, lock = { job = "other", time = os.time() } }
		local plr = fakePlayer()
		local d, why = PD._test.load(plr)
		t.eq(d, nil); t.eq(why, "locked")
		t.eq(st.mem["u_1"].lock.job, "other", "lock untouched")
		assert(PD._clock() <= PD.LOCK_WAIT, "bounded wait")
	end)
	t.test("load takes a stale lock and a released lock", function()
		local PD = newEnv()
		local st = fakeStore(0); PD._test.setStore(st)
		st.mem["u_1"] = { lock = { job = "other", time = os.time() - PD.LOCK_TIMEOUT - 1 } }
		local plr = fakePlayer()
		assert(PD._test.load(plr), "stale lock taken")
		t.eq(st.mem["u_1"].lock.job, PD._test.jobId)
	end)
	t.test("lost lock: save refuses to write stale data, reload or kick", function()
		local PD = newEnv()
		local st = fakeStore(0); PD._test.setStore(st)
		local plr = fakePlayer()
		local d = PD._test.load(plr)
		PD._test.profiles[plr] = d
		d.gems = 999999
		st.mem["u_1"].lock = { job = "other", time = os.time() }
		st.mem["u_1"].data = { marker = true }
		t.eq(PD._test.save(plr, false), "lost")
		t.eq(st.mem["u_1"].data.marker, true, "not clobbered")
		PD._test.onLostLock(plr)
		t.eq(PD._test.profiles[plr], nil); assert(plr.kicked, "kicked while other server holds lock")
		-- other server released -> reload instead of kick
		local plr2 = fakePlayer()
		PD._test.profiles[plr2] = d
		st.mem["u_1"].lock = nil
		t.eq(PD._test.save(plr2, false), "lost", "missing lock = lost")
		PD._test.onLostLock(plr2)
		t.eq(plr2.kicked, nil)
		assert(PD._test.profiles[plr2] and PD._test.profiles[plr2] ~= d, "fresh copy loaded")
		t.eq(st.mem["u_1"].lock.job, PD._test.jobId)
	end)
end
