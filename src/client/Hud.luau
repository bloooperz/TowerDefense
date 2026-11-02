-- Match HUD: wave + enemies bar, base HP bar, countdown/vote, cash, unit list.
-- Reads attributes on ReplicatedStorage.MatchInfo (set by the server).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Units = require(RS.Shared.Units)
local Style = require(script.Parent.Style)
local MyUnits = require(script.Parent.MyUnits)

local Hud = {}
local player = Players.LocalPlayer
local info, ui = nil, {}
local localState = "lobby"
Hud.onVote = nil
Hud.onUnitClicked = nil -- function(unitPart)

local function refresh()
	local onMap = localState ~= "lobby"
	ui.top.Visible = onMap
	ui.cash.Visible = onMap
	ui.units.Visible = onMap
	if not onMap then
		return
	end
	local ms = info:GetAttribute("MatchState")
	local wave = info:GetAttribute("Wave") or 0
	local total = info:GetAttribute("WaveTotal") or 0
	local left = info:GetAttribute("EnemiesLeft") or 0
	local hp, maxHp = info:GetAttribute("BaseHP") or 0, info:GetAttribute("BaseMaxHP") or 1

	if ms == "waiting" then
		ui.wave.Text = "Starting in " .. (info:GetAttribute("Countdown") or 0) .. "s"
		ui.enemyFill.Size = UDim2.fromScale(1, 1)
		ui.enemyLabel.Text = "Place your units!"
	elseif ms == "over" then
		ui.wave.Text = "Match over"
	else
		local maxW = info:GetAttribute("MaxWaves") or 0
		ui.wave.Text = "Wave " .. wave .. (maxW > 0 and ("/" .. maxW) or "")
		ui.enemyFill.Size = UDim2.fromScale(total > 0 and left / total or 0, 1)
		ui.enemyLabel.Text = left .. " enemies left"
	end
	ui.hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	ui.hpLabel.Text = "HP " .. math.max(hp, 0) .. "/" .. maxHp

	local voted = player:GetAttribute("Voted")
	ui.vote.Visible = (ms == "waiting")
	ui.vote.Text = (voted and "Ready  " or "Vote Start  ")
		.. (info:GetAttribute("Votes") or 0) .. "/" .. (info:GetAttribute("InMatch") or 0)
	ui.vote.BackgroundColor3 = voted and Style.GREY or Style.GREEN
end

local function refreshUnits()
	if not ui.units.Visible then
		return
	end
	for _, c in ipairs(ui.unitList:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for _, p in ipairs(MyUnits.list()) do
		local u = Units.get(p:GetAttribute("UnitType"))
		if u then
			local b = Style.make("TextButton", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Style.MID,
				Font = Style.FONT,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = u.name .. "  Lv " .. (p:GetAttribute("Level") or 1),
			}, ui.unitList)
			Style.shape(b, 5)
			b.MouseButton1Click:Connect(function()
				if Hud.onUnitClicked then
					Hud.onUnitClicked(p)
				end
			end)
		end
	end
end

function Hud.init(cashValue)
	info = RS:WaitForChild("MatchInfo")
	local screen = Style.make("ScreenGui", { Name = "Hud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

	-- TOP CENTER
	ui.top = Style.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(360, 104),
		Visible = false,
	}, screen)
	ui.wave = Style.text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 30) }, ui.top)
	local _, ef, el = Style.bar({ Position = UDim2.new(0, 14, 0, 42), Size = UDim2.new(1, -28, 0, 22) }, Style.RED, ui.top)
	ui.enemyFill, ui.enemyLabel = ef, el
	local _, hf, hl = Style.bar({ Position = UDim2.new(0, 14, 0, 70), Size = UDim2.new(1, -28, 0, 22) }, Style.GREEN, ui.top)
	ui.hpFill, ui.hpLabel = hf, hl

	ui.vote = Style.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromOffset(240, 46),
		BackgroundColor3 = Style.GREEN,
		Font = Style.FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, ui.top)
	Style.button(ui.vote, Style.GREEN)
	Style.make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, ui.vote)
	ui.vote.MouseButton1Click:Connect(function()
		if Hud.onVote then
			Hud.onVote()
		end
	end)

	-- BOTTOM CENTER CASH (above hotbar)
	ui.cash = Style.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(260, 44),
		TextColor3 = Style.YELLOW,
		Visible = false,
	}, screen)
	local function cashText()
		ui.cash.Text = "$" .. cashValue.Value
	end
	cashValue.Changed:Connect(cashText)
	cashText()

	-- RIGHT SIDE UNIT LIST
	ui.units = Style.panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(180, 260),
		Visible = false,
	}, screen)
	Style.text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 24), Text = "Units" }, ui.units)
	ui.unitList = Style.make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 36),
		Size = UDim2.new(1, -20, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, ui.units)
	Style.make("UIListLayout", { Padding = UDim.new(0, 4) }, ui.unitList)

	info.AttributeChanged:Connect(refresh)
	player:GetAttributeChangedSignal("Voted"):Connect(refresh)
	task.spawn(function()
		while true do
			refreshUnits()
			task.wait(0.5)
		end
	end)
	refresh()
end

function Hud.setState(s)
	localState = s
	if ui.top then
		refresh()
		refreshUnits()
	end
end

return Hud
