--!strict
-- PURE player data schema with versioned migrations.
-- To change the schema: bump VERSION, add MIGRATIONS[oldVersion] that upgrades in place,
-- and update DataSchema.default. reconcile() fills any missing fields from defaults.
local DataSchema = {}

DataSchema.VERSION = 3

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
	}
	for _, id in ipairs(starter) do
		local uid = genUid()
		d.units[uid] = DataSchema.newUnit(uid, id)
		table.insert(d.loadout, uid)
	end
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

-- Returns migrated data (mutates input). `nil` → fresh default.
function DataSchema.migrate(d, genUid, starter: { string }, maxLoadout: number?)
	if d == nil then
		return DataSchema.default(genUid, starter)
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
		if d.units[uid] and #cleaned < (maxLoadout or 6) then
			table.insert(cleaned, uid)
		end
	end
	d.loadout = cleaned
	-- never leave a player with nothing to play
	if next(d.units) == nil then
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
