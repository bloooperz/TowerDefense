-- Summon panel (built into the existing panels.Summon; gold circle + F already open it).
-- Shows the current standard banner (rotates every Summon.BANNER.PERIOD s, same on every
-- server), countdown, pity, x1/x10/x50 buttons (Gems), Rates popup, and a card-row results popup
-- (cards pop in left -> right in a dark band; Settings > Skip summon animation -> all at once). Server does all validation/rolling.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Summon = require(Shared.Summon)
local SummonReveal = require(Shared.SummonReveal)
local Traits = require(Shared.Traits)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Shape = require(UI.Shape)
local Card = require(UI.Card)
local Rates = require(UI.Rates)
local Toast = require(script.Parent.Parent.Toast)
local ClientSettings = require(script.Parent.Parent.Settings.ClientSettings)

local log = Log.new("SummonUI")
local player = Players.LocalPlayer
local W = Theme.World
local SummonUI = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function SummonUI.build(panel)
	-- FULL-SCREEN summon view (own design): warm/purple gradient backdrop with faint diagonal
	-- streaks, title + banner + timer top-left, featured units large in the center, pity
	-- bottom-left, gems + x1/x10/x50 bottom-right, Panel's X top-right. Lobby HUD hides meanwhile.
	local root = panel.root
	root.Size, root.Position, root.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	panel.body.Visible = false
	local tb = root:FindFirstChild("TitleBanner")
	if tb then
		tb.Visible = false -- replaced by the top-left title block
	end
	local bg = Theme.make("Frame", { Name = "Backdrop", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 20 }, root)
	Theme.make("UIGradient", { Rotation = 30, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 14, 64)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 36, 96)), ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 112, 44)) }) }, bg)
	for k = 1, 7 do
		Theme.make("Frame", { Name = "Decor", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(k / 8, 0.5), Size = UDim2.new(0, 10 + (k % 3) * 14, 1.6, 0), Rotation = 24, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.93, ZIndex = 20 }, bg)
	end
	local floor = Theme.make("Frame", { Name = "Stage", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.8, 0.14), BackgroundColor3 = Color3.fromRGB(255, 200, 120), ZIndex = 20 }, bg)
	Theme.make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }) }, floor)

	local title = Theme.label({ Text = "Summon", Size = UDim2.fromOffset(320, 56), Position = UDim2.fromOffset(28, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, root)
	Shape.outlineText(title, 3)
	Theme.label({ Text = "Standard Banner", Size = UDim2.fromOffset(320, 30), Position = UDim2.fromOffset(30, 76), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.YELLOW, ZIndex = 22 }, root)
	local info = Theme.label({ Size = UDim2.fromOffset(320, 24), Position = UDim2.fromOffset(30, 108), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY, TextColor3 = W.TEXT, ZIndex = 22 }, root)

	-- featured units: large static 3D models (ViewportFrames), name + rarity under each
	local cards = Theme.make("Frame", { Name = "Featured", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.72, 0.5), ZIndex = 21 }, root)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }, cards)
	local function featuredSlot(def, order, big)
		local rc = Config.RARITY_COLORS[def.rarity] or W.BORDER
		local slot = Theme.make("Frame", { Name = "Slot" .. order, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromScale(big and 0.34 or 0.26, big and 1 or 0.82), ZIndex = 21 }, cards)
		local vp = Card.portrait(def, slot)
		vp.Name, vp.BackgroundTransparency, vp.BorderSizePixel, vp.ZIndex = "Model", 1, 0, 22
		vp.Size = UDim2.new(1, 0, 1, -64)
		local plate = Theme.make("Frame", { Name = "Plate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0.9, 0, 0, 58), BackgroundColor3 = Theme.Unit.BASE, ZIndex = 22 }, slot)
		Shape.apply(plate, { radius = 6, fill = Theme.Unit.BASE, transparency = 0.15, edge = rc, thickness = big and 3 or 2, gradient = false })
		Theme.label({ Text = def.name, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 4), ZIndex = 23 }, plate)
		Theme.label({ Text = def.rarity or "Common", Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 34), TextColor3 = rc, ZIndex = 23 }, plate)
	end
	local function rank(id)
		local d = Units.get(id)
		return d and table.find(Summon.RARITIES, d.rarity) or 0
	end

	-- pity progress bottom-left (+ Rates above it)
	local pityBox = Theme.make("Frame", { Name = "Pity", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -24), Size = UDim2.fromOffset(360, 66), BackgroundColor3 = Theme.Unit.BASE, ZIndex = 22 }, root)
	Shape.apply(pityBox, { radius = 6, fill = Theme.Unit.BASE, transparency = 0.2, edge = W.YELLOW, thickness = 3, gradient = false })
	local pityText = Theme.label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.YELLOW, ZIndex = 23 }, pityBox)
	local pityBar = Theme.make("Frame", { Name = "PityBar", Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 16), BackgroundColor3 = Color3.fromRGB(30, 24, 30), ZIndex = 23 }, pityBox)
	Shape.apply(pityBar, { radius = 4, fill = Color3.fromRGB(30, 24, 30), transparency = 0, edge = Color3.fromRGB(10, 8, 10), thickness = 2, gradient = false })
	local pityFill = Theme.make("Frame", { Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), BackgroundColor3 = W.YELLOW, ZIndex = 24 }, pityBar)

	-- gem balance bottom-right, above the summon row
	local gems = Theme.label({ Name = "Gems", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -SummonReveal.ROW_MARGIN, 1, -(SummonReveal.ROW_MARGIN + SummonReveal.ROW_H + 8)), Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(90, 200, 255), ZIndex = 22 }, root)
	local function updGems()
		gems.Text = ("Gems: %d"):format(player:GetAttribute("Gems") or 0)
	end
	player:GetAttributeChangedSignal("Gems"):Connect(updGems)
	updGems()

	local SR = SummonReveal
	local ROW_W = #Summon.TIERS * SR.BTN_W + (#Summon.TIERS - 1) * 10
	local row = Theme.make("Frame", { Name = "SummonRow", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -SR.ROW_MARGIN, 1, -SR.ROW_MARGIN), Size = UDim2.fromOffset(ROW_W, SR.ROW_H), BackgroundTransparency = 1, ZIndex = 22 }, root)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local busy, lastSent = false, nil
	local clicks = SummonReveal.clicks()
	local showing, dismiss = function() return false end, function() end -- set once the popup exists
	for i, tier in ipairs(Summon.TIERS) do
		local cost = tier * Summon.COST_PER_ROLL
		local b = Theme.make("TextButton", { Text = SR.buttonText(tier, cost), Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = W.BORDER_HOT, AutoButtonColor = false, Size = UDim2.fromOffset(SR.BTN_W, SR.ROW_H), LayoutOrder = i, ZIndex = 23 }, row)
		Theme.button(b, Theme.COLORS.Summon)
		Shape.outlineText(b, 2)
		Theme.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, b)
		b.Activated:Connect(function()
			if clicks.summonClick(showing()) == "dismiss" then
				dismiss()
				return
			end
			if busy or not Summon.cooldownReady(lastSent, os.clock()) then
				return -- buttons inert for Summon.COOLDOWN after a summon (server enforces too)
			end
			if (player:GetAttribute("Gems") or 0) < cost then
				Toast.show(("Not enough Gems (need %d)"):format(cost), "error")
				return
			end
			busy, lastSent = true, os.clock()
			task.delay(1.5, function()
				busy = false -- re-armed by result too; this only covers a lost reply
			end)
			Net.send("Summon", tier)
		end)
	end
	Rates.button(root, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -100), Size = UDim2.fromOffset(110, 36), ZIndex = 24 })

	-- Results popup: dark horizontal BAND across the middle (summon screen faintly visible above,
	-- below and through it), cards pop in left -> right with a flame effect. Purely visual.
	local gui = root.Parent
	local pop = Theme.make("Frame", { Name = "SummonReveal", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Active = true, ZIndex = 60 }, gui)
	local band = Theme.make("Frame", { Name = "Band", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -SR.BAR / 2), Size = UDim2.new(1, 0, SR.BAND_SCALE, -SR.BAR), BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.2, ZIndex = 61 }, pop)
	local head = Theme.label({ Text = "Rewards obtained", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), ZIndex = 62 }, band)
	Shape.outlineText(head, 2)
	local stage = Theme.make("ScrollingFrame", { Name = "Cards", BorderSizePixel = 0, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 1, -54), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62 }, band)
	Theme.make("UIGridLayout", { CellSize = UDim2.fromOffset(128, 184), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, stage)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, stage)
	local showingResults = false
	local GRADE_COLORS = { C = Color3.fromRGB(170, 170, 180), B = W.GREEN, A = W.BLUE, S = W.YELLOW, SS = W.ORANGE, Z = Color3.fromRGB(255, 60, 120) }

	local function closePop()
		if not pop.Visible then
			return false
		end
		pop.Visible = false
		showingResults = false
		clear(stage)
		return true
	end

	local function small(text, parent, y, h, color, font)
		local l = Theme.label({ Text = text, Size = UDim2.new(1, -8, 0, h), Position = UDim2.fromOffset(4, y), TextColor3 = color or Color3.new(1, 1, 1), Font = font or Theme.FONT, ZIndex = 66 }, parent)
		Shape.outlineText(l, 1)
		return l
	end

	-- flame-like pop-in: card scales up (Back ease) while rarity-colored flickering streaks and a
	-- gradient glow rise around it and fade. All effect frames are destroyed afterwards.
	local function flame(cell, rc)
		local scale = Theme.make("UIScale", { Scale = 0.35 }, cell)
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local glow = Theme.make("Frame", { Name = "Flame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 16, 1, 16), BackgroundColor3 = rc, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 63 }, cell)
		local grad = Theme.make("UIGradient", { Rotation = -90, Color = ColorSequence.new(Color3.new(1, 1, 1), rc), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0) }) }, glow)
		TweenService:Create(grad, TweenInfo.new(0.5), { Offset = Vector2.new(0, -0.6) }):Play()
		TweenService:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1, Size = UDim2.new(1, 28, 1, 40) }):Play()
		for k = 1, 5 do
			local st = Theme.make("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(k / 6, 0, 1, 6), Size = UDim2.new(0, 6, 0.35, 0), BackgroundColor3 = rc, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 64 }, cell)
			Theme.make("UIGradient", { Rotation = -90, Transparency = NumberSequence.new(0, 1) }, st)
			local dur = 0.3 + (k % 3) * 0.08 -- uneven = flicker
			TweenService:Create(st, TweenInfo.new(dur, Enum.EasingStyle.Quad), { Position = UDim2.new(k / 6, (k % 2 == 0) and 4 or -4, 0.1, 0), Size = UDim2.new(0, 3, 0.55, 0), BackgroundTransparency = 1 }):Play()
		end
		task.delay(0.7, function()
			for _, c in ipairs(cell:GetChildren()) do
				if c.Name == "Flame" or c.Name == "Streak" then
					c:Destroy()
				end
			end
		end)
	end

	-- one 2D card: rounded, thick rarity border, neutral fill, static model clipped inside.
	local function resultCard(m, def, parent)
		local rc = Config.RARITY_COLORS[m.rarity] or Theme.Unit.BORDER
		local cell = Theme.make("Frame", { Name = "Cell" .. m.order, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = m.order, Visible = false, ZIndex = 63 }, parent)
		local c = Theme.make("Frame", { Name = "ResultCard", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Unit.BASE, ClipsDescendants = true, ZIndex = 65 }, cell)
		Shape.apply(c, { radius = 6, fill = Theme.Unit.BASE, transparency = 0, edge = rc, thickness = 3, gradient = false })
		local vp = Card.portrait(def, c) -- static, not rotatable: fixed 3/4 camera angle
		vp.Name, vp.ZIndex, vp.BorderSizePixel = "Model", 66, 0
		vp.Position, vp.Size = UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 86)
		small(m.rarity, c, 92, 16, rc)
		small(m.name, c, 108, 20)
		local st = {}
		for _, s in ipairs(m.stats) do
			table.insert(st, s.value)
		end
		small(#st > 0 and ("DMG " .. (st[1] or "-") .. "  CD " .. (st[2] or "-") .. "  RNG " .. (st[3] or "-")) or "", c, 130, 14, Theme.Unit.MUTED, Theme.BODY)
		local y = 146
		if m.trait then
			small("Trait: " .. m.trait.name, c, y, 14, W.BLUE, Theme.BODY)
			y += 16
		end
		if m.grades then
			local g = {}
			for _, gr in ipairs(m.grades) do
				table.insert(g, gr.label:sub(1, 3) .. " " .. gr.grade)
			end
			small(table.concat(g, "  "), c, y, 14, GRADE_COLORS[m.grades[1].grade] or W.YELLOW, Theme.BODY)
		end
		if m.soldText then
			local tag = Theme.make("Frame", { Name = "SoldTag", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 34), BackgroundColor3 = W.RED, ZIndex = 68 }, c)
			Theme.button(tag, W.RED)
			Theme.label({ Text = m.soldText, Size = UDim2.fromScale(1, 1), ZIndex = 69, Font = Theme.BODY }, tag)
		end
		return cell, rc
	end

	local revealToken = 0
	local function showResults(res)
		local list = res.results or {}
		local kept, sold = 0, 0
		for _, r in ipairs(list) do
			if r.sold then
				sold += 1
			else
				kept += 1
			end
		end
		local s = ClientSettings.get() or {}
		local vm = SummonReveal.layout(list, s.skipSummonAnim == true, Units.get, Traits.byId)
		clear(stage)
		revealToken += 1
		local my = revealToken
		showingResults = not vm.empty
		pop.Visible = showingResults
		for _, m in ipairs(vm.cards) do
			local cell, rc = resultCard(m, Units.get(list[m.order].unitId), stage)
			task.delay(m.delay, function()
				if my ~= revealToken or not cell.Parent then
					return
				end
				cell.Visible = true
				if m.flame then
					Log.try("SummonUI", "flame", flame, cell, rc)
				end
			end)
		end
		Toast.show(("Summoned %d: kept %d, auto-sold %d (+%d Gold)"):format(#list, kept, sold, res.back or 0), "info")
	end

	-- The popup is a full-screen Active frame above the panel; while it shows, the summon row is
	-- lifted INTO its dedicated bottom bar (bottom-right, below the band: SR.rowRect never meets
	-- SR.bandRect) so x1/x10/x50 stay visible and clickable; it goes back on close.
	local rowHome = { parent = row.Parent, pos = row.Position, anchor = row.AnchorPoint, z = row.ZIndex }
	local function liftRow(on)
		if on and row.Parent ~= pop then
			row.Parent, row.AnchorPoint, row.ZIndex = pop, Vector2.new(1, 1), 80
			row.Position = UDim2.new(1, -SR.ROW_MARGIN, 1, -SR.ROW_MARGIN)
		elseif not on and row.Parent == pop then
			row.Parent, row.Position, row.AnchorPoint, row.ZIndex = rowHome.parent, rowHome.pos, rowHome.anchor, rowHome.z
		end
	end

	-- Lobby HUD (side hotkey panels, events banner, currencies/hotbar) is hidden while the summon
	-- screen is open so nothing collides with it; restored exactly as it was on close.
	local hidden = {}
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			for _, c in ipairs(gui:GetChildren()) do
				if c:IsA("GuiObject") and c ~= root and c ~= pop and c.Visible then
					hidden[c], c.Visible = true, false
				end
			end
		else
			closePop()
			for c in pairs(hidden) do
				if c.Parent then
					c.Visible = true
				end
			end
			hidden = {}
		end
	end)
	showing = function()
		return pop.Visible and showingResults
	end
	dismiss = function()
		closePop()
	end
	pop:GetPropertyChangedSignal("Visible"):Connect(function()
		liftRow(pop.Visible)
	end)
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local function classify(pos)
		for _, o in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
			if o:IsDescendantOf(pop) then
				if o.Name == "ResultCard" or o:IsA("ViewportFrame") then
					return "model" -- clicking a card doesn't dismiss
				elseif o:IsA("GuiButton") then
					return "button" -- summon row acts on its own
				end
			end
		end
		return "other"
	end
	UserInputService.InputBegan:Connect(function(i)
		if isPress(i) and showing() then
			clicks.press(classify(i.Position))
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if isPress(i) and clicks.release(showing()) then
			Log.try("SummonUI", "dismiss reveal", closePop)
		end
	end)
	panel.onEsc = closePop -- Esc closes the results first, then the panel

	Net.listen("SummonResult", function(res)
		busy = false
		Log.try("SummonUI", "show results", showResults, res)
	end)

	-- Banner + countdown + pity (cheap: rebuild cards only when the window changes).
	local shownWindow = nil
	local function tick()
		local t = now()
		local w = Summon.window(t)
		if w ~= shownWindow then
			shownWindow = w
			clear(cards)
			local banner = Summon.banner(w, Units.list)
			for i, f in ipairs(SummonReveal.featured(banner.units, rank)) do
				local def = Units.get(f.id)
				if def then
					featuredSlot(def, i, f.emphasized)
				end
			end
		end
		local left = math.max(0, math.floor(Summon.secondsLeft(t)))
		info.Text = ("Rotates in %02d:%02d"):format(left // 60, left % 60)
		local _, top = Summon.effectiveRates(Summon.banner(w, Units.list))
		local pity = player:GetAttribute("SummonPity") or 0
		pityText.Text = ("Pity %d / %d  -  %s guaranteed"):format(pity, Summon.PITY_THRESHOLD, top or "?")
		pityFill.Size = UDim2.fromScale(math.clamp(pity / Summon.PITY_THRESHOLD, 0, 1), 1)
	end
	task.spawn(function()
		while root.Parent do
			if root.Visible then
				Log.try("SummonUI", "tick", tick)
			end
			task.wait(1)
		end
	end)
	player:GetAttributeChangedSignal("SummonPity"):Connect(function()
		Log.try("SummonUI", "tick", tick)
	end)
	log.info("summon panel built")
end

return SummonUI
