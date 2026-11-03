-- Summon panel (built into the existing panels.Summon; gold circle + F already open it).
-- Shows the current standard banner (rotates every Summon.BANNER.PERIOD s, same on every
-- server), countdown, pity, x1/x10/x50 buttons (Gems), Rates popup, and a full-screen reveal
-- (one unit at a time, Next/Space, Skip -> summary; Settings > Skip summon animation -> summary). Server does all validation/rolling.
local Players = game:GetService("Players")
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
local Spin = require(UI.Spin)
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
	local busy = false
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
			if busy then
				return
			end
			if (player:GetAttribute("Gems") or 0) < cost then
				Toast.show(("Not enough Gems (need %d)"):format(cost), "error")
				return
			end
			busy = true
			task.delay(1.5, function()
				busy = false -- re-armed by result too; this only covers a lost reply
			end)
			Net.send("Summon", tier)
		end)
	end
	Rates.button(root, { Position = UDim2.new(1, -110, 0, 212), ZIndex = 24 })

	local function resultCard(r, order, parent)
		local def = Units.get(r.unitId)
		local c = Card.new(def, 1, parent)
		c.LayoutOrder = order
		if r.sold then
			local tag = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundColor3 = W.RED, ZIndex = 8 }, c)
			Theme.button(tag, W.RED)
			Theme.label({ Text = ("Auto-sold +%d Gold"):format(r.sold), Size = UDim2.fromScale(1, 1), ZIndex = 9, Font = Theme.BODY }, tag)
		end
		return c
	end

	-- Full-screen reveal popup (client display only). Sections come from shared/SummonReveal.
	local gui = root.Parent
	local pop = Theme.make("Frame", { Name = "SummonReveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.25, Visible = false, Active = true, ZIndex = 60 }, gui)
	local stage = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 61 }, pop)
	local seq, list = nil, {}

	local function bigBtn(text, color, parent, props)
		local b = Theme.make("TextButton", { Text = text, Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = color, AutoButtonColor = false, ZIndex = 66 }, parent)
		for k, v in pairs(props) do
			b[k] = v
		end
		Theme.button(b, color)
		Shape.outlineText(b, 2)
		Theme.make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		return b
	end
	local function line(text, parent, order, props)
		local l = Theme.label({ Text = text, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 64 }, parent)
		for k, v in pairs(props or {}) do
			l[k] = v
		end
		Shape.outlineText(l, 2)
		return l
	end
	local function section(title, parent, order)
		line(title, parent, order, { TextColor3 = W.MUTED, Size = UDim2.new(1, 0, 0, 20) })
		local row = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 63 }, parent)
		Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		return row
	end
	local function chip(top, bottom, parent, order, edge)
		local c = Theme.make("Frame", { Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = order, ZIndex = 64 }, parent)
		Shape.apply(c, { radius = 6, fill = Theme.Unit.BASE, transparency = 0, edge = edge or Theme.Unit.BORDER, thickness = 3, gradient = false })
		Theme.label({ Text = top, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 3), ZIndex = 65, TextColor3 = edge or Color3.new(1, 1, 1) }, c)
		Theme.label({ Text = bottom, Font = Theme.BODY, TextColor3 = Theme.Unit.MUTED, Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 1, -18), ZIndex = 65 }, c)
	end
	local GRADE_COLORS = { C = Color3.fromRGB(170, 170, 180), B = W.GREEN, A = W.BLUE, S = W.YELLOW, SS = W.ORANGE, Z = Color3.fromRGB(255, 60, 120) }

	local function closePop()
		if not pop.Visible then
			return false
		end
		pop.Visible = false
		clear(stage)
		seq, list = nil, {}
		return true
	end

	local render
	local function showOne(r)
		local def = Units.get(r.unitId)
		local m = SummonReveal.card(r, def, Traits.byId)
		local rc = Config.RARITY_COLORS[m.rarity] or Theme.Unit.BORDER
		-- model presented directly: transparent viewport, no card frame
		local vp = Card.portrait(def, stage)
		vp.BackgroundTransparency, vp.ZIndex = 1, 62
		vp.AnchorPoint, vp.Position, vp.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.3, 0.47), UDim2.fromScale(0.42, 0.7)
		local model = vp:FindFirstChildWhichIsA("Model")
		if model then
			Spin.attach(vp, model, { autoRotate = 0.5 })
		end
		local col = Theme.make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.54, 0.45), Size = UDim2.new(0.38, 0, 0, 420), BackgroundTransparency = 1, ZIndex = 63 }, stage)
		Theme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, col)
		line(m.rarity, col, 1, { TextColor3 = rc, Size = UDim2.new(1, 0, 0, 30) })
		line(m.name, col, 2, { Size = UDim2.new(1, 0, 0, 48) })
		if m.soldText then
			local tag = Theme.make("Frame", { Size = UDim2.fromOffset(220, 32), BackgroundColor3 = W.RED, LayoutOrder = 3, ZIndex = 64 }, col)
			Theme.button(tag, W.RED)
			Theme.label({ Text = m.soldText, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), ZIndex = 65 }, tag)
		end
		local stats = section("Base stats", col, 10)
		for i, st in ipairs(m.stats) do
			chip(st.value, st.label, stats, i)
		end
		if m.trait then
			local t = section("Trait", col, 20)
			local tc = Theme.make("Frame", { Size = UDim2.new(1, 0, 1, 0), ZIndex = 64 }, t)
			Shape.apply(tc, { radius = 6, fill = Theme.Unit.BASE, transparency = 0, edge = W.BLUE, thickness = 3, gradient = false })
			Shape.iconSlot({ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 12), ZIndex = 65 }, tc)
			Theme.label({ Text = m.trait.name, Size = UDim2.new(0.4, 0, 0, 26), Position = UDim2.fromOffset(46, 13), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = W.BLUE, ZIndex = 65 }, tc)
			Theme.label({ Text = m.trait.desc, Font = Theme.BODY, TextScaled = false, TextSize = 14, TextWrapped = true, TextColor3 = Theme.Unit.MUTED, Size = UDim2.new(0.6, -56, 1, -8), Position = UDim2.new(0.4, 50, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 65 }, tc)
		end
		if m.grades then
			local g = section("Stat rolls", col, 30)
			for i, gr in ipairs(m.grades) do
				chip(gr.grade, gr.label, g, i, GRADE_COLORS[gr.grade])
			end
		end
		local bar = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(460, 50), BackgroundTransparency = 1, ZIndex = 63 }, stage)
		Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
		Theme.label({ Text = seq.counter(), Size = UDim2.fromOffset(90, 30), LayoutOrder = 1, ZIndex = 64 }, bar)
		bigBtn("Next  [Space]", W.YELLOW, bar, { Size = UDim2.fromOffset(170, 46), LayoutOrder = 2 }).Activated:Connect(function()
			seq.next()
			render()
		end)
		if seq.showSkip() then
			bigBtn("Skip", W.BLUE, bar, { Size = UDim2.fromOffset(120, 46), LayoutOrder = 3 }).Activated:Connect(function()
				seq.skip()
				render()
			end)
		end
	end

	local function showSummary()
		local box = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 470), ZIndex = 62 }, stage)
		Theme.panel(box, W.BORDER)
		Theme.label({ Text = ("Summon results  -  %d"):format(#list), Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(20, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 63 }, box)
		local g = grid(box, { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 1, -128), ZIndex = 63 })
		for i, r in ipairs(list) do
			resultCard(r, i, g)
		end
	end

	render = function()
		clear(stage)
		if not seq then
			return
		end
		if seq.mode == "reveal" then
			showOne(seq.current())
		elseif seq.mode == "summary" then
			showSummary()
		else
			closePop()
		end
	end

	local function showResults(res)
		list = res.results or {}
		local kept, sold = 0, 0
		for _, r in ipairs(list) do
			if r.sold then
				sold += 1
			else
				kept += 1
			end
		end
		local s = ClientSettings.get() or {}
		seq = SummonReveal.sequence(list, s.skipSummonAnim == true)
		pop.Visible = seq.mode ~= "empty"
		render()
		Toast.show(("Summoned %d: kept %d, auto-sold %d (+%d Gold)"):format(#list, kept, sold, res.back or 0), "info")
	end

	-- The popup is a full-screen Active frame above the panel, so it used to swallow clicks on the
	-- summon buttons. While it shows, the button row is lifted INTO the popup (same screen spot,
	-- top ZIndex) so x1/x10/x50 stay visible and clickable; it goes back on close.
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
		return pop.Visible and seq ~= nil
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
				if o:IsA("ViewportFrame") then
					return "model"
				elseif o:IsA("GuiButton") then
					return "button" -- Next/Skip/summon row act on their own
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
	panel.onEsc = closePop -- Esc closes the reveal first, then the panel
	UserInputService.InputBegan:Connect(function(i, gpe)
		if not gpe and i.KeyCode == Enum.KeyCode.Space and pop.Visible and seq and seq.mode == "reveal" then
			seq.next()
			Log.try("SummonUI", "reveal next", render)
		end
	end)

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
