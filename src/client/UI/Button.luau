-- Rounded glowing icon button: icon, outlined title, shortcut letter, optional "New!" tag.
-- opts = { name, color, keyAction? (Keybinds id), isNew?, size?, onClick }
local Theme = require(script.Parent.Theme)
local Input = require(script.Parent.Parent.Input)
local Log = require(game:GetService("ReplicatedStorage").Shared.Log)

local Button = {}

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
	Theme.button(b, opts.color) -- bright solid fill, lighter top, darker stroke, hover/press in Shape
	-- blank icon slot (real art drops in later); label underneath names the button
	Theme.shape.iconSlot({ Name = "Icon", Size = UDim2.fromScale(0.5, 0.46), Position = UDim2.fromScale(0.25, 0.12), ZIndex = 3 }, b)
	Theme.label({ Text = opts.name, Font = Theme.FONT, Size = UDim2.new(1, -6, 0.26, 0), Position = UDim2.new(0, 3, 0.68, 0), ZIndex = 3 }, b)
	if opts.keyAction then
		-- keybind chip from Input/Keybinds; follows rebinds, hidden when unbound
		local _, refresh = Theme.shape.keyChip(b, function()
			return Input.keyFor(opts.keyAction)
		end)
		Input.onChanged(refresh)
	end
	if opts.isNew then
		local tag = Theme.label({ Text = "New!", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -8), Size = UDim2.fromOffset(44, 20), Rotation = 12, ZIndex = 5, BackgroundTransparency = 0, BackgroundColor3 = Theme.World.RED }, b)
		Theme.button(tag, Theme.World.RED)
	end
	b.Activated:Connect(function()
		if opts.onClick then
			Log.try("UI", "button " .. opts.name, opts.onClick)
		end
	end)
	return holder, b
end

return Button
