--!strict
-- PURE player data schema with versioned migrations.
-- To change the schema: bump VERSION, add MIGRATIONS[oldVersion] that upgrades in place,
-- and update DataSchema.default. reconcile() fills any missing fields from defaults.
local DataSchema = {}

DataSchema.VERSION = 5

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = deepCopy(v)
	end
	return o
end
DataSchema.deepCopy = deepCopy

function DataSchema.newUnit(uid: string, unitId: string)
	return { uid = uid, unitId = unitId, level = 1, xp = 0, trait = nil }
end

-- Unit instance (v4): { uid, unitId, level = 1..80, xp = progress INTO level (shared/UnitLevel), trait? }
-- Player: xp = lifetime total; level mirrors PlayerLevel.levelForXp(xp) (kept in sync by PlayerData).

-- genUid: () -> string. starter: list of unit ids.
function DataSchema.default(genUid, starter: { string })
	local d = {
		version = DataSchema.VERSION,
		gems = 0,
		gold = 0,
		level = 1,
		xp = 0,
		rerolls = 0,
		units = {}, -- [uid] = unit instance
		loadout = {}, -- array of uids (max Config.LOADOUT_SIZE)
		stats = { matches = 0, wins = 0, kills = 0, damage = 0, wavesCleared = 0, bestWave = 0 },
		clears = {}, -- ["Map:Mode"] = true (first-clear tracking)
		settings = {}, -- v3: validated by shared/Settings.sanitize (has its own .version)
		items = {}, -- v4: [itemId] = count (shared/Items)
		milestones = {}, -- v4: ["<level>"] = true (shared/Milestones, claimed)
		summonPity = 0, -- v5: rolls since last top-rarity pull (shared/Summon)
		starterChosen = false, -- v5: starter screen done (Summon.claimStarter grants unit + gems)
	}
	for _, id in ipairs(starter) do
		local uid = genUid()
		d.units[uid] = DataSchema.newUnit(uid, id)
		table.insert(d.loadout, uid)
	end
	d.starterChosen = #starter > 0
	return d
end

-- MIGRATIONS[n] upgrades data from version n to n + 1.
DataSchema.MIGRATIONS = {
	-- v1 (prototype): { coins = number, owned = { unitId, ... } }
	[1] = function(d, genUid)
		d.gems = d.coins or d.gems or 0
		d.coins = nil
		d.units = d.units or {}
		d.loadout = d.loadout or {}
		for _, id in ipairs(d.owned or {}) do
			local uid = genUid()
			d.units[uid] = DataSchema.newUnit(uid, id)
			if #d.loadout < 6 then
				table.insert(d.loadout, uid)
			end
		end
		d.owned = nil
	end,
	-- v2 -> v3: player settings blob
	[2] = function(d)
		if type(d.settings) ~= "table" then
			d.settings = {}
		end
	end,
	-- v3 -> v4: unit leveling rework. Old units stored LIFETIME xp at 150 xp/level (cap 50);
	-- now xp is progress into the current level (cap 80). Keep the old level, carry the
	-- remainder (PlayerData then runs UnitLevel.normalize for any overflow). Add items/milestones.
	[3] = function(d)
		for uid, u in pairs(d.units or {}) do
			if type(u) ~= "table" or type(u.unitId) ~= "string" then
				d.units[uid] = nil
				continue
			end
			u.uid = uid
			local oldXp = math.max(tonumber(u.xp) or 0, 0)
			local lv = math.max(math.floor(tonumber(u.level) or 1), math.min(math.floor(oldXp / 150) + 1, 50))
			u.level = math.clamp(lv, 1, 80)
			u.xp = math.max(math.floor(oldXp - (lv - 1) * 150), 0)
			if u.xp > 0 and oldXp < (lv - 1) * 150 then
				u.xp = 0
			end
		end
		if type(d.items) ~= "table" then
			d.items = {}
		end
		if type(d.milestones) ~= "table" then
			d.milestones = {}
		end
	end,
	-- v4 -> v5: summon pity counter + starter flag. Accounts that already own units skip the
	-- starter screen (starterChosen = true); no units are added or removed.
	[4] = function(d)
		d.starterChosen = d.starterChosen == true or (type(d.units) == "table" and next(d.units) ~= nil)
		d.summonPity = math.max(math.floor(tonumber(d.summonPity) or 0), 0)
		d.gold = math.max(math.floor(tonumber(d.gold) or 0), 0)
	end,
}

local function reconcile(d, defaults)
	for k, v in pairs(defaults) do
		if d[k] == nil then
			d[k] = deepCopy(v)
		elseif type(v) == "table" and type(d[k]) == "table" and k == "stats" then
			reconcile(d[k], v)
		end
	end
end

-- Returns migrated data (mutates input). `nil` -> fresh default.
function DataSchema.migrate(d, genUid, starter: { string }, maxLoadout: number?)
	if d == nil then
		return DataSchema.default(genUid, {}) -- new account: no units until the starter pick
	end
	local v = d.version or 1
	while v < DataSchema.VERSION do
		local m = DataSchema.MIGRATIONS[v]
		if m then
			m(d, genUid)
		end
		v += 1
	end
	d.version = DataSchema.VERSION
	local fresh = DataSchema.default(function()
		return "_"
	end, {})
	reconcile(d, fresh)
	-- drop loadout entries pointing at missing units; trim
	local cleaned = {}
	for _, uid in ipairs(d.loadout) do
		if d.units[uid] and #cleaned < (maxLoadout or 6) and not table.find(cleaned, uid) then
			table.insert(cleaned, uid)
		end
	end
	d.loadout = cleaned
	-- never leave a player who already picked a starter with nothing to play
	if next(d.units) == nil and d.starterChosen then
		for _, id in ipairs(starter) do
			local uid = genUid()
			d.units[uid] = DataSchema.newUnit(uid, id)
		end
	end
	if #d.loadout == 0 then
		for uid in pairs(d.units) do
			if #d.loadout < (maxLoadout or 6) then
				table.insert(d.loadout, uid)
			end
		end
	end
	return d
end

return DataSchema
