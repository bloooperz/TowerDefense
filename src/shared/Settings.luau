-- PURE settings schema + validation. Stored in PlayerData as d.settings (DataSchema v3).
-- Server validates every save (Settings.sanitize); unknown fields are dropped, bad values reset.
local Settings = {}
Settings.VERSION = 1

Settings.DEFAULTS = {
	version = Settings.VERSION,
	lowGraphics = false,
	damageNumbers = true,
	hideOthers = false,
	music = 0.5, -- 0..1
	sfx = 0.7, -- 0..1
	keybinds = {}, -- overrides only: { [actionId] = KeyCode name }
}

local BOOLS = { "lowGraphics", "damageNumbers", "hideOthers" }
local VOLUMES = { "music", "sfx" }

-- Migrations for the settings blob itself: MIGRATIONS[n] upgrades n -> n+1.
Settings.MIGRATIONS = {}

-- Returns a full, valid settings table + list of problems (for logging/toasts).
-- Keybinds module is passed in (pure modules don't use `script`, so no cross-require).
function Settings.sanitize(raw, Keybinds)
	local out, problems = table.clone(Settings.DEFAULTS), {}
	out.keybinds = {}
	if type(raw) ~= "table" then
		if raw ~= nil then
			table.insert(problems, "settings not a table")
		end
		return out, problems
	end
	local v = type(raw.version) == "number" and raw.version or 1
	while v < Settings.VERSION do
		local m = Settings.MIGRATIONS[v]
		if m then
			m(raw)
		end
		v += 1
	end
	for _, k in ipairs(BOOLS) do
		if raw[k] ~= nil then
			if type(raw[k]) == "boolean" then
				out[k] = raw[k]
			else
				table.insert(problems, k .. " must be true/false")
			end
		end
	end
	for _, k in ipairs(VOLUMES) do
		local n = raw[k]
		if n ~= nil then
			if type(n) == "number" and n == n then
				out[k] = math.clamp(n, 0, 1)
			else
				table.insert(problems, k .. " must be a number")
			end
		end
	end
	local kb, kp = Keybinds.sanitize(raw.keybinds or {})
	out.keybinds = kb
	for _, p in ipairs(kp) do
		table.insert(problems, p)
	end
	return out, problems
end

return Settings
