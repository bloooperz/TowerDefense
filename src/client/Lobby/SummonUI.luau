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

local function grid(parent, props, cell)
	local f = Theme.make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, parent)
	for k, v in pairs(props) do
		f[k] = v
	end
	Theme.make("UIGridLayout", { CellSize = cell or UDim2.fromOffset(86, 104), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, f)
	return f
end

function SummonUI.build(panel)
	panel.root.Size = UDim2.fromOffset(640, 310)
	panel.body.Visible = false
	local root = panel.root

	local info = Theme.label({ Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 56), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY, TextColor3 = W.TEXT, ZIndex = 22 }, root)
	local cards = grid(root, { Position = UDim2.fromOffset(20, 88), Size = UDim2.new(1, -40, 0, 116) })
	local pityText = Theme.label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 212), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY, TextColor3 = W.YELLOW, ZIndex = 22 }, root)

	local row = Theme.make("Frame", { Position = UDim2.fromOffset(20, 244), Size = UDim2.new(1, -40, 0, 48), BackgroundTransparency = 1, ZIndex = 22 }, root)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local busy, lastSent = false, nil
	local clicks = SummonReveal.clicks()
	local showing, dismiss = function() return false end, function() end -- set once the popup exists
	for i, tier in ipairs(Summon.TIERS) do
		local cost = tier * Summon.COST_PER_ROLL
		local b = Theme.make("TextButton", { Text = ("Summon x%d  (%d Gems)"):format(tier, cost), Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = W.BORDER_HOT, AutoButtonColor = false, Size = UDim2.fromOffset(170, 44), LayoutOrder = i, ZIndex = 23 }, row)
		Theme.button(b, Theme.COLORS.Summon)
		Shape.outlineText(b, 2)
		Theme.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
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
	Rates.button(root, { Position = UDim2.new(1, -110, 0, 212), ZIndex = 24 })

	-- Results popup: dark horizontal BAND across the middle (summon screen faintly visible above,
	-- below and through it), cards pop in left -> right with a flame effect. Purely visual.
	local gui = root.Parent
	local pop = Theme.make("Frame", { Name = "SummonReveal", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Active = true, ZIndex = 60 }, gui)
	local band = Theme.make("Frame", { Name = "Band", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.2, ZIndex = 61 }, pop)
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
	-- lifted INTO it (same screen spot, top ZIndex) so x1/x10/x50 stay visible and clickable.
	local rowHome = { parent = row.Parent, pos = row.Position, z = row.ZIndex }
	local function liftRow(on)
		if on and row.Parent ~= pop then
			local a, o = row.AbsolutePosition, pop.AbsolutePosition
			row.Parent, row.Position, row.ZIndex = pop, UDim2.fromOffset(a.X - o.X, a.Y - o.Y), 80
		elseif not on and row.Parent == pop then
			row.Parent, row.Position, row.ZIndex = rowHome.parent, rowHome.pos, rowHome.z
		end
	end
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
			for i, id in ipairs(banner.units) do
				local def = Units.get(id)
				if def then
					Card.new(def, 1, cards).LayoutOrder = i
				end
			end
		end
		local left = math.max(0, math.floor(Summon.secondsLeft(t)))
		info.Text = ("Standard Banner  -  rotates in %02d:%02d"):format(left // 60, left % 60)
		local _, top = Summon.effectiveRates(Summon.banner(w, Units.list))
		pityText.Text = ("Pity %d / %d  -  %s guaranteed at %d"):format(player:GetAttribute("SummonPity") or 0, Summon.PITY_THRESHOLD, top or "?", Summon.PITY_THRESHOLD)
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
