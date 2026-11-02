-- Rounded glowing icon button: icon, outlined title, shortcut letter, optional "New!" tag.
-- opts = { name, icon, color, key?, isNew?, size?, onClick }
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Log = require(game:GetService("ReplicatedStorage").Shared.Log)

local Button = {}
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Button.new(opts, parent)
	local size = opts.size or 84
	-- holder keeps layout stable while the inner button scales
	local holder = Theme.make("Frame", { Name = opts.name, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local b = Theme.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = opts.color,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
	}, holder)
	Theme.round(b, 16)
	Theme.stroke(b, 3)
	Theme.gloss(b)
	local scale = Theme.make("UIScale", { Scale = 1 }, b)
	Theme.glow(b, opts.color, 4).Name = "Glow"
	Theme.label({ Text = opts.icon or "?", Size = UDim2.fromScale(0.6, 0.5), Position = UDim2.fromScale(0.2, 0.08), ZIndex = 3, TextStrokeTransparency = 1 }, b)
	Theme.label({ Text = opts.name, Size = UDim2.new(1, -6, 0.26, 0), Position = UDim2.new(0, 3, 0.68, 0), ZIndex = 3 }, b)
	if opts.key then
		local k = Theme.label({ Text = opts.key, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(4, 3), ZIndex = 4, BackgroundTransparency = 0.3, BackgroundColor3 = Theme.OUTLINE }, b)
		Theme.round(k, 6)
	end
	if opts.isNew then
		local tag = Theme.label({ Text = "New!", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -8), Size = UDim2.fromOffset(44, 20), Rotation = 12, ZIndex = 5, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 30, 40) }, b)
		Theme.round(tag, 6)
		Theme.stroke(tag, 2)
	end
	local function to(s)
		TweenService:Create(scale, QUICK, { Scale = s }):Play()
	end
	local hovering = false
	b.MouseEnter:Connect(function()
		hovering = true
		to(1.08)
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(hovering and 1.08 or 1)
	end)
	b.Activated:Connect(function()
		if opts.onClick then
			Log.try("UI", "button " .. opts.name, opts.onClick)
		end
	end)
	return holder, b
end

return Button
