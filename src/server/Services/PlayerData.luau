-- Persistent player profiles.
--  * DataStore record: { data = <profile>, lock = { job, time } }  (session lock)
--  * Load: UpdateAsync claims the lock; if another live server holds it, wait (backoff) until it
--    is released or goes stale (LOCK_TIMEOUT). Never force-steal a live lock: after LOCK_WAIT
--    seconds we kick the player with a clear message instead.
--  * Save: retried with exponential backoff (SAVE_ATTEMPTS, 1s/2s/4s...), incl. leave + BindToClose
--    (bounded by CLOSE_BUDGET). Only writes while we still own the lock; if another server has
--    taken the session (lost lock) we stop saving the stale copy and reload or kick.
--  * Studio without API access (or any DataStore error at boot) falls back to an in-memory mock.
--  * Schema/migrations live in shared/DataSchema (pure, unit tested).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local DataSchema = require(Shared.DataSchema)
local UnitLevel = require(Shared.UnitLevel)
local PlayerLevel = require(Shared.PlayerLevel)
local Items = require(Shared.Items)
local Milestones = require(Shared.Milestones)
local Settings = require(Shared.Settings)
local Keybinds = require(Shared.Keybinds)
local Log = require(Shared.Log)
local log = Log.new("PlayerData")

local PlayerData = {}
PlayerData.STORE_NAME = "Profiles_v1"
PlayerData.LOCK_TIMEOUT = 600
PlayerData.AUTOSAVE = 60
PlayerData.LOAD_ATTEMPTS = 5 -- DataStore *errors* tolerated while loading
PlayerData.LOCK_WAIT = 90 -- seconds to wait for another server's live lock before kicking
PlayerData.SAVE_ATTEMPTS = 4
PlayerData.SAVE_BACKOFF = 1 -- 1s, 2s, 4s between save attempts
PlayerData.CLOSE_BUDGET = 25 -- BindToClose gives ~30s; keep margin
PlayerData.LOCKED_KICK = "Your data is still open on another server. Please wait a minute and rejoin."
PlayerData.LOST_KICK = "Your session was opened on another server. Please rejoin to load your latest data."
PlayerData._sleep = function(s) -- overridable in tests
	task.wait(s)
end
PlayerData._clock = os.clock

local profiles = {} -- [player] = data
local changedListeners = {}
local levelListeners = {}

-- Fires (plr, newLevel, oldLevel) whenever a player's level goes up. Also mirrored as the
-- "Level" attribute and the ServerStorage "PlayerLevelChanged" BindableEvent (server-only).
local levelEvent = Instance.new("BindableEvent")
levelEvent.Name = "PlayerLevelChanged"
PlayerData.PlayerLevelChanged = levelEvent.Event
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

-- Stale-sync guard: every PlayerLevel function load/replicate needs must exist, else the local
-- copy of src/shared/PlayerLevel.luau is out of date (would surface as "attempt to call a nil value").
for _, fn in ipairs({ "levelForXp", "check", "progress" }) do
	if type((PlayerLevel :: any)[fn]) ~= "function" then
		log.error(("PlayerLevel.%s is missing: src/shared/PlayerLevel.luau is STALE (git pull / re-sync Rojo)"):format(fn))
	end
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
		log.warn("DataStore unavailable, using in-memory mock (progress resets on stop):", res)
		store = mockStore()
		PlayerData.mock = true
	end
end

local function key(plr)
	return "u_" .. plr.UserId
end

local function replicate(plr, d)
	plr:SetAttribute("Gems", d.gems)
	d.level = PlayerLevel.levelForXp(d.xp)
	plr:SetAttribute("Level", d.level)
	plr:SetAttribute("Xp", d.xp)
	-- unit inventory + items + milestones for the lobby Units/Milestones panels (JSON, read-only)
	local inv = {}
	for uid, u in pairs(d.units) do
		table.insert(inv, { uid = uid, unitId = u.unitId, level = u.level or 1, xp = u.xp or 0, trait = u.trait, equipped = table.find(d.loadout, uid) ~= nil })
	end
	plr:SetAttribute("Inventory", HttpService:JSONEncode(inv))
	plr:SetAttribute("Items", HttpService:JSONEncode(d.items or {}))
	local claimed = {}
	for k in pairs(d.milestones or {}) do
		table.insert(claimed, tonumber(k))
	end
	plr:SetAttribute("Milestones", HttpService:JSONEncode(claimed))
	local ids, levels = {}, {}
	for _, uid in ipairs(d.loadout) do
		local u = d.units[uid]
		if u then
			table.insert(ids, u.unitId)
			table.insert(levels, tostring(u.level or 1))
		end
	end
	plr:SetAttribute("Loadout", table.concat(ids, ","))
	plr:SetAttribute("LoadoutLevels", table.concat(levels, ",")) -- parallel to Loadout
	plr:SetAttribute("Gold", d.gold or 0) -- placeholder until gold/rerolls exist in DataSchema
	plr:SetAttribute("Rerolls", d.rerolls or 0)
	local st = Settings.sanitize(d.settings, Keybinds)
	d.settings = st
	plr:SetAttribute("Settings", HttpService:JSONEncode(st)) -- client applies on load / change
	for _, fn in ipairs(changedListeners) do
		task.spawn(Log.try, "PlayerData", "onChanged", fn, plr, d)
	end
