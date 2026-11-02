-- Lobby HUD (built in code, like every other client UI): events banner, left/right icon
-- grids, currencies, loadout cards, level bar. Visible only while not in a match.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Rewards = require(Shared.Rewards)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Card = require(UI.Card)
local MapSelect = require(script.Parent.Parent.MapSelect)
local LobbyFeatures = require(Shared.LobbyFeatures)

local log = Log.new("Lobby")
local player = Players.LocalPlayer
local LobbyUI = {}

local LEFT = {
	{ name = "Inventory", icon = "🎒", key = "I" },
	{ name = "Units", icon = "🧊", key = "K" },
	{ name = "Trade", icon = "🤝", key = "T" },
	{ name = "Summon", icon = "✨", key = "F", isNew = true },
	{ name = "Play", icon = "▶", key = "P" },
}
local RIGHT = {
	{ name = "Quests", icon = "📜", key = "J" },
	{ name = "Battlepass", icon = "🎖", key = "B" },
	{ name = "Profile", icon = "👤", key = "U" },
	{ name = "Friends", icon = "👥", key = "G" },
}
local CURRENCIES = { -- placeholder until Gold/Rerolls exist in DataSchema
	{ attr = "Gems", icon = "💎", color = Color3.fromRGB(90, 200, 255) },
	{ attr = "Gold", icon = "🪙", color = Color3.fromRGB(255, 210, 60) },
	{ attr = "Rerolls", icon = "🎲", color = Color3.fromRGB(200, 120, 255) },
}

local screen, panels, hotbar, levelFill, levelText = nil, {}, nil, nil, nil
local actions, keyMap, keyLabels = {}, {}, {}
local Input = require(script.Parent.Parent.Input)
Input.onChanged(function()
	for name, lbl in pairs(keyLabels) do
		lbl.Text = Input.keyFor(name) or ""
	end
end)

local function openPanel(name)
	panels[name].toggle() -- Panel manager closes whatever else is open
end

-- One panel table for buttons AND lobby circles. Circles open (never toggle-close).
function LobbyUI.openPanel(name)
	local p = panels[name]
	if not p then
		log.warn("no lobby panel named", name)
		return
	end
	if Panel.current() ~= p then
		p.open()
	end
end

-- Lobby circles: open the feature's panel once per entry (step off + back on to reopen).
local function watchCircles()
	local inside, lastOpen = nil, 0
	game:GetService("RunService").Heartbeat:Connect(function()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local f = hrp and screen.Enabled and hrp.Position.Y < 15 and LobbyFeatures.at(hrp.Position) or nil
		local id = f and f.id
		if id == inside then
			return
		end
		inside = id
		if f and os.clock() - lastOpen > 0.5 then
			lastOpen = os.clock()
			Log.try("Lobby", "circle " .. f.id, LobbyUI.openPanel, f.panel)
		end
	end)
end

local function sidePanel(list, anchorX, posX)
	local rows = math.ceil(#list / 2)
	local f = Theme.make("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Position = UDim2.new(posX, anchorX == 0 and 16 or -16, 0.5, 0),
		Size = UDim2.fromOffset(2 * 84 + 3 * 12, rows * 84 + (rows + 1) * 12),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0.25,
	}, screen)
	Theme.round(f, 20)
	Theme.stroke(f, 4)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12) }, f)
	Theme.make("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	for i, def in ipairs(list) do
		local keyName = Input.keyFor(def.name) or def.key
		local h = Button.new({
			name = def.name, icon = def.icon, key = keyName, isNew = def.isNew,
			color = Theme.COLORS[def.name],
			onClick = actions[def.name],
		}, f)
		h.LayoutOrder = i
		keyMap[def.name] = true -- shortcut keys resolved through Input (rebindable)
		for _, d in ipairs(h:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text == keyName and d.Size == UDim2.fromOffset(20, 20) then
				keyLabels[def.name] = d
			end
		end
	end
end

local function eventBanner()
	local holder = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(300, 100), BackgroundTransparency = 1 }, screen)
	-- label sits fully above the card+glow (glow spreads 6px) and on a higher ZIndex
	Theme.label({ Text = "EVENTS", Size = UDim2.new(1, 0, 0, 24), ZIndex = 5, TextColor3 = Color3.fromRGB(255, 230, 120) }, holder)
	local card = Theme.make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Theme.COLORS.Event, ZIndex = 2 }, holder)
	Theme.round(card, 14)
	Theme.stroke(card, 3)
	Theme.gloss(card)
	local glow = Theme.glow(card, Theme.COLORS.Event, 6)
	Theme.label({ Text = "🔥 Shadow Festival", Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 4), ZIndex = 3 }, card)
	Theme.label({ Text = "Ends in 3d 12h (placeholder)", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 38), ZIndex = 3, TextColor3 = Color3.fromRGB(255, 240, 210) }, card)
	-- pulse glow
	TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.25 }):Play()
	card.Activated:Connect(function()
		openPanel("Event")
	end)
