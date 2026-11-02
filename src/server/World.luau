-- Builds the lobby once, and builds/clears a map from a Map definition.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)

local World = {}

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
World.part = part

local function billboard(adornee, text, size)
	local g = Instance.new("BillboardGui")
	g.Size, g.StudsOffsetWorldSpace, g.AlwaysOnTop = size or UDim2.fromOffset(250, 60), Vector3.new(0, 6, 0), false
	g.MaxDistance = 120 -- not AlwaysOnTop: never draws through walls/UI
	g.Parent = adornee
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, true
	l.TextColor3, l.Text, l.Font = Color3.new(1, 1, 1), text, Enum.Font.FredokaOne
	l.TextStrokeTransparency = 0.4
	l.Parent = g
	return l
end

function World.buildLobby()
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

	World.runtime = Instance.new("Folder")
	World.runtime.Name = "Runtime" -- placed units live directly in here
	World.runtime.Parent = workspace
	World.movers = Instance.new("Folder")
	World.movers.Name = "Movers" -- anything moved along the path by the client renderer
	World.movers.Parent = World.runtime
	World.fx = Instance.new("Folder")
	World.fx.Name = "FX"
	World.fx.Parent = World.runtime
end

function World.clearMap()
	if World.mapFolder then
		World.mapFolder:Destroy()
		World.mapFolder = nil
	end
end

function World.buildMap(map)
	World.clearMap()
	local f = Instance.new("Folder")
	f.Name = "Map"
	f.Parent = workspace
	World.mapFolder = f
	local o = Config.MAP_ORIGIN
	part({
		Name = "Ground",
		Size = map.groundSize,
		Position = o,
		Color = map.groundColor or Color3.fromRGB(70, 140, 70),
		Material = Enum.Material.Grass,
	}, f)
	local path = Maps.path(map)
	for i, s in ipairs(path.segs) do
		local mid = s.a + s.dir * (s.len / 2)
		local flat = Vector3.new(mid.X, o.Y + Config.TRACK_TOP - 0.5, mid.Z)
		part({
			Name = "Track" .. i,
			Size = Vector3.new(map.trackWidth, 1, s.len + map.trackWidth),
			CFrame = CFrame.lookAt(flat, flat + Vector3.new(s.dir.X, 0, s.dir.Z)),
			Color = Color3.fromRGB(110, 110, 110),
			Material = Enum.Material.Concrete,
		}, f)
	end
	local endPos, endDir = path:positionAt(path.length)
	World.base = part({
		Name = "Base",
		Size = Vector3.new(8, 8, 8),
		Position = endPos + endDir * 6 + Vector3.new(0, 4 - 0.5, 0),
		Color = Color3.fromRGB(0, 120, 255),
	}, f)
	World.baseLabel = billboard(World.base, "", UDim2.fromOffset(120, 28))
	local startPos = path:positionAt(0)
	part({
		Name = "EnemySpawn",
		Size = Vector3.new(6, 0.4, 6),
		Position = startPos + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, f)
	return path
end

return World
