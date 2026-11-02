-- Settings gear (bottom-left, lobby AND match HUD: own ScreenGui, always visible) + Settings panel.
-- Panel goes through the one-panel manager (Panel.new -> Panel.register): opening closes others, Esc/X close.
-- Sections: Match (Restart / Leave; greyed "Only in a match" in the lobby), Graphics, Audio, Controls.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Keybinds = require(Shared.Keybinds)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Input = require(script.Parent.Parent.Input)
local Toast = require(script.Parent.Parent.Toast)
local ClientSettings = require(script.Parent.ClientSettings)
local log = Log.new("SettingsUI")

local SettingsUI = {}
local ACCENT = Theme.World.BORDER_HOT -- world palette (warm)
local GREY = Color3.fromRGB(92, 76, 66)
local panel, list
local inMatch = false
local matchButtons = {} -- { btn, color, label }
local refreshers = {}
local capture = nil -- { id, btn } while waiting for a key

local function refreshAll()
	for _, fn in ipairs(refreshers) do
		Log.try("SettingsUI", "refresh", fn)
	end
end

local function header(text, order)
	Theme.label({ Text = text, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT, LayoutOrder = order, ZIndex = 22 }, list)
end

local function row(order, height)
	local r = Theme.make("Frame", { Size = UDim2.new(1, -8, 0, height or 44), BackgroundColor3 = Theme.World.BASE_2, LayoutOrder = order, ZIndex = 22 }, list)
	Theme.round(r, 10)
	Theme.stroke(r, 2)
	return r
end

local function chunky(text, color, parent, props)
	local b = Theme.make("TextButton", {
		Text = text, Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0, TextStrokeColor3 = Theme.OUTLINE,
		BackgroundColor3 = color, AutoButtonColor = true, ZIndex = 23,
	}, parent)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	Theme.button(b, color)
	return b
end

-- Two-step confirm: first click arms ("Confirm?") for 3s, second click runs.
local function confirmButton(text, color, parent, props, run)
	local b = chunky(text, color, parent, props)
	local armed = 0
	b.Activated:Connect(function()
		if not inMatch then
			Toast.show("Only in a match", "error")
			return
		end
		if os.clock() < armed then
			armed = 0
			b.Text = text
			Log.try("SettingsUI", text, run)
		else
			armed = os.clock() + 3
			b.Text = "Confirm?"
			task.delay(3, function()
				if os.clock() >= armed then
					b.Text = text
				end
			end)
		end
	end)
	table.insert(matchButtons, { btn = b, color = color })
	return b
end