end

local function currencies(parent)
	local bar = Theme.make("Frame", { Size = UDim2.fromOffset(420, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, parent)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }, bar)
	for _, c in ipairs(CURRENCIES) do
		local pill = Theme.make("Frame", { Size = UDim2.fromOffset(130, 36), BackgroundColor3 = Theme.PANEL }, bar)
		Theme.round(pill, 18)
		Theme.stroke(pill, 3)
		Theme.make("UIStroke", { Thickness = 1.5, Color = c.color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.2 }, pill)
		Theme.label({ Text = c.icon, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(6, 4), TextStrokeTransparency = 1 }, pill)
		local n = Theme.label({ Size = UDim2.new(1, -44, 0, 26), Position = UDim2.fromOffset(38, 5), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = c.color }, pill)
		local function upd()
			n.Text = tostring(player:GetAttribute(c.attr) or 0)
		end
		player:GetAttributeChangedSignal(c.attr):Connect(upd)
		upd()
	end
end

local function rebuildHotbar()
	for _, ch in ipairs(hotbar:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	local ids, levels = {}, {}
	for id in string.gmatch(player:GetAttribute("Loadout") or "", "[^,]+") do
		table.insert(ids, id)
	end
	for l in string.gmatch(player:GetAttribute("LoadoutLevels") or "", "[^,]+") do
		table.insert(levels, tonumber(l) or 1)
	end
	for i = 1, Config.LOADOUT_SIZE do
		local u = ids[i] and Units.get(ids[i])
		if ids[i] and not u then
			log.warn("loadout slot", i, "has unknown unit", ids[i])
		end
		local ok, card = Log.try("Lobby", "card " .. tostring(ids[i]), Card.new, u, levels[i] or 1, hotbar)
		if ok then
			card.LayoutOrder = i
		end
	end
end

local function levelBar(parent)
	local bg = Theme.make("Frame", { Size = UDim2.fromOffset(560, 24), BackgroundColor3 = Color3.fromRGB(20, 18, 32), LayoutOrder = 3 }, parent)
	Theme.round(bg, 12)
	Theme.stroke(bg, 3)
	levelFill = Theme.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(80, 220, 120) }, bg)
	Theme.round(levelFill, 12)
	Theme.gloss(levelFill)
	levelText = Theme.label({ Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 3 }, bg)
	local function upd()
		local l, into, need = Rewards.levelProgress(player:GetAttribute("Xp") or 0)
		levelFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
		levelText.Text = ("Level %d [%d/%d]"):format(l, into, need)
	end
	player:GetAttributeChangedSignal("Xp"):Connect(upd)
	upd()
end

function LobbyUI.init()
	screen = Theme.make("ScreenGui", { Name = "Lobby", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

	for _, def in ipairs(LEFT) do
		actions[def.name] = function()
			openPanel(def.name)
		end
	end
	for _, def in ipairs(RIGHT) do
		actions[def.name] = function()
			openPanel(def.name)
		end
	end
	-- Play opens the real map/mode picker (server decides pick vs join, same as the portal).
	actions.Play = function()
		if MapSelect.panel and Panel.current() == MapSelect.panel then
			MapSelect.panel.close()
			return
		end
		Net.send("RequestPlay")
	end
	for name, def in pairs(Theme.COLORS) do
		if name ~= "Play" then
			panels[name] = Panel.new(name == "Event" and "Shadow Festival" or name, screen, def)
		end
	end
	-- circle-only features get a same-style "Coming soon" placeholder in the same table
	for _, f in ipairs(LobbyFeatures.list) do
		if not panels[f.panel] then
			panels[f.panel] = Panel.new(f.panel, screen, f.color)
		end
	end
	watchCircles()

	sidePanel(LEFT, 0, 0)
	sidePanel(RIGHT, 1, 1)
	eventBanner()

	local bottom = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(600, 200), BackgroundTransparency = 1 }, screen)
	Theme.make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, bottom)
	currencies(bottom)
	hotbar = Theme.make("Frame", { Size = UDim2.fromOffset(600, 108), BackgroundTransparency = 1, LayoutOrder = 2 }, bottom)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, hotbar)
	levelBar(bottom)
	rebuildHotbar()
	player:GetAttributeChangedSignal("Loadout"):Connect(rebuildHotbar)
	player:GetAttributeChangedSignal("LoadoutLevels"):Connect(rebuildHotbar)

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not screen.Enabled then
			return
		end
		local name = Input.action(input.KeyCode)
		if name and keyMap[name] then
			Log.try("Lobby", "shortcut " .. name, actions[name])
		end
	end)

	-- Lobby only: hide as soon as we're in a match (any state but "lobby").
	Net.listen("MatchState", function(s)
		LobbyUI.setVisible(s == "lobby")
	end)
	log.info("lobby UI ready")
end

function LobbyUI.setVisible(v)
	screen.Enabled = v
	if not v then
		Panel.closeCurrent()
	end
end

return LobbyUI
