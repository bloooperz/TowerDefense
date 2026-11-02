-- Centered modal panel with title + close button. Panel.new(title, parent) -> { root, body, open, close }
local Theme = require(script.Parent.Theme)

local Panel = {}

function Panel.new(title, parent, color)
	local root = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 300),
		BackgroundColor3 = Theme.PANEL,
		Visible = false,
		ZIndex = 20,
	}, parent)
	Theme.round(root, 18)
	Theme.stroke(root, 4)
	Theme.make("UIStroke", { Thickness = 2, Color = color or Color3.new(1, 1, 1), Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, root)
	local titleLabel = Theme.label({ Text = title, Size = UDim2.new(1, -80, 0, 40), Position = UDim2.fromOffset(20, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, TextColor3 = color or Color3.new(1, 1, 1) }, root)
	local body = Theme.label({ Text = "Coming soon", Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0.5, -20), ZIndex = 21, TextColor3 = Color3.fromRGB(210, 210, 230) }, root)
	local close = Theme.make("TextButton", { Text = "X", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(220, 50, 60), Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -50, 0, 12), ZIndex = 22 }, root)
	Theme.round(close, 10)
	Theme.stroke(close, 3)
	local p = { root = root, body = body, title = titleLabel }
	function p.open()
		root.Visible = true
	end
	function p.close()
		root.Visible = false
	end
	close.Activated:Connect(p.close)
	return p
end

return Panel
