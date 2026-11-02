-- Ghost preview + range ring that follows the mouse.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Placement = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ghost, ring, unit, topper
local cashValue

function Placement.init(cash)
	cashValue = cash
	RunService.RenderStepped:Connect(function()
		if not ghost then
			return
		end
		local p = mouse.Hit.Position
		local pos = Vector3.new(math.round(p.X), Config.MAP_ORIGIN.Y + 0.5 + unit.size / 2, math.round(p.Z))
		ghost.Position = pos
		if topper then
			topper.Position = pos + Vector3.new(0, unit.size / 2 + 0.2, 0)
		end
		ring.CFrame = CFrame.new(pos.X, Config.MAP_ORIGIN.Y + 0.6, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		local ok = Config.isValidPlacement(pos, unit.size) and cashValue.Value >= unit.cost
		ring.Color = ok and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
	end)
end

function Placement.clear()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if ring then
		ring:Destroy()
		ring = nil
	end
	if topper then
		topper:Destroy()
		topper = nil
	end
	unit = nil
end

function Placement.start(u)
	Placement.clear()
	unit = u
	ghost = Instance.new("Part")
	ghost.Anchored, ghost.CanCollide, ghost.CanQuery = true, false, false
	ghost.Size, ghost.Transparency, ghost.Color = Vector3.one * u.size, 0.5, Color3.new(1, 1, 1)
	ghost.Parent = workspace
	ring = Instance.new("Part")
	ring.Shape, ring.Anchored, ring.CanCollide, ring.CanQuery = Enum.PartType.Cylinder, true, false, false
	ring.Size, ring.Transparency, ring.Material = Vector3.new(0.2, u.range * 2, u.range * 2), 0.7, Enum.Material.Neon
	ring.Parent = workspace
	if u.topper then
		topper = Instance.new("Part")
		topper.Anchored, topper.CanCollide, topper.CanQuery = true, false, false
		topper.Size, topper.Transparency, topper.Color = Vector3.new(u.size, 0.4, u.size), 0.5, u.topper
		topper.Parent = ghost
	end
	mouse.TargetFilter = ghost
end

function Placement.position()
	return ghost and ghost.Position
end

return Placement
