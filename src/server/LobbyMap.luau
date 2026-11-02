-- Placeholder lobby scenery + feature circles. Built on its own ground (top at Y=0.05) so it
-- works with or without the default Baseplate (whose top is Y=0).
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local LobbyFeatures = require(Shared.LobbyFeatures)
local World = require(script.Parent.World)

local log = Log.new("LobbyMap")
local part, billboard = World.part, World.billboard
local LobbyMap = {}
local GROUND_Y = 0.05

local function building(parent, name, pos, size, wall, roof)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	part({ Name = "Walls", Size = size, Position = pos + Vector3.new(0, size.Y / 2, 0), Color = wall, Material = Enum.Material.SmoothPlastic }, m)
	local rh = size.Y * 0.4
	local half = Vector3.new(size.X, rh, size.Z / 2)
	local top = pos.Y + size.Y + rh / 2
	for i, s in ipairs({ -1, 1 }) do
		local w = Instance.new("WedgePart")
		w.Name = "Roof" .. i
		w.Anchored, w.Size, w.Color, w.Material = true, half, roof, Enum.Material.SmoothPlastic
		w.CFrame = CFrame.new(pos.X, top, pos.Z + s * size.Z / 4) * CFrame.Angles(0, s == 1 and math.pi or 0, 0)
		w.Parent = m
	end
	part({ Name = "Door", Size = Vector3.new(4, 7, 0.4), Position = pos + Vector3.new(0, 3.5, (pos.Z > 0 and -1 or 1) * (size.Z / 2 + 0.1)), Color = Color3.fromRGB(90, 60, 40) }, m)
end

local function tree(parent, pos, h)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood }, parent)
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * (h * 0.9), Position = pos + Vector3.new(0, h + h * 0.25, 0), Color = Color3.fromRGB(60, 150, 70), Material = Enum.Material.Grass, CanCollide = false }, parent)
end

function LobbyMap.build()
	local root = Instance.new("Folder")
	root.Name = "LobbyMap"
	root.Parent = World.lobby or workspace
	part({ Name = "Grass", Size = Vector3.new(200, 1, 200), Position = Vector3.new(0, GROUND_Y - 0.5, 0), Color = Color3.fromRGB(85, 170, 75), Material = Enum.Material.Grass }, root)
	part({ Name = "Plaza", Size = Vector3.new(110, 0.2, 120), Position = Vector3.new(0, GROUND_Y + 0.1, 5), Color = Color3.fromRGB(170, 170, 165), Material = Enum.Material.Slate }, root)
	part({ Name = "PortalPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 22, 22), CFrame = CFrame.new(Config.PORTAL_POS.X, GROUND_Y + 0.3, Config.PORTAL_POS.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 50, 120), Material = Enum.Material.Slate }, root)

	-- border fence
	for _, e in ipairs({ { 0, -99, 200, 1 }, { 0, 99, 200, 1 }, { -99, 0, 1, 200 }, { 99, 0, 1, 200 } }) do
		part({ Name = "Fence", Size = Vector3.new(e[3], 4, e[4]), Position = Vector3.new(e[1], GROUND_Y + 2, e[2]), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks }, root)
	end

	building(root, "Shop", Vector3.new(70, GROUND_Y, -10), Vector3.new(20, 12, 16), Color3.fromRGB(240, 220, 170), Color3.fromRGB(60, 160, 80))
	building(root, "GuildHall", Vector3.new(-70, GROUND_Y, 15), Vector3.new(22, 14, 18), Color3.fromRGB(200, 190, 230), Color3.fromRGB(120, 60, 200))
	building(root, "Tower", Vector3.new(-60, GROUND_Y, -70), Vector3.new(14, 22, 14), Color3.fromRGB(210, 200, 190), Color3.fromRGB(200, 50, 60))
	building(root, "House", Vector3.new(60, GROUND_Y, 70), Vector3.new(16, 10, 14), Color3.fromRGB(250, 235, 210), Color3.fromRGB(200, 110, 40))
	building(root, "Cottage", Vector3.new(-60, GROUND_Y, 75), Vector3.new(14, 9, 12), Color3.fromRGB(230, 240, 250), Color3.fromRGB(60, 120, 200))
	for _, p in ipairs({ { 80, -80 }, { 85, 40 }, { -85, -35 }, { -85, 50 }, { 20, 85 }, { -25, 85 }, { 30, -85 }, { -15, -85 } }) do
		tree(root, Vector3.new(p[1], GROUND_Y, p[2]), 10)
	end

	for _, f in ipairs(LobbyFeatures.list) do
		local c = part({
			Name = "Feature_" .. f.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, LobbyFeatures.RADIUS * 2, LobbyFeatures.RADIUS * 2),
			CFrame = CFrame.new(f.position.X, GROUND_Y + 0.25, f.position.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = f.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, root)
		c:SetAttribute("FeatureId", f.id)
		local l = billboard(c, f.name, Vector2.new(10, 2.5), 5)
		l.TextColor3 = f.color
	end

	local old = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if old then
		log.info("existing SpawnLocation found at", tostring(old.Position), "- disabling it; lobby spawn is code-placed")
		old.Enabled = false
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored, spawn.Size, spawn.Transparency, spawn.CanCollide = true, Vector3.new(6, 0.2, 6), 1, false
	spawn.CFrame = CFrame.lookAt(Vector3.new(Config.LOBBY_SPAWN.X, GROUND_Y + 0.4, Config.LOBBY_SPAWN.Z), Config.PORTAL_POS * Vector3.new(1, 0, 1) + Vector3.new(0, GROUND_Y + 0.4, 0))
	spawn.Neutral, spawn.Duration = true, 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end
	spawn.Parent = root
end

function LobbyMap.init()
	LobbyMap.build() -- circle entry is detected client-side (LobbyUI) and opens the lobby panel
end

return LobbyMap
