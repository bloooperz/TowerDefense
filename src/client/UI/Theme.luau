-- Lobby visual language: saturated rounded squares, thick dark outline, neon glow, outlined bold text.
local Theme = {}
Theme.FONT = Enum.Font.FredokaOne
Theme.OUTLINE = Color3.fromRGB(15, 12, 25)
Theme.PANEL = Color3.fromRGB(30, 26, 48)
Theme.COLORS = {
	Inventory = Color3.fromRGB(255, 150, 40),
	Units = Color3.fromRGB(60, 200, 90),
	Trade = Color3.fromRGB(40, 190, 230),
	Summon = Color3.fromRGB(200, 70, 255),
	Play = Color3.fromRGB(255, 60, 80),
	Quests = Color3.fromRGB(255, 210, 40),
	Battlepass = Color3.fromRGB(255, 90, 180),
	Profile = Color3.fromRGB(80, 120, 255),
	Friends = Color3.fromRGB(40, 220, 170),
	Event = Color3.fromRGB(255, 120, 30),
}

function Theme.make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function Theme.round(o, r)
	return Theme.make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end

-- Thick dark outline (Border mode so it hugs the shape).
function Theme.stroke(o, thickness, color)
	return Theme.make("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Theme.OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, o)
end

-- Vertical shine so flat colors read as glossy.
function Theme.gloss(o)
	return Theme.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	}, o)
end

-- Neon glow: a slightly larger, translucent rounded frame behind `o` (same parent).
function Theme.glow(o, color, spread)
	spread = spread or 8
	local g = Theme.make("Frame", {
		Name = "Glow",
		AnchorPoint = o.AnchorPoint,
		Position = o.Position,
		Size = o.Size + UDim2.fromOffset(spread * 2, spread * 2),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.6,
		ZIndex = math.max(o.ZIndex - 1, 0),
	}, o.Parent)
	-- offset for non-centered anchors
	g.Position = o.Position - UDim2.fromOffset(spread * (1 - 2 * o.AnchorPoint.X), spread * (1 - 2 * o.AnchorPoint.Y))
	Theme.round(g, 18)
	return g
end

-- Bold outlined label.
function Theme.label(props, parent)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.OUTLINE,
		TextScaled = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return Theme.make("TextLabel", base, parent)
end

return Theme
