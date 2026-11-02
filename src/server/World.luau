-- Builds the lobby (portal) and the map.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local World = {}

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface = true, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
World.part = part

local function billboard(adornee, text)
	local g = Instance.new("BillboardGui")
	g.Size, g.StudsOffsetWorldSpace, g.AlwaysOnTop = UDim2.fromOffset(250, 60), Vector3.new(0, 6, 0), true
	g.MaxDistance = 300
	g.Parent = adornee
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, true
	l.TextColor3, l.Text = Color3.new(1, 1, 1), text
	l.Parent = g
	return l
end

function World.build()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	World.portal = part({
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, Config.PORTAL_SIZE, Config.PORTAL_SIZE),
		CFrame = CFrame.new(Config.PORTAL_POS) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 80, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, lobby)
	World.portalLabel = billboard(World.portal, "Step in to play!")

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	part({
		Name = "Ground",
		Size = Vector3.new(220, 1, 140),
		Position = Config.MAP_ORIGIN,
		Color = Color3.fromRGB(70, 140, 70),
		Material = Enum.Material.Grass,
	}, map)
	part({
		Name = "Track",
		Size = Vector3.new(Config.LENGTH, 1, Config.TRACK_WIDTH),
		Position = Vector3.new((Config.START.X + Config.FINISH.X) / 2, Config.MAP_ORIGIN.Y + 0.6, Config.START.Z),
		Color = Color3.fromRGB(110, 110, 110),
		Material = Enum.Material.Concrete,
	}, map)
	World.base = part({
		Name = "Base",
		Size = Vector3.new(8, 8, 8),
		Position = Config.FINISH + Vector3.new(6, 1.4, 0),
		Color = Color3.fromRGB(0, 120, 255),
	}, map)
	World.baseLabel = billboard(World.base, "")

	World.runtime = Instance.new("Folder")
	World.runtime.Name = "Runtime"
	World.runtime.Parent = workspace
end

return World
