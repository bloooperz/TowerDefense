-- Small stacked toasts (top-center). Server rejections arrive via Net "Notify".
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Style = require(script.Parent.Style)

local Toast = {}
local holder
local MAX = 4

function Toast.init()
	local screen = Style.make("ScreenGui", { Name = "Toasts", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	holder = Style.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
	}, screen)
	Style.make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, holder)
end

local order = 0
function Toast.show(text, kind)
	if not holder then
		return
	end
	order += 1
	local items = {}
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items >= MAX then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	local l = Style.make("TextLabel", {
		Size = UDim2.fromOffset(420, 30),
		BackgroundColor3 = kind == "error" and Color3.fromRGB(150, 35, 35) or Style.MID,
		BackgroundTransparency = 0.15,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Style.FONT,
		TextScaled = true,
		Text = tostring(text),
		LayoutOrder = order,
	}, holder)
	local shape = Style.shape(l, 7, kind == "error" and Color3.fromRGB(255, 90, 90) or Style.STROKE)
	Style.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, l)
	task.delay(3, function()
		if l.Parent then
			shape.box.Visible = false
			TweenService:Create(l, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			l:Destroy()
		end
	end)
end

return Toast