local function toggleRow(order, label, key)
	local r = row(order)
	Theme.label({ Text = label, Size = UDim2.new(1, -120, 1, -12), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, r)
	local b = chunky("", GREY, r, { Size = UDim2.fromOffset(90, 32), Position = UDim2.new(1, -100, 0.5, -16) })
	local function refresh()
		local on = ClientSettings.get()[key]
		b.Text = on and "ON" or "OFF"
		b.BackgroundColor3 = on and Theme.World.GREEN or GREY
	end
	b.Activated:Connect(function()
		local ok, why = ClientSettings.set(key, not ClientSettings.get()[key])
		if not ok then
			Toast.show("Couldn't change " .. label .. ": " .. tostring(why), "error")
		end
		refresh()
	end)
	table.insert(refreshers, refresh)
end

-- Auto-sell threshold: click cycles rarities (low -> high). Picking a rarity at/above
-- Summon.CONFIRM_FROM arms a confirm first ("Confirm Mythic?", 3s), a second click applies it.
local function rarityRow(order, label, key)
	local Summon = require(Shared.Summon)
	local r = row(order)
	Theme.label({ Text = label, Size = UDim2.new(1, -170, 1, -12), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, r)
	local b = chunky("", ACCENT, r, { Size = UDim2.fromOffset(150, 32), Position = UDim2.new(1, -160, 0.5, -16) })
	local armed, pendingValue = 0, nil
	local function refresh()
		b.Text = "Up to " .. tostring(ClientSettings.get()[key])
	end
	b.Activated:Connect(function()
		local cur = ClientSettings.get()[key]
		local nextR = Summon.RARITIES[(Summon.rank(cur) % #Summon.RARITIES) + 1]
		if pendingValue and os.clock() < armed then
			nextR, pendingValue, armed = pendingValue, nil, 0
		elseif Summon.rank(nextR) >= Summon.rank(Summon.CONFIRM_FROM) then
			pendingValue, armed = nextR, os.clock() + 3
			b.Text = "Confirm " .. nextR .. "?"
			task.delay(3, function()
				if os.clock() >= armed then
					pendingValue = nil
					refresh()
				end
			end)
			return
		end
		local ok, why = ClientSettings.set(key, nextR)
		if not ok then
			Toast.show("Couldn't change " .. label .. ": " .. tostring(why), "error")
		end
		refresh()
	end)
	table.insert(refreshers, refresh)
end

local function sliderRow(order, label, key)
	local r = row(order)
	local text = Theme.label({ Size = UDim2.new(0.4, -12, 1, -12), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, r)
	local track = Theme.make("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(0.6, -24, 0, 12), Position = UDim2.new(0.4, 6, 0.5, -6), BackgroundColor3 = Theme.World.BASE, ZIndex = 23 }, r)
	Theme.round(track, 6)
	local fill = Theme.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, ZIndex = 24 }, track)
	Theme.round(fill, 6)
	local knob = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 25 }, track)
	Theme.round(knob, 11)
	Theme.stroke(knob, 2)
	local function show(v)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		text.Text = ("%s %d%%"):format(label, math.floor(v * 100 + 0.5))
	end
	local function refresh()
		show(ClientSettings.get()[key])
	end
	local dragging = false
	local function setFromX(x)
		local v = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		v = math.floor(v * 20 + 0.5) / 20
		show(v)
		ClientSettings.set(key, v)
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			setFromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(refreshers, refresh)
end

local function stopCapture()
	if capture then
		capture.btn.Text = Input.keyFor(capture.id) or "?"
		capture.btn.BackgroundColor3 = GREY
	end
	capture = nil
	task.defer(function() -- other InputBegan listeners still see this key press: keep them muted until next frame
		if not capture then
			Input.capturing = false
			Panel.blockEsc = false
		end
	end)
end

local function bindRow(order, action)
	local r = row(order, 38)
	Theme.label({ Text = action.label, Size = UDim2.new(1, -130, 1, -10), Position = UDim2.fromOffset(12, 5), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, r)
	local b = chunky(Input.keyFor(action.id) or "?", GREY, r, { Size = UDim2.fromOffset(110, 28), Position = UDim2.new(1, -118, 0.5, -14) })
	b.Activated:Connect(function()
		if capture then
			stopCapture()
		end
		capture = { id = action.id, btn = b }
		Input.capturing = true
		Panel.blockEsc = true
		b.Text = "Press a key (Esc cancels)"
		b.BackgroundColor3 = ACCENT
	end)
	table.insert(refreshers, function()
		if not capture or capture.btn ~= b then
			b.Text = Input.keyFor(action.id) or "?"
		end
	end)
end

local function onCaptureKey(input)
	if not capture or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local id = capture.id
	if input.KeyCode == Enum.KeyCode.Escape then
		stopCapture()
		return
	end
	local o, why = Keybinds.rebind(Input.overrides(), id, input.KeyCode.Name)
	if not o then
		Toast.show(why, "error")
		log.warn("rebind rejected:", why)
		stopCapture()
		return
	end
	stopCapture()
	local ok, err = ClientSettings.set("keybinds", o)
	if not ok then
		Toast.show("Couldn't save keybind: " .. tostring(err), "error")
	end
	refreshAll()
end

local function build(screen)
	panel = Panel.new("Settings", screen, ACCENT)
	panel.root.Size = UDim2.fromOffset(580, 460)
	panel.body.Visible = false
	list = Theme.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -40, 1, -80),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21,
	}, panel.root)
	Theme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local o = 0
	local function n()
		o += 1
		return o
	end
	header("Match", n())
	local mr = row(n(), 56)
	confirmButton("Restart", Theme.World.ORANGE, mr, { Size = UDim2.new(0.5, -18, 1, -14), Position = UDim2.fromOffset(12, 7) }, function()
		Net.send("RequestRestart")
	end)
	confirmButton("Leave", Theme.World.RED, mr, { Size = UDim2.new(0.5, -18, 1, -14), Position = UDim2.new(0.5, 6, 0, 7) }, function()
		Net.send("LeaveMatch")
		Panel.closeCurrent()
	end)
	local only = Theme.label({ Text = "Only in a match", Size = UDim2.new(1, 0, 0, 20), TextColor3 = Theme.World.MUTED, LayoutOrder = n(), ZIndex = 22 }, list)
	table.insert(refreshers, function()
		only.Visible = not inMatch
		for _, m in ipairs(matchButtons) do
			m.btn.BackgroundColor3 = inMatch and m.color or GREY
			m.btn.TextTransparency = inMatch and 0 or 0.4
			m.btn.AutoButtonColor = inMatch
		end
	end)

	header("Graphics", n())
	toggleRow(n(), "Low graphics", "lowGraphics")
	toggleRow(n(), "Damage numbers", "damageNumbers")
	toggleRow(n(), "Hide other players' units", "hideOthers")
	header("Summon", n())
	toggleRow(n(), "Skip summon animation", "skipSummonAnim")
	toggleRow(n(), "Auto-sell summoned units", "autoSell")
	rarityRow(n(), "Auto-sell rarity", "autoSellMax")
	header("Audio", n())
	sliderRow(n(), "Music", "music")
	sliderRow(n(), "SFX", "sfx")

	header("Controls", n())
	for _, a in ipairs(Keybinds.ACTIONS) do
		bindRow(n(), a)
	end
	local rr = row(n(), 48)
	chunky("Reset to defaults", Theme.World.BLUE, rr, { Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6) }).Activated:Connect(function()
		stopCapture()
		local ok, err = ClientSettings.set("keybinds", {})
		if ok then
			Toast.show("Keybinds reset", "info")
		else
			Toast.show("Reset failed: " .. tostring(err), "error")
		end
		refreshAll()
	end)

	local rawOpen, rawClose = panel.open, panel.close
	panel.open = function()
		refreshAll()
		rawOpen()
	end
	panel.close = function()
		stopCapture()
		rawClose()
	end
end

function SettingsUI.toggle()
	if panel then
		panel.toggle()
	end
end

function SettingsUI.setMatchState(s)
	inMatch = s ~= nil and s ~= "lobby"
	refreshAll()
end

function SettingsUI.init()
	Log.try("Settings", "ClientSettings.init", ClientSettings.init)
	local player = Players.LocalPlayer
	local screen = Theme.make("ScreenGui", { Name = "Settings", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	build(screen)
	local holder = Button.new({ name = "Settings", keyAction = "settings", size = 64, color = ACCENT, onClick = SettingsUI.toggle }, screen)
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -16)
	UIS.InputBegan:Connect(function(input)
		Log.try("SettingsUI", "capture", onCaptureKey, input)
	end)
	ClientSettings.onChanged(refreshAll)
	Input.onChanged(refreshAll)
end

return SettingsUI
