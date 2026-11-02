-- Unit panel: click one of your placed units to view/upgrade/sell it.
-- Reads Level/UnitType/UnitId attributes the server sets on the unit part.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Traits = require(Shared.Traits)
local Passive = require(Shared.Passive)
local Log = require(Shared.Log)
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UI.Theme)
local Toast = require(script.Parent.Toast)
local log = Log.new("UnitPanel")
local warned = {} -- [unitName] = true: passive problems are logged/toasted once per unit
local sideOpen = false
local SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local NEON = Color3.fromRGB(200, 70, 255)

local UnitPanel = {}
local refreshPassive
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

local function setSide(open)
	sideOpen = open
	gui.passiveBtn.Text = (gui.passiveIcon or "✦") .. "  " .. (gui.passiveName or "Passive") .. (open and "  ◀" or "  ▶")
	TweenService:Create(gui.side, SLIDE, { Position = open and UDim2.fromScale(0, 0) or UDim2.fromScale(-1.05, 0) }):Play()
end

refreshPassive = function(u, st, nx)
	if not Passive.has(u) then
		gui.passiveBtn.Visible = false
		if sideOpen then
			setSide(false)
		end
		return
	end
	gui.passiveBtn.Visible = true
	gui.passiveName, gui.passiveIcon = u.passive.name or "Passive", u.passive.icon
	gui.sideTitle.Text = (u.passive.icon and (u.passive.icon .. " ") or "") .. gui.passiveName
	local plain, rich, problems = Passive.describe(u, st, nx)
	if #problems > 0 and not warned[u.name] then
		warned[u.name] = true
		for _, p in ipairs(problems) do
			log.warn("passive:", p)
		end
		Toast.show(("%s passive info is broken (see Output)"):format(u.name), "error")
	end
	gui.sideText.Text = rich or plain or "No description available."
	gui.sideHint.Text = nx and "Green = changes on next upgrade" or "Max level"
	gui.passiveBtn.Text = (gui.passiveIcon or "✦") .. "  " .. gui.passiveName .. (sideOpen and "  ◀" or "  ▶")
end

local function refresh()
	if not current or not current.Parent then
		UnitPanel.close()
		return
	end
	local u = Units.get(current:GetAttribute("UnitType"))
	if not u then
		UnitPanel.close()
		return
	end
	local level = current:GetAttribute("Level") or 1
	local maxL = UnitStats.maxLevel(u)
	-- sandbox units carry overrides (Ov* attrs); same shared resolver as the server
	local ov = current:GetAttribute("Trait") and {
		damage = current:GetAttribute("OvDamage"), range = current:GetAttribute("OvRange"),
		rate = current:GetAttribute("OvRate"), trait = current:GetAttribute("Trait"),
	} or nil
	local st = Traits.resolve(UnitStats.at(u, level), ov)
	local nx = level < maxL and Traits.resolve(UnitStats.at(u, level + 1), ov) or nil

	gui.name.Text = u.name .. (u.unique and "  ★" or "")
	gui.level.Text = "Lv " .. level .. "/" .. maxL
	local lines = {
		statLine("Damage", st.damage, nx and nx.damage),
		statLine("Range", st.range, nx and nx.range),
		statLine("Attack every", st.rate, nx and nx.rate, "s"),
	}
	-- passive-specific numbers live in the Passive side panel, not here (core stats only)
	refreshPassive(u, st, nx)
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
	for i = 1, 3 do
		gui.stats[i] = text({
			Position = UDim2.fromOffset(16, 214 + (i - 1) * 22),
			Size = UDim2.new(1, -32, 0, 18),
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(220, 220, 230),
		}, panel)
	end

	-- Passive info button + companion side panel (slides out to the right of the unit screen).
	-- Child of the unit panel, so it hides with it; not a top-level Panel (one-panel rule untouched).
	gui.passiveBtn = make("TextButton", {
		Position = UDim2.fromOffset(16, 284), Size = UDim2.new(1, -32, 0, 34),
		Text = "Passive", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0, TextStrokeColor3 = Theme.OUTLINE,
		BackgroundColor3 = NEON, AutoButtonColor = true, Visible = false, ZIndex = 3,
	}, panel)
	round(gui.passiveBtn, 10)
	Theme.stroke(gui.passiveBtn, 3)
	Theme.gloss(gui.passiveBtn)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, gui.passiveBtn)
	gui.passiveBtn.MouseButton1Click:Connect(function()
		Log.try("UnitPanel", "toggle passive", setSide, not sideOpen)
	end)
	local clip = make("Frame", {
		Position = UDim2.new(1, 8, 0, 40), Size = UDim2.fromOffset(250, 260),
		BackgroundTransparency = 1, ClipsDescendants = true,
	}, panel)
	gui.side = make("Frame", {
		Position = UDim2.fromScale(-1.05, 0), Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Theme.PANEL,
	}, clip)
	round(gui.side, 14)
	Theme.stroke(gui.side, 3)
	make("UIStroke", { Thickness = 2, Color = NEON, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gui.side)
	gui.sideTitle = Theme.label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), TextColor3 = NEON, TextXAlignment = Enum.TextXAlignment.Left }, gui.side)
	gui.sideText = Theme.label({
		Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -84),
		TextScaled = false, TextSize = 17, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeTransparency = 0.6, Font = Enum.Font.GothamMedium,
	}, gui.side)
	gui.sideHint = Theme.label({ Position = UDim2.new(0, 12, 1, -30), Size = UDim2.new(1, -24, 0, 18), TextColor3 = Color3.fromRGB(170, 170, 200), TextXAlignment = Enum.TextXAlignment.Left }, gui.side)

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

-- Esc: close the passive side panel first, then the unit screen.
function UnitPanel.escape()
	if current and sideOpen then
		setSide(false)
	else
		UnitPanel.close()
	end
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
	if gui.side then
		sideOpen = false
		gui.side.Position = UDim2.fromScale(-1.05, 0) -- snap shut; reopening starts collapsed
	end
	if gui.panel then
		gui.panel.Visible = false
	end
end

return UnitPanel
