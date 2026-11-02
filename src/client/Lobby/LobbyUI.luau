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
local actions, keyMap = {}, {}

local function openPanel(name)
	for n, p in pairs(panels) do
		if n ~= name then
			p.close()
		end
	end
	panels[name].open()
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
		local h = Button.new({
			name = def.name, icon = def.icon, key = def.key, isNew = def.isNew,
			color = Theme.COLORS[def.name],
			onClick = actions[def.name],
		}, f)
		h.LayoutOrder = i
		keyMap[Enum.KeyCode[def.key]] = def.name
	end
end

local function eventBanner()
	local holder = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(300, 92), BackgroundTransparency = 1 }, screen)
	Theme.label({ Text = "EVENTS", Size = UDim2.new(1, 0, 0, 22), TextColor3 = Color3.fromRGB(255, 230, 120) }, holder)
	local card = Theme.make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Theme.COLORS.Event, ZIndex = 2 }, holder)
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
		Net.send("RequestPlay")
	end
	for name, def in pairs(Theme.COLORS) do
		if name ~= "Play" then
			panels[name] = Panel.new(name == "Event" and "Shadow Festival" or name, screen, def)
		end
	end

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
		local name = keyMap[input.KeyCode]
		if name then
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
		for _, p in pairs(panels) do
			p.close()
		end
	end
end

return LobbyUI
