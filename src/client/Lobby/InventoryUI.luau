-- Lobby Inventory ("Collection") panel. UI ONLY: Equip / Sell show a "Coming soon" toast,
-- Lock is a client-side visual toggle, View shows a spinnable 3D portrait + stats as stored.
-- Data: the server's `Inventory` attribute (JSON). Layout/text decided by shared/InventoryView.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Traits = require(Shared.Traits)
local InventoryView = require(Shared.InventoryView)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Shape = require(UI.Shape)
local Card = require(UI.Card)
local Toast = require(script.Parent.Parent.Toast)

local log = Log.new("Inventory")
local player = Players.LocalPlayer
local U = Theme.Unit
local W = Theme.World
local InventoryUI = {}

local BTN_COLORS = { Equip = W.YELLOW, Sell = W.RED, Lock = Color3.fromRGB(110, 116, 128), View = W.ORANGE }
local CARD_W, CARD_H = 100, 96 -- near-square like the reference

local function decode()
	local raw = player:GetAttribute("Inventory")
	if type(raw) ~= "string" then
		return nil -- not replicated yet -> loading
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(v) ~= "table" then
		log.warn("bad Inventory attribute:", v)
		return {}
	end
	return v
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function rarityColor(r)
	return Config.RARITY_COLORS[r or "Common"] or U.BORDER
end

local function bigButton(text, color, parent, order)
	local b = Theme.make("TextButton", { Text = text, Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = color, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = order, ZIndex = 33 }, parent)
	Theme.button(b, color)
	Shape.outlineText(b, 2)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, b)
	return b
end

-- Drag (mouse or touch) on `vp` spins `model` around Y.
local function spinnable(vp, model)
	local dragging, lastX, angle = false, 0, 0
	local pivot = model:GetPivot()
	vp.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, i.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			angle += (i.Position.X - lastX) * 0.01
			lastX = i.Position.X
			model:PivotTo(pivot * CFrame.Angles(0, angle, 0))
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