end

-- Is `lock` held by a different, live server?
local function lockedByOther(lock, now)
	return lock ~= nil and lock.job ~= jobId and now - (lock.time or 0) < PlayerData.LOCK_TIMEOUT
end

-- Load + claim the session lock. Never steals a live lock.
-- Returns data, or nil + "locked" | "error". `maxWait` (seconds) caps waiting on a lock (default LOCK_WAIT).
local function load(plr, maxWait)
	maxWait = maxWait or PlayerData.LOCK_WAIT
	local started = PlayerData._clock()
	local errors, attempt = 0, 0
	while true do
		attempt += 1
		local result, held
		local ok, err = pcall(function()
			store:UpdateAsync(key(plr), function(rec)
				rec = rec or {}
				local now = os.time()
				if lockedByOther(rec.lock, now) then
					result, held = nil, rec.lock
					return nil -- cancel write; wait for release/stale
				end
				if rec.lock and rec.lock.job ~= jobId then
					log.warn("taking STALE lock for", plr.Name, "from", rec.lock.job, "age", now - (rec.lock.time or 0))
				end
				held = nil
				rec.data = DataSchema.migrate(rec.data, genUid, Config.STARTER_LOADOUT, Config.LOADOUT_SIZE)
				for _, u in pairs(rec.data.units) do
					UnitLevel.normalize(u) -- v4 migration may leave overflow; also repairs bad values
				end
				rec.data.level = PlayerLevel.levelForXp(rec.data.xp)
				rec.lock = { job = jobId, time = now }
				result = rec.data
				return rec
			end)
		end)
		if ok and result then
			return result
		end
		local reason
		if not ok then
			errors += 1
			log.error("load failed for", plr.Name, "attempt", attempt, err)
			if errors >= PlayerData.LOAD_ATTEMPTS then
				return nil, "error"
			end
			reason = "error"
		else
			reason = "locked"
			log.warn("profile for", plr.Name, "locked by another server", held and held.job, "; waiting (attempt", attempt .. ")")
		end
		local delay = math.min(attempt * 2, 10)
		if reason == "locked" and PlayerData._clock() - started + delay > maxWait then
			log.warn("giving up on", plr.Name, ": still locked by another server after", math.floor(PlayerData._clock() - started), "s (not stealing)")
			return nil, "locked"
		end
		if not plr.Parent then
			return nil, "left"
		end
		PlayerData._sleep(delay)
	end
end

-- One UpdateAsync write. Returns "ok" | "lost" (another server owns the session) or errors.
local function writeOnce(plr, d, release)
	local status = "ok"
	store:UpdateAsync(key(plr), function(rec)
		rec = rec or {}
		-- We always hold a lock after load; a missing or foreign lock means another server
		-- took (and maybe released) the session, so our copy is stale. Don't clobber.
		if rec.lock == nil or rec.lock.job ~= jobId then
			status = "lost"
			return nil
		end
		status = "ok"
		rec.data = d
		rec.lock = (not release) and { job = jobId, time = os.time() } or nil
		return rec
	end)
	return status
end

-- Save with exponential backoff. `deadline` (os.clock-style, via _clock) bounds retries (BindToClose).
-- Returns "ok" | "lost" | "failed" | nil (no profile).
local function save(plr, release, deadline)
	local d = profiles[plr]
	if not d then
		return nil
	end
	for attempt = 1, PlayerData.SAVE_ATTEMPTS do
		local ok, res = pcall(writeOnce, plr, d, release)
		if ok then
			if res == "lost" then
				log.warn("save for", plr.Name, "skipped: session lock is held by another server (lost lock); not writing stale data")
			elseif attempt > 1 then
				log.info("save for", plr.Name, "succeeded on attempt", attempt)
			end
			return res
		end
		local delay = PlayerData.SAVE_BACKOFF * 2 ^ (attempt - 1)
		log.warn("save failed for", plr.Name, "attempt", attempt .. "/" .. PlayerData.SAVE_ATTEMPTS, res)
		if attempt == PlayerData.SAVE_ATTEMPTS then
			break
		end
		if deadline and PlayerData._clock() + delay > deadline then
			log.warn("save for", plr.Name, ": out of shutdown time budget, no more retries")
			break
		end
		PlayerData._sleep(delay)
	end
	log.error("save FAILED for", plr.Name, "after retries; progress since last save may be lost")
	return "failed"
