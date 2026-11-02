-- Hotbar of units + START button.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Hotbar = {}
local slots = {}
Hotbar.onSelect = nil -- function(index)
Hotbar.onStart = nil -- function()

function Hotbar.init()
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn = "TDGui", false
	screen.Parent = player:WaitForChild("PlayerGui")

	local startBtn = Instance.new("TextButton")
	startBtn.AnchorPoint, startBtn.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 20)
	startBtn.Size, startBtn.Text, startBtn.TextScaled = UDim2.fromOffset(220, 60), "START", true
	startBtn.BackgroundColor3, startBtn.TextColor3 = Color3.fromRGB(0, 170, 80), Color3.new(1, 1, 1)
	startBtn.Visible = false
	Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 12)
	startBtn.MouseButton1Click:Connect(function()
		if Hotbar.onStart then
			Hotbar.onStart()
		end
	end)
	startBtn.Parent = screen
	Hotbar.startBtn = startBtn

	local bar = Instance.new("Frame")
	bar.AnchorPoint, bar.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -20)
	bar.Size, bar.BackgroundTransparency, bar.Visible = UDim2.fromOffset(#Config.UNITS * 90, 90), 1, false
	local layout = Instance.new("UIListLayout", bar)
	layout.FillDirection, layout.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 10)
	bar.Parent = screen
	Hotbar.bar = bar

	for i, u in ipairs(Config.UNITS) do
		local b = Instance.new("TextButton")
		b.Size, b.BackgroundColor3 = UDim2.fromOffset(80, 80), Color3.fromRGB(40, 40, 50)
		b.TextColor3, b.TextScaled = Color3.new(1, 1, 1), true
		b.Text = i .. "\n" .. u.name .. "\n$" .. u.cost
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke", b)
		stroke.Thickness, stroke.Color = 3, Color3.new(0, 0, 0)
		b.MouseButton1Click:Connect(function()
			if Hotbar.onSelect then
				Hotbar.onSelect(i)
			end
		end)
		b.Parent = bar
		slots[i] = stroke
	end
end

function Hotbar.highlight(index)
	for i, s in ipairs(slots) do
		s.Color = (i == index) and Color3.fromRGB(255, 220, 0) or Color3.new(0, 0, 0)
	end
end

function Hotbar.setState(s)
	Hotbar.bar.Visible = (s ~= "lobby")
	Hotbar.startBtn.Visible = (s == "waiting")
end

return Hotbar
