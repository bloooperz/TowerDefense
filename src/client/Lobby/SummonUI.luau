-- Summon panel (built into the existing panels.Summon; gold circle + F already open it).
-- Shows the current standard banner (rotates every Summon.BANNER.PERIOD s, same on every
-- server), countdown, pity, x1/x10/x50 buttons (Gems), Rates popup, and a card reveal with
-- Skip (Settings > Summon > Skip summon animation). Server does all validation/rolling.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Summon = require(Shared.Summon)
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
	panel.root.Size = UDim2.fromOffset(640, 440)
	panel.body.Visible = false
	local root = panel.root

	local info = Theme.label({ Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 56), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY, TextColor3 = W.TEXT, ZIndex = 22 }, root)
	local cards = grid(root, { Position = UDim2.fromOffset(20, 88), Size = UDim2.new(1, -40, 0, 116) })
	local pityText = Theme.label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 212), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY, TextColor3 = W.YELLOW, ZIndex = 22 }, root)

	local row = Theme.make("Frame", { Position = UDim2.fromOffset(20, 244), Size = UDim2.new(1, -40, 0, 48), BackgroundTransparency = 1, ZIndex = 22 }, root)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local busy = false
	for i, tier in ipairs(Summon.TIERS) do
		local cost = tier * Summon.COST_PER_ROLL
		local b = Theme.make("TextButton", { Text = ("Summon x%d  (%d Gems)"):format(tier, cost), Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = W.BORDER_HOT, AutoButtonColor = false, Size = UDim2.fromOffset(170, 44), LayoutOrder = i, ZIndex = 23 }, row)
		Theme.button(b, Theme.COLORS.Summon)
		Shape.outlineText(b, 2)
		Theme.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		b.Activated:Connect(function()
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

	-- Reveal overlay (results). Cards pop in one by one unless skipped.
	local reveal = Theme.make("Frame", { Size = UDim2.new(1, -40, 0, 128), Position = UDim2.fromOffset(20, 300), BackgroundColor3 = W.BASE_2, ZIndex = 22 }, root)
	Theme.panel(reveal, W.BORDER)
	local revealGrid = grid(reveal, { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -110, 1, -16) }, UDim2.fromOffset(70, 84))
	local summary = Theme.label({ Text = "Results appear here", Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(8, 54), Font = Theme.BODY, TextColor3 = W.MUTED, ZIndex = 23 }, reveal)
	local skip = Theme.make("TextButton", { Text = "Skip", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = W.BLUE, AutoButtonColor = false, Size = UDim2.fromOffset(86, 36), Position = UDim2.new(1, -96, 0.5, -18), Visible = false, ZIndex = 24 }, reveal)
	Theme.button(skip, W.BLUE)
	local token = 0

	local function resultCard(r, order, parent)
		local def = Units.get(r.unitId)
		local c = Card.new(def, 1, parent)
		c.LayoutOrder = order
		if r.sold then
			local tag = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundColor3 = W.RED, ZIndex = 8 }, c)
			Theme.button(tag, W.RED)
			Theme.label({ Text = ("Auto-sold +%d"):format(r.sold), Size = UDim2.fromScale(1, 1), ZIndex = 9, Font = Theme.BODY }, tag)
		end
		return c
	end

	local function showResults(res)
		token += 1
		local my = token
		clear(revealGrid)
		summary.Visible = false
		local kept, sold = 0, 0
		for _, r in ipairs(res.results or {}) do
			if r.sold then
				sold += 1
			else
				kept += 1
			end
		end
		local s = ClientSettings.get() or {}
		local animate = not s.skipSummonAnim
		skip.Visible = animate
		local list = res.results or {}
		local placed = 0
		local function finish()
			for i = placed + 1, #list do
				resultCard(list[i], i, revealGrid)
			end
			placed = #list
			skip.Visible = false
			Toast.show(("Summoned %d: kept %d, auto-sold %d (+%d Gold)"):format(#list, kept, sold, res.back or 0), "info")
		end
		if not animate then
			finish()
			return
		end
		task.spawn(function()
			for i, r in ipairs(list) do
				if token ~= my or placed >= #list then
					return
				end
				local c = resultCard(r, i, revealGrid)
				placed = i
				local sc = Theme.make("UIScale", { Scale = 0.2 }, c)
				TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				local rk = Summon.rank(r.rarity)
				task.wait(rk >= Summon.rank("Epic") and 0.45 or 0.12)
			end
			if token == my then
				finish()
			end
		end)
		skip.Activated:Once(function()
			if token == my and placed < #list then
				token += 1 -- stop the animation loop
				finish()
			end
		end)
	end

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