function InventoryUI.build(panel)
	local root = panel.root
	root.Size = UDim2.fromOffset(6 * (CARD_W + 8) + 44, 470)
	root.Position = UDim2.new(0.5, -150, 0.5, 0) -- leave room for the slide-out detail on the right
	panel.body.Visible = false
	if panel.title then
		panel.title.Text = "Collection"
	end
	local locks = InventoryView.newLocks()
	local selected = nil
	local tipOpen = false

	local headerKey = Theme.label({ Text = "Units:", Size = UDim2.fromOffset(80, 24), Position = UDim2.fromOffset(24, 58), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.MUTED, ZIndex = 22 }, root)
	local header = Theme.label({ Text = "-/" .. InventoryView.MAX_UNITS, Size = UDim2.fromOffset(110, 24), Position = UDim2.fromOffset(110, 58), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, root)
	local grid = Theme.make("ScrollingFrame", { Position = UDim2.fromOffset(16, 88), Size = UDim2.new(1, -32, 1, -104), BackgroundColor3 = U.BASE_2, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, root)
	Shape.apply(grid, { radius = 6, edge = U.BORDER, thickness = 2, gradient = false })
	Theme.make("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H), CellPadding = UDim2.fromOffset(8, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, grid)
	local message = Theme.label({ Text = InventoryView.LOADING, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0.5, 0), TextColor3 = W.MUTED, ZIndex = 24 }, root)

	-- slide-out detail (child of root -> hides with the panel; not a separate Panel)
	local detail = Theme.make("Frame", { Position = UDim2.new(1, 12, 0, 0), Size = UDim2.fromOffset(260, 470), Visible = false, ZIndex = 30 }, root)
	Theme.panel(detail, U.BORDER, Theme.Unit)
	local dlist = Theme.make("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundTransparency = 1, ZIndex = 31 }, detail)
	Theme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, dlist)
	local tip = Theme.make("Frame", { Position = UDim2.new(1, 10, 0, 90), Size = UDim2.fromOffset(230, 110), Visible = false, ZIndex = 34 }, detail)
	Theme.panel(tip, W.BLUE, Theme.Unit) -- dark box, thick colored border
	Shape.iconSlot({ Name = "TraitIcon", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 10), ZIndex = 35 }, tip)
	local tipName = Theme.label({ Text = "", Size = UDim2.new(1, -54, 0, 26), Position = UDim2.fromOffset(42, 9), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 35 }, tip)
	local tipDesc = Theme.label({ Text = "", TextScaled = false, TextSize = 20, TextWrapped = true, Font = Theme.FONT, TextColor3 = U.MUTED, Size = UDim2.new(1, -20, 1, -44), Position = UDim2.fromOffset(12, 40), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 35 }, tip)

	-- View mode: replaces the grid content (Back returns)
	local view = Theme.make("Frame", { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 1, -72), BackgroundTransparency = 1, Visible = false, ZIndex = 22 }, root)

	local render
	local function showGrid(on)
		header.Visible, headerKey.Visible, grid.Visible = on, on, on
		view.Visible = not on
		if not on then
			detail.Visible, message.Visible = false, false
		end
	end

	local function openView(card)
		clear(view)
		showGrid(false)
		local def = Units.get(card.unitId)
		local vp = Card.portrait(def, view)
		vp.Size, vp.Position, vp.ZIndex = UDim2.new(0.55, 0, 1, -50), UDim2.fromOffset(0, 0), 23
		Shape.apply(vp, { radius = 8, edge = rarityColor(card.rarity), thickness = 3, gradient = false })
		local model = vp:FindFirstChildWhichIsA("Model")
		if model then
			spinnable(vp, model)
		end
		Theme.label({ Text = "Drag to spin", Size = UDim2.new(0.55, 0, 0, 18), Position = UDim2.new(0, 0, 1, -46), TextColor3 = W.MUTED, Font = Theme.BODY, ZIndex = 24 }, view)
		local info = Theme.make("Frame", { Position = UDim2.new(0.55, 14, 0, 0), Size = UDim2.new(0.45, -14, 1, -50), BackgroundTransparency = 1, ZIndex = 23 }, view)
		Theme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, info)
		local m = InventoryView.detail(card, def, locks.isLocked(card.uid))
		local n = 0
		local function line(text, color, h)
			n += 1
			Theme.label({ Text = text, Size = UDim2.new(1, 0, 0, h or 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Color3.new(1, 1, 1), LayoutOrder = n, ZIndex = 24 }, info)
		end
		line(m.name, nil, 30)
		line(m.rarity, rarityColor(m.rarity))
		line(m.levelText, W.YELLOW)
		for _, s in ipairs(m.stats) do
			line(s.label .. ": " .. s.value)
		end
		for _, s in ipairs(m.extra) do
			line(s.label .. ": " .. s.value, W.MUTED)
		end
		line("Trait: " .. m.traitText, m.trait and W.YELLOW or W.MUTED)
		if m.trait and m.trait.desc ~= "" then
			n += 1
			Theme.label({ Text = m.trait.desc, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Theme.BODY, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = n, ZIndex = 24 }, info)
		end
		local back = bigButton("Back", W.BLUE, view, 0)
		back.Size, back.Position = UDim2.fromOffset(140, 40), UDim2.new(1, -140, 1, -40)
		back.Activated:Connect(function()
			showGrid(true)
			render()
		end)
	end

	local function openDetail(card)
		clear(dlist)
		tip.Visible, tipOpen = false, false
		local def = Units.get(card.unitId)
		local m = InventoryView.detail(card, def, locks.isLocked(card.uid))
		local rc = rarityColor(m.rarity)
		Shape.get(detail).setEdge(locks.isLocked(card.uid) and W.YELLOW or rc, 3)
		Theme.label({ Text = m.name, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 32 }, dlist)
		local row = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 32 }, dlist)
		Theme.label({ Text = m.rarity, Size = UDim2.new(0.55, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rc, ZIndex = 32 }, row)
		local chip = Theme.make("TextButton", { Text = m.traitText, Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = m.trait and W.BLUE or U.BASE, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 33 }, row)
		Theme.button(chip, m.trait and W.BLUE or U.BASE)
		Theme.make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, chip)
		local function setTip(on)
			tipOpen = on and m.trait ~= nil
			tip.Visible = tipOpen
			if m.trait then
				tipName.Text, tipName.TextColor3 = m.trait.name, W.BLUE
				tipDesc.Text = m.trait.desc
			end
		end
		chip.MouseEnter:Connect(function() setTip(true) end)
		chip.MouseLeave:Connect(function() setTip(false) end)
		chip.Activated:Connect(function() setTip(not tipOpen) end)
		Theme.label({ Text = m.levelText, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.YELLOW, LayoutOrder = 3, ZIndex = 32 }, dlist)
		local stats = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 32 }, dlist)
		Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, stats)
		for i, s in ipairs(m.stats) do
			local c = Theme.make("Frame", { Size = UDim2.new(1 / 3, -4, 1, 0), LayoutOrder = i, ZIndex = 32 }, stats)
			Shape.apply(c, { radius = 6, fill = U.BASE, transparency = 0, edge = U.BORDER, thickness = 2, gradient = false })
			local slot = Shape.iconSlot({ Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(4, 4), ZIndex = 33 }, c)
			Shape.tooltip(slot, s.label, U.BORDER)
			Theme.label({ Text = s.value, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(22, 2), ZIndex = 33 }, c)
			Theme.label({ Text = s.label, Font = Theme.BODY, TextColor3 = W.MUTED, Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 1, -17), ZIndex = 33 }, c)
		end
		Theme.label({ Text = m.lockText, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = locks.isLocked(card.uid) and W.YELLOW or W.MUTED, LayoutOrder = 5, ZIndex = 32 }, dlist)
		for i, bdef in ipairs(m.buttons) do
			local b = bigButton(bdef.text, BTN_COLORS[bdef.action], dlist, 10 + i)
			b.Name = bdef.action .. "Button"
			b.Activated:Connect(function()
				if bdef.action == "Equip" or bdef.action == "Sell" then
					Toast.show(bdef.text .. ": coming soon", "info")
				elseif bdef.action == "Lock" then
					locks.toggle(card.uid)
					render()
				elseif bdef.action == "View" then
					openView(card)
				end
			end)
		end
		detail.Visible = true
	end

	render = function()
		if view.Visible then
			return
		end
		local vm = InventoryView.cards(decode(), Units.get, Traits.byId)
		header.Text = vm.header:gsub("^Units: ", "")
		message.Text = vm.message or ""
		message.Visible = vm.message ~= nil
		clear(grid)
		local found = nil
		for i, card in ipairs(vm.cards) do
			local def = Units.get(card.unitId)
			local rc = rarityColor(card.rarity)
			local isSel = card.uid == selected
			if isSel then
				found = card
			end
			local c = Theme.make("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 23 }, grid)
			Shape.apply(c, { radius = 8, fill = U.BASE, transparency = 0, edge = isSel and Color3.new(1, 1, 1) or rc, thickness = isSel and 5 or 4 })
			Shape.glow(c, rc)
			-- portrait fills the card (inset inside the border); text overlays it
			local vp = Card.portrait(def, c)
			vp.Size, vp.Position, vp.ZIndex = UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), 24
			Shape.apply(vp, { radius = 6, edge = U.BORDER, thickness = 1, gradient = false })
			Theme.label({ Text = 'Lv. <font color="#FFCE3C">' .. card.level .. "</font>", RichText = true, Size = UDim2.fromOffset(60, 18), Position = UDim2.fromOffset(8, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26 }, c)
			if card.equipped then
				-- equipped marker overhangs the top-right corner (text chip, no emoji)
				local e = Theme.label({ Text = "E", Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 6), BackgroundTransparency = 0, BackgroundColor3 = W.GREEN, ZIndex = 28 }, c)
				Shape.apply(e, { radius = 5, fill = W.GREEN, transparency = 0, edge = Theme.darkEdge(W.GREEN), thickness = 3, gradient = false })
				Shape.tooltip(e, "Equipped", W.GREEN)
			end
			if locks.isLocked(card.uid) then
				Theme.label({ Text = "LOCKED", Size = UDim2.fromOffset(50, 14), Position = UDim2.new(1, -56, 0, 28), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = W.YELLOW, ZIndex = 26 }, c)
			end
			local ts = Theme.make("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(6, 28), BackgroundColor3 = Theme.OUTLINE, ZIndex = 26 }, c)
			Shape.apply(ts, { radius = 4, edge = card.trait and W.YELLOW or U.BORDER, thickness = 2, gradient = false })
			Shape.iconSlot({ Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 27 }, ts)
			Shape.tooltip(ts, card.trait and card.trait.name or "No trait", card.trait and W.YELLOW or U.BORDER)
			-- name: big, bottom-right, over the portrait
			Theme.label({ Text = card.name, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 1, -26), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 26 }, c)
			c.Activated:Connect(function()
				selected = card.uid
				render()
			end)
		end
		if found then
			openDetail(found)
		else
			selected = nil
			detail.Visible = false
		end
	end

	player:GetAttributeChangedSignal("Inventory"):Connect(function()
		Log.try("Inventory", "render", render)
	end)
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible then -- closing (X / Esc / another panel) resets to the grid
			view.Visible, selected = false, nil
			showGrid(true)
			Log.try("Inventory", "render", render)
		end
	end)
	Log.try("Inventory", "render", render)
end

return InventoryUI
