-- Ghost preview + range ring that follows the mouse.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local UnitStats = require(Shared.UnitStats)
local MyUnits = require(script.Parent.MyUnits)

local Placement = {}
local function RS_INFO()
	return game:GetService("ReplicatedStorage"):WaitForChild("MatchInfo")
end
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ghost, ring, unit, topper
local cashValue, unitId
local tip, warn, flashUntil = nil, nil, 0
local sandboxCb = nil -- dev sandbox placement: skips cost/caps, calls back with the position

-- Why the current spot can't be used, or nil if it can.
function Placement.reason()
	if not ghost then
		return nil
	end
	if not sandboxCb and MyUnits.count(unitId) >= UnitStats.maxPlaced(unit) then
		return "Limit reached!"
	end
	if not sandboxCb and cashValue.Value < unit.cost then
		return "Not enough money!"
	end
	local pos = ghost.Position
	local spot = Maps.placementReason(Maps.get(RS_INFO():GetAttribute("MapId") or ""), pos, unit.size)
	if spot then
		return spot
	end
	if MyUnits.overlapsAny(pos, unit.size) then
		return "Overlaps another unit"
	end
	return nil
end

-- Show a red message near the cursor for a moment (used on rejected click).
function Placement.flash(msg)
	warn.Text = msg
	flashUntil = os.clock() + 1.2
end

function Placement.init(cash)
	cashValue = cash
	local screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset, screen.DisplayOrder = "Cursor", false, true, 10
	screen.Parent = player:WaitForChild("PlayerGui")
	local function label(color, y)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency, l.TextScaled, l.Font = 1, true, Enum.Font.FredokaOne
		l.TextColor3, l.Size, l.Position = color, UDim2.fromOffset(220, 22), UDim2.fromOffset(0, y)
		l.TextXAlignment = Enum.TextXAlignment.Left
		local s = Instance.new("UIStroke")
		s.Thickness, s.Parent = 1.5, l
		l.Parent = screen
		return l
	end
	tip = label(Color3.fromRGB(230, 230, 240), 0)
	tip.Text = "LMB Place  |  Q/RMB Cancel"
	tip.Size = UDim2.fromOffset(200, 16)
	warn = label(Color3.fromRGB(255, 70, 70), 0)

	RunService.RenderStepped:Connect(function()
		local m = UIS:GetMouseLocation()
		tip.Position = UDim2.fromOffset(m.X + 18, m.Y + 18)
		warn.Position = UDim2.fromOffset(m.X + 18, m.Y - 8)
		tip.Visible = ghost ~= nil
		if not ghost then
			warn.Visible = os.clock() < flashUntil
			return
		end
		local p = mouse.Hit.Position
		local pos = Vector3.new(math.round(p.X), Config.MAP_ORIGIN.Y + Config.GROUND_TOP + unit.size / 2, math.round(p.Z))
		ghost.Position = pos
		if topper then
			topper.Position = pos + Vector3.new(0, unit.size / 2 + 0.2, 0)
		end
		ring.CFrame = CFrame.new(pos.X, Config.MAP_ORIGIN.Y + 0.6, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		local why = Placement.reason()
		ring.Color = why and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
		if why then
			warn.Text = why
		end
		warn.Visible = why ~= nil or os.clock() < flashUntil
	end)
end

function Placement.clear()
	sandboxCb = nil
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

function Placement.start(u, id)
	Placement.clear()
	unit, unitId = u, id
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

-- Dev sandbox: same preview, but free/uncapped; LMB calls cb(pos) (Main routes the click).
function Placement.startSandbox(u, range, cb)
	Placement.start(u, u.id)
	sandboxCb = cb
	if range and range > 0 then
		ring.Size = Vector3.new(0.2, range * 2, range * 2)
	end
end
function Placement.isSandbox()
	return sandboxCb ~= nil
end
function Placement.commitSandbox()
	local why = Placement.reason()
	if why then
		Placement.flash(why)
		return
	end
	local cb, pos = sandboxCb, ghost.Position
	Placement.clear()
	cb(pos)
end

function Placement.position()
	return ghost and ghost.Position
end

return Placement
