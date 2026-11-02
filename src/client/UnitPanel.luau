-- Unit panel: click one of your placed units to view/upgrade/sell it.
-- Reads Level/UnitIndex/UnitId attributes the server sets on the unit part.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local UnitPanel = {}
local player = Players.LocalPlayer
local cashValue, upgradeEvent, sellEvent, targetEvent
local gui = {}
local current, ring, model, conns = nil, nil, nil, {}
local angle = 0

local DARK = Color3.fromRGB(22, 22, 30)
local MID = Color3.fromRGB(38, 38, 50)
local GREEN = Color3.fromRGB(0, 170, 90)
local RED = Color3.fromRGB(190, 50, 50)
local GREY = Color3.fromRGB(70, 70, 80)

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end
local function text(props, parent)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function fmt(n)
	if math.floor(n) == n then
		return tostring(n)
	end
	return string.format("%.2f", n)
end

local function statLine(label, now, nxt, suffix)
	suffix = suffix or ""
	local s = label .. ": " .. fmt(now) .. suffix
	if nxt and nxt ~= now then
		s ..= "  →  " .. fmt(nxt) .. suffix
	end
	return s
end

local function refresh()
	if not current or not current.Parent then
		UnitPanel.close()
		return
	end
	local u = Config.UNITS[current:GetAttribute("UnitIndex")]
	local level = current:GetAttribute("Level") or 1
	local maxL = Config.maxLevel(u)
	local st = Config.statsAt(u, level)
	local nx = level < maxL and Config.statsAt(u, level + 1) or nil

	gui.name.Text = u.name .. (u.unique and "  ★" or "")
	gui.level.Text = "Lv " .. level .. "/" .. maxL
	local lines = {
		statLine("Damage", st.damage, nx and nx.damage),
		statLine("Range", st.range, nx and nx.range),
		statLine("Attack every", st.rate, nx and nx.rate, "s"),
	}
	if st.ability.dogDamage then
		table.insert(lines, statLine("Dog damage", st.ability.dogDamage, nx and nx.ability.dogDamage))
		table.insert(lines, statLine("Max dogs", st.ability.maxDogs, nx and nx.ability.maxDogs))
		table.insert(lines, statLine("Dog every Nth hit", st.ability.every, nx and nx.ability.every))
	end
	for i, l in ipairs(gui.stats) do
		l.Text = lines[i] or ""
	end

	local up = u.upgrades and u.upgrades[level]
	if not up then
		gui.upgrade.Text, gui.upgrade.BackgroundColor3, gui.upgrade.AutoButtonColor = "MAX LEVEL", GREY, false
	else
		local ok = cashValue.Value >= up.cost
		gui.upgrade.Text = "UPGRADE  $" .. up.cost
		gui.upgrade.BackgroundColor3, gui.upgrade.AutoButtonColor = ok and GREEN or GREY, ok
	end
	gui.target.Text = "Target: " .. (current:GetAttribute("Targeting") or "First")
	local spent = current:GetAttribute("Spent") or u.cost
	gui.sell.Text = "SELL  $" .. math.floor(spent * Config.SELL_REFUND)

	-- range ring
	if ring then
		ring.Size = Vector3.new(0.2, st.range * 2, st.range * 2)
		local p = current.Position
		ring.CFrame = CFrame.new(p.X, Config.MAP_ORIGIN.Y + 0.6, p.Z) * CFrame.Angles(0, 0, math.rad(90))
	end
end

local function buildModel(unitPart)
	gui.view:ClearAllChildren()
	local cam = make("Camera", {}, gui.view)
	gui.view.CurrentCamera = cam
	model = make("Model", {}, gui.view)
	local clone = unitPart:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if not d:IsA("BasePart") then
			d:Destroy()
		end
	end
	local offset = clone.Position
	clone.Position = Vector3.zero
	clone.Parent = model
	for _, d in ipairs(clone:GetChildren()) do
		d.Position -= offset
	end
	model.PrimaryPart = clone
	gui.camDist = clone.Size.Magnitude * 1.6
