-- Data-driven lobby feature spots (pure data; no `script`). Positions are ground-level (Y = 0).
-- enabled=false -> stepping on it toasts "Coming soon: <name>". When a feature is real, set
-- enabled=true and register a server handler: LobbyMap.handlers[id] = function(plr) ... end
local LobbyFeatures = {}

LobbyFeatures.RADIUS = 6

LobbyFeatures.list = {
	{ id = "summon", name = "Summon", color = Color3.fromRGB(255, 200, 40), position = Vector3.new(-40, 0, -10), enabled = false },
	{ id = "traits", name = "Traits Reroll", color = Color3.fromRGB(160, 70, 255), position = Vector3.new(-40, 0, 15), enabled = false },
	{ id = "stats", name = "Stats Reroll", color = Color3.fromRGB(40, 220, 255), position = Vector3.new(-40, 0, 40), enabled = false },
	{ id = "shop", name = "Shop", color = Color3.fromRGB(60, 220, 90), position = Vector3.new(40, 0, -10), enabled = false },
	{ id = "quests", name = "Quests", color = Color3.fromRGB(255, 140, 30), position = Vector3.new(40, 0, 15), enabled = false },
	{ id = "leaderboards", name = "Leaderboards", color = Color3.fromRGB(190, 215, 255), position = Vector3.new(40, 0, 40), enabled = false },
	{ id = "trading", name = "Trading", color = Color3.fromRGB(255, 110, 200), position = Vector3.new(0, 0, 50), enabled = false },
	{ id = "evolution", name = "Evolution", color = Color3.fromRGB(220, 40, 60), position = Vector3.new(-25, 0, -45), enabled = false },
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
