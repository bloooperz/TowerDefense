-- Map + mode picker, opened by the server when a player steps into the idle portal.
-- Built entirely from the Maps/Modes registries: adding a map needs no UI changes.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = RS:WaitForChild("Shared")
local Maps = require(Shared.Maps)
local Modes = require(Shared.Modes)
local Net = require(Shared.Net)
local Style = require(script.Parent.Style)

local MapSelect = {}
local root
local chosenMap, chosenMode
local mapButtons, modeButtons = {}, {}

local function paint()
	for id, b in pairs(mapButtons) do
		b.BackgroundColor3 = id == chosenMap and Style.BLUE or Style.MID
	end
	for id, b in pairs(modeButtons) do
		b.BackgroundColor3 = id == chosenMode and Style.BLUE or Style.MID
	end
end

local function button(text, parent, order)
	local b = Style.make("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Style.MID,
		Font = Style.FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		LayoutOrder = order,
	}, parent)
	Style.make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	return b
end

local function column(title, x, parent)
	local col = Style.make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(x, 10, 0, 50),
		Size = UDim2.new(0.5, -20, 1, -120),
	}, parent)
	Style.text({ Text = title, Size = UDim2.new(1, 0, 0, 26) }, col)
	local list = Style.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32) }, col)
	Style.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	return list
end

function MapSelect.init()
	local screen = Style.make("ScreenGui", { Name = "MapSelect", ResetOnSpawn = false, DisplayOrder = 20 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	root = Style.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 360), Visible = false }, screen)
	Style.text({ Text = "Choose a map", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 8) }, root)
	local maps, modes = column("Map", 0, root), column("Mode", 0.5, root)
	for i, m in ipairs(Maps.list) do
		local b = button(m.name, maps, i)
		mapButtons[m.id] = b
		b.MouseButton1Click:Connect(function()
			chosenMap = m.id
			paint()
		end)
	end
	for i, m in ipairs(Modes.list) do
		local b = button(m.name .. (m.maxWaves and (" (" .. m.maxWaves .. " waves)") or " (endless)"), modes, i)
		modeButtons[m.id] = b
		b.MouseButton1Click:Connect(function()
			chosenMode = m.id
			paint()
		end)
	end
	chosenMap = Maps.list[1] and Maps.list[1].id
	chosenMode = Modes.list[1] and Modes.list[1].id
	paint()
	local start = button("Start", root, 0)
	start.AnchorPoint, start.Position, start.Size = Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), UDim2.fromOffset(160, 44)
	start.BackgroundColor3 = Style.GREEN
	start.MouseButton1Click:Connect(function()
		if chosenMap and chosenMode then
			Net.send("ChooseMap", chosenMap, chosenMode)
		end
		root.Visible = false
	end)
	local cancel = button("Cancel", root, 0)
	cancel.AnchorPoint, cancel.Position, cancel.Size = Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), UDim2.fromOffset(120, 44)
	cancel.BackgroundColor3 = Style.GREY
	cancel.MouseButton1Click:Connect(function()
		root.Visible = false
	end)
	Net.listen("OpenMapSelect", function()
		root.Visible = true
	end)
	Net.listen("MatchState", function()
		root.Visible = false
	end)
end

return MapSelect
