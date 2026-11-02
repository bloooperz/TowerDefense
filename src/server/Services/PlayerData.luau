-- Persistent player profiles.
--  * DataStore record: { data = <profile>, lock = { job, time } }  (session lock)
--  * Load: UpdateAsync claims the lock; if another live server holds it, retry with backoff,
--    and steal it on the final attempt (or if older than LOCK_TIMEOUT).
--  * Save: only writes while we still own the lock. Release on leave + BindToClose.
--  * Studio without API access (or any DataStore error at boot) falls back to an in-memory mock.
--  * Schema/migrations live in shared/DataSchema (pure, unit tested).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local DataSchema = require(Shared.DataSchema)
local Rewards = require(Shared.Rewards)

local PlayerData = {}
PlayerData.STORE_NAME = "Profiles_v1"
PlayerData.LOCK_TIMEOUT = 600
PlayerData.AUTOSAVE = 60
PlayerData.LOAD_ATTEMPTS = 5

local profiles = {} -- [player] = data
local changedListeners = {}
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local function genUid()
	return HttpService:GenerateGUID(false)
end

-- Mock store with the same UpdateAsync shape.
local function mockStore()
	local mem = {}
	return {
		UpdateAsync = function(_, key, fn)
			local new = fn(mem[key])
			if new ~= nil then
				mem[key] = new
			end
			return mem[key]
		end,
	}
end

local store
do
	local ok, res = pcall(function()
		local s = game:GetService("DataStoreService"):GetDataStore(PlayerData.STORE_NAME)
		if RunService:IsStudio() then
			s:GetAsync("__probe") -- throws if Studio API access is off
		end
		return s
	end)
	if ok then
		store = res
	else
		warn("[PlayerData] DataStore unavailable, using in-memory mock: " .. tostring(res))
		store = mockStore()
		PlayerData.mock = true
	end
end

local function key(plr)
	return "u_" .. plr.UserId
end

local function replicate(plr, d)
	plr:SetAttribute("Gems", d.gems)
	plr:SetAttribute("Level", Rewards.levelForXp(d.xp))
	plr:SetAttribute("Xp", d.xp)
	local ids = {}
	for _, uid in ipairs(d.loadout) do
		local u = d.units[uid]
		if u then
			table.insert(ids, u.unitId)
		end
	end
	plr:SetAttribute("Loadout", table.concat(ids, ","))
	for _, fn in ipairs(changedListeners) do
		task.spawn(fn, plr, d)
	end
end

local function load(plr)
	for attempt = 1, PlayerData.LOAD_ATTEMPTS do
		local steal = attempt == PlayerData.LOAD_ATTEMPTS
		local result
		local ok, err = pcall(function()
			store:UpdateAsync(key(plr), function(rec)
				rec = rec or {}
				local lock = rec.lock
				local now = os.time()
				if lock and lock.job ~= jobId and now - lock.time < PlayerData.LOCK_TIMEOUT and not steal then
					result = nil
					return nil -- cancel write
				end
				rec.data = DataSchema.migrate(rec.data, genUid, Config.STARTER_LOADOUT, Config.LOADOUT_SIZE)
				rec.lock = { job = jobId, time = now }
				result = rec.data
				return rec
			end)
		end)
		if ok and result then
			return result
		end
		if not ok then
			warn("[PlayerData] load failed: " .. tostring(err))
		end
		task.wait(attempt * 2)
	end
	return nil
end

local function save(plr, release)
	local d = profiles[plr]
	if not d then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(plr), function(rec)
			rec = rec or {}
			if rec.lock and rec.lock.job ~= jobId then
				return nil -- another server took over; don't clobber
			end
			rec.data = d
			rec.lock = (not release) and { job = jobId, time = os.time() } or nil
			return rec
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed: " .. tostring(err))
	end
end

function PlayerData.get(plr)
	return profiles[plr]
end

function PlayerData.onChanged(fn)
	table.insert(changedListeners, fn)
end

-- Unit ids currently in the player's loadout (falls back to starters before load).
function PlayerData.loadoutIds(plr)
	local d = profiles[plr]
	if not d then
		return Config.STARTER_LOADOUT
	end
	local ids = {}
	for _, uid in ipairs(d.loadout) do
		if d.units[uid] then
			table.insert(ids, d.units[uid].unitId)
		end
	end
	return ids
end

-- grant = { gems?, xp?, unitXp?, stats = { key = delta }?, bestWave?, clear? }
function PlayerData.grant(plr, g)
	local d = profiles[plr]
	if not d then
		return
	end
	d.gems += g.gems or 0
	d.xp += g.xp or 0
	if g.unitXp then
		for _, uid in ipairs(d.loadout) do
			local u = d.units[uid]
			if u then
				u.xp += g.unitXp
				u.level = Rewards.unitLevelForXp(u.xp)
			end
		end
	end
	for k, v in pairs(g.stats or {}) do
		d.stats[k] = (d.stats[k] or 0) + v
	end
	if g.bestWave then
		d.stats.bestWave = math.max(d.stats.bestWave, g.bestWave)
	end
	if g.clear then
		d.clears[g.clear] = true
	end
	replicate(plr, d)
end

function PlayerData.init()
	local function added(plr)
		local d = load(plr)
		if not plr.Parent then
			if d then -- left while loading: release the lock we just took
				profiles[plr] = d
				save(plr, true)
				profiles[plr] = nil
			end
			return
		end
		if not d then
			plr:Kick("Couldn't load your data. Please rejoin.")
			return
		end
		profiles[plr] = d
		replicate(plr, d)
	end
	Players.PlayerAdded:Connect(added)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(added, plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		save(plr, true)
		profiles[plr] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for plr in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(plr, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PlayerData.AUTOSAVE)
			for plr in pairs(profiles) do
				task.spawn(save, plr, false)
			end
		end
	end)
end

return PlayerData