end

-- Another server owns the session: drop our stale copy, then reload fresh data if the lock is
-- free/stale right now, else kick so the player rejoins onto fresh data.
local function onLostLock(plr)
	if not profiles[plr] then
		return
	end
	profiles[plr] = nil -- stop autosaving the stale copy immediately
	log.warn("lost session lock for", plr.Name, "; dropping stale copy and reloading")
	if not plr.Parent then
		return
	end
	local fresh = load(plr, 0) -- single attempt, never steals
	if fresh and plr.Parent then
		profiles[plr] = fresh
		replicate(plr, fresh)
		log.info("reloaded fresh data for", plr.Name, "after lost lock")
	else
		log.warn("could not safely reacquire", plr.Name, "; kicking to rejoin")
		plr:Kick(PlayerData.LOST_KICK)
	end
end

function PlayerData.get(plr)
	return profiles[plr]
end

-- Validate + store a settings JSON blob from the client. Returns an error string on failure.
function PlayerData.saveSettings(plr, json)
	local d = profiles[plr]
	if not d then
		return "Your data hasn't loaded yet"
	end
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(raw) ~= "table" then
		log.warn(plr.Name, "sent undecodable settings:", raw)
		return "Settings save failed (bad data)"
	end
	local clean, problems = Settings.sanitize(raw, Keybinds)
	if #problems > 0 then
		log.warn(plr.Name, "settings problems:", table.concat(problems, "; "))
	end
	d.settings = clean
	replicate(plr, d)
	if #problems > 0 then
		return ("Some settings were invalid and reset (%s)"):format(problems[1]):sub(1, 64)
	end
	return nil
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

-- Account level of the strongest owned copy of `unitId` in the loadout (1 before load).
function PlayerData.unitLevelFor(plr, unitId)
	local d = profiles[plr]
	local best = 1
	if d then
		for _, uid in ipairs(d.loadout) do
			local u = d.units[uid]
			if u and u.unitId == unitId then
				best = math.max(best, UnitLevel.clampLevel(u.level))
			end
		end
	end
	return best
end

-- Add player XP (lifetime) and fire level-up hooks. Returns (newLevel, oldLevel).
local function addPlayerXp(plr, d, xp)
	local old = PlayerLevel.levelForXp(d.xp)
	d.xp = math.max(d.xp + math.floor(xp or 0), 0)
	local new = PlayerLevel.levelForXp(d.xp)
	d.level = new
	if new > old then
		log.info(plr.Name, "player level", old, "->", new)
		levelEvent:Fire(plr, new, old)
		for _, fn in ipairs(levelListeners) do
			task.spawn(Log.try, "PlayerData", "onLevelChanged", fn, plr, new, old)
		end
		if Milestones.pending(d, new) > 0 then
			task.defer(function()
				local Net = require(Shared.Net)
				Net.fire("Notify", plr, ("Level %d! Milestone reward ready (Profile)"):format(new), "info")
			end)
		end
	end
	return new, old
end

function PlayerData.onLevelChanged(fn)
	table.insert(levelListeners, fn)
end

-- Server-side gate check (PlayerLevel.UNLOCKS). nil = allowed, else reason.
function PlayerData.checkUnlock(plr, feature)
	local d = profiles[plr]
	if not d then
		return "Your data hasn't loaded yet"
	end
	return PlayerLevel.check(PlayerLevel.levelForXp(d.xp), feature)
end

-- grant = { gems?, xp?, unitXp?, stats = { key = delta }?, bestWave?, clear? }
-- unitXp goes to every EQUIPPED (loadout) unit. Returns { [uid] = { unitId, gained, levels, level } }.
function PlayerData.grant(plr, g)
	local d = profiles[plr]
	if not d then
		log.warn("grant for", plr.Name, "before data loaded; dropped", g.xp, g.gems)
		return nil
	end
	d.gems += g.gems or 0
	addPlayerXp(plr, d, g.xp or 0)
	local unitReport = {}
	if g.unitXp and g.unitXp > 0 then
		for _, uid in ipairs(d.loadout) do
			local u = d.units[uid]
			if u and not unitReport[uid] then
				local levels, wasted = UnitLevel.addXp(u, g.unitXp)
				unitReport[uid] = { unitId = u.unitId, gained = g.unitXp - wasted, levels = levels, level = u.level }
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
	return unitReport
end

local function loaded(plr)
	local d = profiles[plr]
	if not d then
		return nil, "Your data hasn't loaded yet"
	end
	return d
end

