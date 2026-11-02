-- PURE keybind table + validation (no Enum/`script`, testable in lune). Keys are KeyCode NAMES.
-- Client runtime lives in client/Input.luau; persisted overrides live in Settings.keybinds.
local Keybinds = {}

-- Ordered: what the Controls list shows. Escape is reserved (closes panels / cancels rebinding).
Keybinds.ACTIONS = {
	{ id = "hotbar1", label = "Hotbar slot 1", default = "One" },
	{ id = "hotbar2", label = "Hotbar slot 2", default = "Two" },
	{ id = "hotbar3", label = "Hotbar slot 3", default = "Three" },
	{ id = "hotbar4", label = "Hotbar slot 4", default = "Four" },
	{ id = "hotbar5", label = "Hotbar slot 5", default = "Five" },
	{ id = "hotbar6", label = "Hotbar slot 6", default = "Six" },
	{ id = "cancel", label = "Cancel placement", default = "Q" },
	{ id = "Inventory", label = "Lobby: Inventory", default = "I" },
	{ id = "Units", label = "Lobby: Units", default = "K" },
	{ id = "Trade", label = "Lobby: Trade", default = "T" },
	{ id = "Summon", label = "Lobby: Summon", default = "F" },
	{ id = "Play", label = "Lobby: Play", default = "P" },
	{ id = "Quests", label = "Lobby: Quests", default = "J" },
	{ id = "Battlepass", label = "Lobby: Battlepass", default = "B" },
	{ id = "Profile", label = "Lobby: Profile", default = "U" },
	{ id = "Friends", label = "Lobby: Friends", default = "G" },
	{ id = "settings", label = "Settings", default = "O" },
	{ id = "dev", label = "Dev menu (Studio)", default = "F2" },
}
Keybinds.RESERVED = { Escape = true, Unknown = true }
Keybinds.byId = {}
for _, a in ipairs(Keybinds.ACTIONS) do
	Keybinds.byId[a.id] = a
end

local function validKeyName(k)
	return type(k) == "string" and #k <= 24 and k:match("^%w+$") ~= nil and not Keybinds.RESERVED[k]
end
Keybinds.validKeyName = validKeyName

-- overrides: { [actionId] = keyName } -> full map { [actionId] = keyName }
function Keybinds.resolve(overrides)
	local map = {}
	for _, a in ipairs(Keybinds.ACTIONS) do
		local o = overrides and overrides[a.id]
		map[a.id] = validKeyName(o) and o or a.default
	end
	return map
end

-- Drop unknown actions / bad keys / overrides equal to default; reject duplicates in the resolved map.
-- Returns cleaned overrides, list of problems.
function Keybinds.sanitize(overrides)
	local clean, problems = {}, {}
	if type(overrides) ~= "table" then
		return clean, { "keybinds not a table" }
	end
	for id, k in pairs(overrides) do
		local a = Keybinds.byId[id]
		if not a then
			table.insert(problems, "unknown action " .. tostring(id))
		elseif not validKeyName(k) then
			table.insert(problems, ("bad key for %s: %s"):format(id, tostring(k)))
		elseif k ~= a.default then
			clean[id] = k
		end
	end
	local used = {}
	for _, a in ipairs(Keybinds.ACTIONS) do -- first action (list order) keeps a contested key
		local k = clean[a.id] or a.default
		if used[k] then
			table.insert(problems, ("duplicate key %s (%s vs %s)"):format(k, used[k], a.id))
			clean[a.id] = nil
		else
			used[k] = a.id
		end
	end
	-- a reverted action may now collide with an override; re-check once
	local seen = {}
	for _, a in ipairs(Keybinds.ACTIONS) do
		local k = clean[a.id] or a.default
		if seen[k] then
			clean[seen[k]] = nil
		end
		seen[k] = a.id
	end
	return clean, problems
end

-- Try to bind actionId to keyName. Returns new overrides, or nil + reason (duplicate etc.).
function Keybinds.rebind(overrides, actionId, keyName)
	local a = Keybinds.byId[actionId]
	if not a then
		return nil, "Unknown action " .. tostring(actionId)
	end
	if not validKeyName(keyName) then
		return nil, tostring(keyName) .. " can't be bound"
	end
	local map = Keybinds.resolve(overrides)
	for id, k in pairs(map) do
		if k == keyName and id ~= actionId then
			return nil, ("%s is already bound to %s"):format(keyName, Keybinds.byId[id].label)
		end
	end
	local out = table.clone(overrides or {})
	out[actionId] = keyName ~= a.default and keyName or nil
	return out, nil
end

return Keybinds