end

function UnitPanel.init(cash, upEv, sellEv, targetEv)
	cashValue, upgradeEvent, sellEvent, targetEvent = cash, upEv, sellEv, targetEv
	local screen = make("ScreenGui", { Name = "UnitPanel", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(280, 488),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, screen)
	round(panel, 14)
	make("UIStroke", { Color = Color3.fromRGB(90, 90, 120), Thickness = 2 }, panel)
	gui.panel = panel

	gui.name = text({ Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(200, 28) }, panel)
	gui.level = text({
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.fromOffset(200, 18),
		TextColor3 = Color3.fromRGB(255, 210, 80),
	}, panel)

	local close = make("TextButton", {
		Position = UDim2.new(1, -40, 0, 10),
		Size = UDim2.fromOffset(30, 30),
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = RED,
	}, panel)
	round(close, 8)
	close.MouseButton1Click:Connect(function()
		UnitPanel.close()
	end)

	gui.view = make("ViewportFrame", {
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 0, 140),
		BackgroundColor3 = MID,
		Ambient = Color3.fromRGB(150, 150, 150),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	}, panel)
	round(gui.view, 10)

	gui.stats = {}
	for i = 1, 6 do
		gui.stats[i] = text({
			Position = UDim2.fromOffset(16, 214 + (i - 1) * 22),
			Size = UDim2.new(1, -32, 0, 18),
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(220, 220, 230),
		}, panel)
	end

	local function button(label, color, y)
		local b = make("TextButton", {
			Position = UDim2.new(0, 16, 1, y),
			Size = UDim2.new(1, -32, 0, 40),
			Text = label,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = color,
		}, panel)
		round(b, 10)
		make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, b)
		return b
	end
	gui.target = button("Target: First", Color3.fromRGB(60, 110, 200), -148)
	gui.target.MouseButton1Click:Connect(function()
		if current then
			local modes = Config.TARGET_MODES
			local i = table.find(modes, current:GetAttribute("Targeting") or "First") or 1
			targetEvent:FireServer(current:GetAttribute("UnitId"), modes[i % #modes + 1])
		end
	end)
	gui.upgrade = button("UPGRADE", GREEN, -100)
	gui.sell = button("SELL", RED, -52)
	gui.upgrade.MouseButton1Click:Connect(function()
		if current then
			upgradeEvent:FireServer(current:GetAttribute("UnitId"))
		end
	end)
	gui.sell.MouseButton1Click:Connect(function()
		if current then
			sellEvent:FireServer(current:GetAttribute("UnitId"))
			UnitPanel.close()
		end
	end)

	cashValue.Changed:Connect(function()
		if current then
			refresh()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not current or not model or not gui.view.CurrentCamera then
			return
		end
		angle += dt * 0.8
		local d = gui.camDist
		gui.view.CurrentCamera.CFrame =
			CFrame.lookAt(Vector3.new(math.sin(angle) * d, d * 0.5, math.cos(angle) * d), Vector3.zero)
	end)
end

function UnitPanel.open(unitPart)
	UnitPanel.close()
	current = unitPart
	buildModel(unitPart)
	ring = make("Part", {
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 0.75,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(80, 170, 255),
	}, workspace)
	table.insert(conns, unitPart.AttributeChanged:Connect(refresh))
	table.insert(conns, unitPart.AncestryChanged:Connect(function()
		if not unitPart:IsDescendantOf(workspace) then
			UnitPanel.close()
		end
	end))
	gui.panel.Visible = true
	refresh()
end

function UnitPanel.close()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	if ring then
		ring:Destroy()
		ring = nil
	end
	current, model = nil, nil
	if gui.panel then
		gui.panel.Visible = false
	end
end

return UnitPanel