-- XP food: feed `count` of `itemId` to unit `uid`. Returns reason on failure.
function PlayerData.feedUnit(plr, uid, itemId, count)
	local d, why = loaded(plr)
	if not d then
		return why
	end
	local reason, item, xp = Items.checkFeed(d, uid, itemId, count, UnitLevel.MAX)
	if reason then
		return reason
	end
	local u = d.units[uid]
	local before = u.level
	local _, wasted = UnitLevel.addXp(u, xp)
	-- don't burn food that was entirely wasted by the cap: refund whole items worth of waste
	local refund = math.min(math.floor(wasted / item.xp), count - 1)
	Items.add(d, itemId, -(count - refund))
	log.info(plr.Name, "fed", count - refund, itemId, "to", u.unitId, uid, "lv", before, "->", u.level)
	replicate(plr, d)
	return nil, u, before
end

-- Fuse duplicates `feedUids` into `targetUid`. Fed units are removed.
function PlayerData.fuseUnits(plr, targetUid, feedUids)
	local d, why = loaded(plr)
	if not d then
		return why
	end
	local gate = PlayerLevel.check(PlayerLevel.levelForXp(d.xp), "Fuse")
	if gate then
		return gate
	end
	local reason, xp = UnitLevel.checkFuse(d, targetUid, feedUids)
	if reason then
		return reason
	end
	local u = d.units[targetUid]
	local before = u.level
	for _, uid in ipairs(feedUids) do
		d.units[uid] = nil
	end
	UnitLevel.addXp(u, xp)
	log.info(plr.Name, "fused", #feedUids, "x", u.unitId, "into", targetUid, "+" .. xp, "xp lv", before, "->", u.level)
	replicate(plr, d)
	return nil, u, before
end

function PlayerData.claimMilestone(plr, level)
	local d, why = loaded(plr)
	if not d then
		return why
	end
	local reason = Milestones.claim(d, PlayerLevel.levelForXp(d.xp), level, Items.add)
	if reason then
		return reason
	end
	log.info(plr.Name, "claimed milestone", level)
	replicate(plr, d)
	return nil
end

-- Dev/test helpers (callers must be Studio-only).
function PlayerData.devGrantUnitXp(plr, xp)
	return PlayerData.grant(plr, { unitXp = xp })
end
function PlayerData.devGrantPlayerXp(plr, xp)
	PlayerData.grant(plr, { xp = xp })
end
function PlayerData.devGiveItem(plr, itemId, n)
	local d, why = loaded(plr)
	if not d then
		return why
	end
	if not Items.get(itemId) then
		return "Unknown item " .. tostring(itemId)
	end
	Items.add(d, itemId, n)
	replicate(plr, d)
end
function PlayerData.devGiveUnit(plr, unitId)
	local d, why = loaded(plr)
	if not d then
		return why
	end
	local uid = genUid()
	d.units[uid] = DataSchema.newUnit(uid, unitId)
	replicate(plr, d)
end

function PlayerData.init()
	local function added(plr)
		local d, why = load(plr)
		if not plr.Parent then
			if d then -- left while loading: release the lock we just took
				profiles[plr] = d
				save(plr, true)
				profiles[plr] = nil
			end
			return
		end
		if not d then
			log.warn("kicking", plr.Name, "load failed:", why)
			plr:Kick(why == "locked" and PlayerData.LOCKED_KICK or "Couldn't load your data. Please rejoin.")
			return
		end
		profiles[plr] = d
		levelEvent.Parent = game:GetService("ServerStorage")
		replicate(plr, d)
		log.info("loaded", plr.Name, "loadout:", plr:GetAttribute("Loadout"))
	end
	Players.PlayerAdded:Connect(function(plr)
		Log.try("PlayerData", "load " .. plr.Name, added, plr)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(Log.try, "PlayerData", "load " .. plr.Name, added, plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		save(plr, true)
		profiles[plr] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		local deadline = PlayerData._clock() + PlayerData.CLOSE_BUDGET
		for plr in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(plr, true, deadline)
				pending -= 1
			end)
		end
		while pending > 0 and PlayerData._clock() < deadline do
			task.wait()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PlayerData.AUTOSAVE)
			for plr in pairs(profiles) do
				task.spawn(function()
					if save(plr, false) == "lost" then
						onLostLock(plr)
					end
				end)
			end
		end
	end)
end

-- Test hooks (lune specs): internal functions + store injection. Not used by game code.
PlayerData._test = {
	load = function(...)
		return load(...)
	end,
	save = function(...)
		return save(...)
	end,
	onLostLock = function(...)
		return onLostLock(...)
	end,
	profiles = profiles,
	jobId = jobId,
	setStore = function(s)
		store = s
	end,
}

return PlayerData
