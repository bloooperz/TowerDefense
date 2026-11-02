-- Hotbar built from the player's loadout (Player attribute "Loadout" = "Basic,Sniper,...").
-- Rebuilds whenever the loadout changes, so equip/unequip later needs no client changes here.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local MyUnits = require(script.Parent.MyUnits)
local Style = require(script.Parent.Style)

local Hotbar = {}
local slots, counts = {}, {}
Hotbar.ids = {} -- slot index -> unitId
Hotbar.onSelect = nil -- function(slotIndex)

local player = Players.LocalPlayer

local function parseLoadout()
	local ids = {}
	local raw = player:GetAttribute("Loadout")
	if raw and raw ~= "" then
		for id in string.gmatch(raw, "[^,]+") do
			if Units.get(id) and #ids < Config.LOADOUT_SIZE then
				table.insert(ids, id)
			end
		end
	else
		ids = table.clone(Config.STARTER_LOADOUT)
	end
	return ids
end

local function rebuild()
	local bar = Hotbar.bar
	for _, c in ipairs(bar:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	table.clear(slots)
	table.clear(counts)
	Hotbar.ids = parseLoadout()
	bar.Size = UDim2.fromOffset(#Hotbar.ids * 90, 90)
	for i, id in ipairs(Hotbar.ids) do
		local u = Units.get(id)
		local b = Instance.new("TextButton")
		b.Size, b.BackgroundColor3 = UDim2.fromOffset(80, 80), Color3.fromRGB(40, 40, 50)
		b.TextColor3, b.TextScaled = Color3.new(1, 1, 1), true
		b.Text = i .. "\n" .. u.name .. "\n$" .. u.cost
		b.Font = Style.FONT
		b.LayoutOrder = i
		b.BackgroundColor3 = Style.MID
		local stroke = Style.shape(b, 8, Style.STROKE)
		b.MouseButton1Click:Connect(function()
			if Hotbar.onSelect then
				Hotbar.onSelect(i)
			end
		end)
		local c = Instance.new("TextLabel")
		c.AnchorPoint, c.Position, c.Size = Vector2.new(1, 0), UDim2.new(1, -4, 0, 2), UDim2.fromOffset(34, 16)
		c.BackgroundTransparency, c.TextScaled, c.Font = 1, true, Enum.Font.GothamBlack
		c.TextColor3 = Color3.fromRGB(200, 200, 210)
		c.Parent = b
		counts[i], slots[i] = c, stroke
		b.Parent = bar
	end
	Hotbar.refreshCounts()
end

function Hotbar.init()
	local screen = Instance.new("ScreenGui")
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- UI/Shape relies on children drawing over parents
	screen.Name, screen.ResetOnSpawn = "TDGui", false
	screen.Parent = player:WaitForChild("PlayerGui")
	local bar = Instance.new("Frame")
	bar.AnchorPoint, bar.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -20)
	bar.BackgroundTransparency, bar.Visible = 1, false
	local layout = Instance.new("UIListLayout", bar)
	layout.FillDirection, layout.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	bar.Parent = screen
	Hotbar.bar = bar
	rebuild()
	player:GetAttributeChangedSignal("Loadout"):Connect(rebuild)
	task.spawn(function()
		while true do
			if bar.Visible then
				Hotbar.refreshCounts()
			end
			task.wait(0.3)
		end
	end)
end

function Hotbar.unitAt(i)
	local id = Hotbar.ids[i]
	return id and Units.get(id), id
end

function Hotbar.highlight(index)
	for i, s in ipairs(slots) do
		s.setEdge((i == index) and Color3.fromRGB(255, 220, 0) or Style.STROKE, (i == index) and 2 or 1.5)
	end
end

function Hotbar.refreshCounts()
	for i, id in ipairs(Hotbar.ids) do
		local u = Units.get(id)
		local n, max = MyUnits.count(id), UnitStats.maxPlaced(u)
		counts[i].Text = n .. "/" .. max
		counts[i].TextColor3 = n >= max and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(200, 200, 210)
	end
end

function Hotbar.setState(s)
	Hotbar.bar.Visible = (s ~= "lobby")
	Hotbar.refreshCounts()
end

return Hotbar
