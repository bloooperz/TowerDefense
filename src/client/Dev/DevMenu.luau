-- Studio-only dev menu (Kohl's Admin style): floating draggable panel. F2 or the corner
-- "DEV" button toggles it. Built ONLY in Studio; all actions are server-validated (server/Dev).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Traits = require(Shared.Traits)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Placement = require(script.Parent.Parent.Placement)

local log = Log.new("DevMenu")
local DevMenu = {}
local KEY = Enum.KeyCode.F2
local BG, ROW = Color3.fromRGB(28, 28, 36), Color3.fromRGB(45, 45, 58)

local function btn(text, color, parent, order)
	local b = Theme.make("TextButton", {
		Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color or ROW, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, AutoButtonColor = true,
	}, parent)
	Theme.round(b, 6)
	return b
end

local function row(parent, order)
	local f = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	return f
end

local function cycler(parent, order, label, items, nameOf, onChange)
	local i = 1
	local r = row(parent, order)
	Theme.make("TextLabel", { Text = label, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 210), BackgroundTransparency = 1, Size = UDim2.new(0, 56, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 }, r)
	local prev = btn("<", nil, r, 2)
	prev.Size = UDim2.new(0, 28, 1, 0)
	local mid = btn("", Color3.fromRGB(60, 60, 80), r, 3)
	mid.Size = UDim2.new(1, -124, 1, 0)
	local nxt = btn(">", nil, r, 4)
	nxt.Size = UDim2.new(0, 28, 1, 0)
	local function show()
		mid.Text = nameOf(items[i])
		if onChange then onChange(items[i]) end
	end
	prev.Activated:Connect(function() i = (i - 2) % #items + 1; show() end)
	nxt.Activated:Connect(function() i = i % #items + 1; show() end)
	show()
	return function() return items[i] end
end

local function numberBox(parent, label, order)
	local r = row(parent, order)
	Theme.make("TextLabel", { Text = label, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 210), BackgroundTransparency = 1, Size = UDim2.new(0, 90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left }, r)
	local box = Theme.make("TextBox", { Text = "", PlaceholderText = "default", ClearTextOnFocus = false, Font = Enum.Font.Code, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = ROW, Size = UDim2.new(1, -94, 1, 0) }, r)
	Theme.round(box, 6)
	return box
end

local function draggable(handle, frame)
	local dragging, start, origin
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, start, origin = true, i.Position, frame.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function build()
	local state = RS:WaitForChild("DevState", 10)
	if not state then
		log.error("DevState missing: server Dev.init did not run (see server Output)")
		Toast.show("Dev menu: server backend missing", "error")
		return
	end
	local gui = Theme.make("ScreenGui", { Name = "DevMenu", ResetOnSpawn = false, DisplayOrder = 50 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local corner = btn("DEV", Color3.fromRGB(200, 40, 60), gui)
	corner.AnchorPoint, corner.Position, corner.Size = Vector2.new(1, 1), UDim2.new(1, -8, 1, -8), UDim2.fromOffset(52, 28)

	local frame = Theme.make("Frame", { Size = UDim2.fromOffset(300, 470), Position = UDim2.new(1, -320, 0, 80), BackgroundColor3 = BG, Visible = false }, gui)
	Theme.round(frame, 10)
	Theme.make("UIStroke", { Color = Color3.fromRGB(200, 40, 60), Thickness = 2 }, frame)
	local title = Theme.make("TextLabel", { Text = "  DEV MENU (Studio)  [F2]", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(200, 40, 60), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Active = true }, frame)
	Theme.round(title, 10)
	draggable(title, frame)
	local body = Theme.make("ScrollingFrame", { Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 1, -46), BackgroundTransparency = 1, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, frame)
	Theme.make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	local function header(t, o)
		Theme.make("TextLabel", { Text = t, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 120, 130), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = o }, body)
	end
	header("SANDBOX (places unit in your match)", 1)
	local dmg, rng, rate, lvl
	local getUnit = cycler(body, 2, "Unit", Units.list, function(u) return u.name or u.id end, function(u)
		if dmg then
			dmg.PlaceholderText, rng.PlaceholderText, rate.PlaceholderText = tostring(u.damage), tostring(u.range), tostring(u.rate)
			lvl.PlaceholderText = "1-" .. UnitStats.maxLevel(u)
		end
	end)
	local getTrait = cycler(body, 3, "Trait", Traits.list, function(t) return t.name end)
	dmg, rng, rate, lvl = numberBox(body, "Damage", 4), numberBox(body, "Range", 5), numberBox(body, "Atk interval s", 6), numberBox(body, "Level", 7)
	local u0 = getUnit()
	dmg.PlaceholderText, rng.PlaceholderText, rate.PlaceholderText, lvl.PlaceholderText = tostring(u0.damage), tostring(u0.range), tostring(u0.rate), "1-" .. UnitStats.maxLevel(u0)
	local function num(box, default)
		local n = tonumber(box.Text)
		if box.Text ~= "" and not n then
			error(("'%s' is not a number"):format(box.Text), 0)
		end
		return n or default
	end
	btn("Spawn unit", Color3.fromRGB(50, 140, 80), body, 8).Activated:Connect(function()
		local ok, err = pcall(function()
			-- read the boxes NOW (live .Text), then pick the spot with the placement preview
			local u, tr = getUnit(), getTrait()
			local d, r, a, l = num(dmg, 0), num(rng, 0), num(rate, 0), num(lvl, 1)
			if d < 0 or r < 0 or a < 0 then
				error("stats must be >= 0 (blank/0 = default)", 0)
			end
			log.info("sandbox", u.id, tr.id, "dmg", d, "rng", r, "rate", a, "lv", l, "- click to place, Q cancels")
			Placement.startSandbox(u, r, function(pos)
				Net.send("DevSandbox", u.id, tr.id, d, r, a, l, pos)
			end)
			Toast.show("Click to place " .. (u.name or u.id) .. " (Q/RMB cancels)", "info")
		end)
		if not ok then
			log.warn("sandbox input:", err)
			Toast.show("Sandbox: " .. tostring(err), "error")
		end
	end)

	header("CHEATS", 10)
	local toggles = { { "cash", "Infinite cash" }, { "rerolls", "Infinite rerolls" }, { "god", "God mode (base)" } }
	for i, t in ipairs(toggles) do
		local b = btn("", nil, body, 10 + i)
		local function upd()
			local on = state:GetAttribute(t[1]) == true
			b.Text = t[2] .. ": " .. (on and "ON" or "OFF")
			b.BackgroundColor3 = on and Color3.fromRGB(50, 140, 80) or ROW
		end
		state:GetAttributeChangedSignal(t[1]):Connect(upd)
		upd()
		b.Activated:Connect(function()
			Net.send("DevToggle", t[1], state:GetAttribute(t[1]) ~= true)
		end)
	end
	btn("Skip wave", Color3.fromRGB(70, 90, 160), body, 20).Activated:Connect(function()
		Net.send("DevSkipWave")
	end)
	btn("Reset all", Color3.fromRGB(170, 50, 50), body, 21).Activated:Connect(function()
		Net.send("DevReset")
	end)

	local function toggle()
		frame.Visible = not frame.Visible
	end
	corner.Activated:Connect(toggle)
	UIS.InputBegan:Connect(function(i, gpe)
		if i.KeyCode == KEY and not gpe then
			toggle()
		end
	end)
	log.info("dev menu ready (F2)")
end

function DevMenu.init()
	if not RunService:IsStudio() then
		return -- never built in published games
	end
	task.spawn(Log.try, "DevMenu", "build", build) -- don't block other client init on DevState
end

return DevMenu
