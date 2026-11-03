-- Map + mode picker, opened by the server when a player steps into the idle portal.
-- Built entirely from the Maps/Modes registries: adding a map needs no UI changes.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = RS:WaitForChild("Shared")
local Maps = require(Shared.Maps)
local Modes = require(Shared.Modes)
local Net = require(Shared.Net)
local Style = require(script.Parent.Style)
local Panel = require(script.Parent.UI.Panel)
local Shape = require(script.Parent.UI.Shape)
local UiState = require(Shared.UiState)

local MapSelect = {}
local root, titleLabel, startBtn, mapsCol, modesCol
local kind = "pick"
local chosenMap, chosenMode
local mapButtons, modeButtons = {}, {}

-- Selected = solid orange fill + thick dark-orange border for every map (UiState.pickCard),
-- painted via Shape.setFill so the hover/press tween can't fade it back to the neutral fill.
local PICK = { ORANGE = Style.ORANGE, ORANGE_EDGE = Style.ORANGE, NEUTRAL = Style.MID, BORDER = Style.STROKE }
local function paintPick(b, selected)
	local v = UiState.pickCard(selected)
	local h = Shape.get(b)
	if h then
		h.setFill(PICK[v.fill])
		h.setEdge(PICK[v.edge], v.thickness)
	else
		b.BackgroundColor3 = PICK[v.fill]
	end
end
local function paint()
	for id, b in pairs(mapButtons) do
		paintPick(b, id == chosenMap)
	end
	for id, b in pairs(modeButtons) do
		paintPick(b, id == chosenMode)
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
	Style.shape(b, 8)
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
	MapSelect.panel = Panel.register({
		open = function()
			root.Visible = true
		end,
		close = function()
			root.Visible = false
		end,
	})
	local screen = Style.make("ScreenGui", { Name = "MapSelect", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 20 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	root = Style.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 360), Visible = false }, screen)
	titleLabel = Style.text({ Text = "Choose a map", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 8) }, root)
	local maps, modes = column("Map", 0, root), column("Mode", 0.5, root)
	-- Same reusable drop-rates popup as the Summon panel.
	require(script.Parent.UI.Rates).button(root, { Position = UDim2.new(1, -100, 0, 10), Size = UDim2.fromOffset(84, 28) })
	mapsCol, modesCol = maps.Parent, modes.Parent
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
	startBtn = start
	start.AnchorPoint, start.Position, start.Size = Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), UDim2.fromOffset(160, 44)
	start.BackgroundColor3 = Style.GREEN
	start.MouseButton1Click:Connect(function()
		if kind == "join" then
			Net.send("JoinMatch")
		elseif chosenMap and chosenMode then
			Net.send("ChooseMap", chosenMap, chosenMode)
		end
		MapSelect.panel.close()
	end)
	local cancel = button("Cancel", root, 0)
	cancel.AnchorPoint, cancel.Position, cancel.Size = Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), UDim2.fromOffset(120, 44)
	cancel.BackgroundColor3 = Style.GREY
	cancel.MouseButton1Click:Connect(function()
		MapSelect.panel.close()
	end)
	-- payload: { kind = "pick" } or { kind = "join", mapName, modeName, players }
	Net.listen("OpenMapSelect", function(p)
		kind = (type(p) == "table" and p.kind) or "pick"
		local join = kind == "join"
		mapsCol.Visible, modesCol.Visible = not join, not join
		titleLabel.Text = join and ("Join %s (%s)? %d in lobby"):format(p.mapName or "?", p.modeName or "?", p.players or 0)
			or "Choose a map"
		startBtn.Text = join and "Join" or "Start"
		MapSelect.panel.open() -- one-panel manager closes any lobby panel
	end)
	Net.listen("MatchState", function()
		MapSelect.panel.close()
	end)
end

return MapSelect
