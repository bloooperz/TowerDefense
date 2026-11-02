-- Data-driven lobby feature spots (pure data; no `script`). Positions are ground-level (Y = 0).
-- Stepping on a circle (lobby only) opens lobby panel `panel` via LobbyUI.openPanel -- the same
-- panel table the lobby buttons use. Panels with no button get a "Coming soon" placeholder;
-- a real feature just replaces that panel in LobbyUI. `enabled` is reserved for future gating.
local LobbyFeatures = {}

LobbyFeatures.RADIUS = 6

-- Accent per feature (keyed by panel name). Client Theme.COLORS reuses these so the lobby tile,
-- the map circle and its placeholder panel all share one color.
LobbyFeatures.ACCENTS = {
	Summon = Color3.fromRGB(255, 196, 40), -- gold
	["Traits Reroll"] = Color3.fromRGB(160, 70, 255), -- purple
	["Stats Reroll"] = Color3.fromRGB(40, 220, 255), -- cyan
	Shop = Color3.fromRGB(60, 220, 90), -- green
	Quests = Color3.fromRGB(255, 140, 30), -- orange
	Leaderboards = Color3.fromRGB(190, 215, 255), -- white-blue
	Trade = Color3.fromRGB(255, 110, 200), -- pink
	Evolution = Color3.fromRGB(220, 30, 60), -- crimson
}
local A = LobbyFeatures.ACCENTS

LobbyFeatures.list = {
	{ id = "summon", panel = "Summon", name = "Summon", color = A["Summon"], position = Vector3.new(-40, 0, -10), enabled = false },
	{ id = "traits", panel = "Traits Reroll", name = "Traits Reroll", color = A["Traits Reroll"], position = Vector3.new(-40, 0, 15), enabled = false },
	{ id = "stats", panel = "Stats Reroll", name = "Stats Reroll", color = A["Stats Reroll"], position = Vector3.new(-40, 0, 40), enabled = false },
	{ id = "shop", panel = "Shop", name = "Shop", color = A["Shop"], position = Vector3.new(40, 0, -10), enabled = false },
	{ id = "quests", panel = "Quests", name = "Quests", color = A["Quests"], position = Vector3.new(40, 0, 15), enabled = false },
	{ id = "leaderboards", panel = "Leaderboards", name = "Leaderboards", color = A["Leaderboards"], position = Vector3.new(40, 0, 40), enabled = false },
	{ id = "trading", panel = "Trade", name = "Trading", color = A["Trade"], position = Vector3.new(0, 0, 50), enabled = false },
	{ id = "evolution", panel = "Evolution", name = "Evolution", color = A["Evolution"], position = Vector3.new(-25, 0, -45), enabled = false },
}

-- Which feature (if any) a ground position is standing in (XZ distance).
function LobbyFeatures.at(pos)
	for _, f in ipairs(LobbyFeatures.list) do
		local d = Vector3.new(pos.X - f.position.X, 0, pos.Z - f.position.Z)
		if d.Magnitude <= LobbyFeatures.RADIUS then
			return f
		end
	end
	return nil
end

return LobbyFeatures
