-- Lobby Inventory panel (I): items / materials (XP food, portals, materials). READ-ONLY.
-- Data: the server's `Items` attribute (JSON { [id] = count }). Rows decided by shared/ItemsView.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ItemsView = require(Shared.ItemsView)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Shape = require(UI.Shape)

local log = Log.new("ItemsUI")
local player = Players.LocalPlayer
local U = Theme.Unit
local W = Theme.World
local ItemsUI = {}

local function decode()
	local raw = player:GetAttribute("Items")
	if type(raw) ~= "string" then
		return nil -- not replicated yet -> loading
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(v) ~= "table" then
		log.warn("bad Items attribute:", v)
		return {}
	end
	return v
end

function ItemsUI.build(panel)
	local root = panel.root
	root.Size = UDim2.fromOffset(560, 440)
	panel.body.Visible = false
	if panel.title then
		panel.title.Text = "Inventory"
	end
	local header = Theme.label({ Text = "Items: -", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(24, 58), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, root)
	local list = Theme.make("ScrollingFrame", { Position = UDim2.fromOffset(16, 88), Size = UDim2.new(1, -32, 1, -104), BackgroundColor3 = U.BASE_2, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, root)
	Shape.apply(list, { radius = 6, edge = U.BORDER, thickness = 2, gradient = false })
	Theme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12) }, list)
	local message = Theme.label({ Text = ItemsView.LOADING, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0.5, 0), TextColor3 = W.MUTED, TextWrapped = true, ZIndex = 24 }, root)

	local function render()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local vm = ItemsView.view(decode())
		header.Text = vm.header
		message.Text = vm.message or ""
		message.Visible = vm.message ~= nil
		for i, r in ipairs(vm.rows) do
			local row = Theme.make("Frame", { Name = r.id, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, ZIndex = 23 }, list)
			Shape.apply(row, { radius = 6, fill = U.BASE, transparency = 0, edge = U.BORDER, thickness = 2, gradient = false })
			local slot = Theme.make("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = U.BASE_2, ZIndex = 24 }, row)
			Shape.apply(slot, { radius = 6, edge = U.BORDER, thickness = 2, gradient = false })
			Shape.iconSlot({ Size = UDim2.fromScale(1, 1), ZIndex = 25 }, slot) -- blank until item art exists
			Theme.label({ Text = r.name, Size = UDim2.new(0.55, -56, 0, 24), Position = UDim2.fromOffset(56, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24 }, row)
			Theme.label({ Text = r.category, Font = Theme.BODY, Size = UDim2.new(0.55, -56, 0, 18), Position = UDim2.fromOffset(56, 29), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.MUTED, ZIndex = 24 }, row)
			Theme.label({ Text = r.countText, Size = UDim2.new(0.3, 0, 0, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = W.YELLOW, ZIndex = 24 }, row)
			Shape.tooltip(row, r.tooltip, W.BORDER)
		end
	end
	player:GetAttributeChangedSignal("Items"):Connect(function()
		Log.try("ItemsUI", "render", render)
	end)
	Log.try("ItemsUI", "render", render)
end

return ItemsUI
