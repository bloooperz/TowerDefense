-- Centered modal panel with title + close button. Panel.new(title, parent) -> { root, body, open, close }
local Theme = require(script.Parent.Theme)

local Panel = {}

-- Central manager: at most ONE panel open at a time, for every panel (placeholder panels,
-- event panel, map picker, future panels). Anything with open()/close() can register.
local current = nil
function Panel.register(p)
	local rawOpen, rawClose = p.open, p.close
	function p.open()
		if current and current ~= p then
			local prev = current
			current = nil
			prev.close()
		end
		current = p
		rawOpen()
	end
	function p.close()
		if current == p then
			current = nil
		end
		rawClose()
	end
	function p.toggle()
		if current == p then
			p.close()
		else
			p.open()
		end
	end
	return p
end
function Panel.closeCurrent()
	if current then
		current.close()
	end
end
function Panel.current()
	return current
end
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.Escape and not gpe and not Panel.blockEsc then -- blockEsc: rebind capture eats Esc
		Panel.closeCurrent()
	end
end)

function Panel.new(title, parent, color)
	local root = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 300),
		BackgroundColor3 = Theme.PANEL,
		Visible = false,
		ZIndex = 20,
	}, parent)
	Theme.panel(root, color or Theme.World.BORDER) -- world palette, border in the feature's accent
	local banner = Theme.banner(root, title)
	local titleLabel = banner.label
	local body = Theme.label({ Text = "Coming soon", Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0.5, -20), ZIndex = 21, TextColor3 = Theme.World.MUTED }, root)
	local close = Theme.make("TextButton", { Text = "X", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 10), ZIndex = 22 }, root)
	Theme.button(close, Theme.World.RED)
	local p = { root = root, body = body, title = titleLabel }
	function p.open()
		root.Visible = true
	end
	function p.close()
		root.Visible = false
	end
	Panel.register(p)
	close.Activated:Connect(function()
		p.close()
	end)
	return p
end

return Panel
