-- Lobby visual language: saturated rounded squares, thick dark outline, neon glow, outlined bold text.
local Theme = {}
local Shape = require(script.Parent.Shape)
Theme.FONT = Enum.Font.GothamBlack -- display / headers / buttons
Theme.BODY = Enum.Font.GothamMedium -- readable body text
Theme.OUTLINE = Color3.fromRGB(8, 6, 16)
Theme.PANEL = Color3.fromRGB(16, 14, 30) -- deep base; Shape adds the vertical gradient
Theme.PANEL_2 = Color3.fromRGB(26, 22, 46) -- raised rows/cards
Theme.EDGE = Color3.fromRGB(130, 110, 255) -- house neon edge
Theme.shape = Shape
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

-- All surfaces go through UI/Shape (chamfered corners, crisp neon edge, subtle gradient). No corner instances anywhere.
-- `r` (old corner radius) maps to the cut size so call sites keep their relative sizing.
function Theme.round(o, r)
	return Shape.apply(o, { cut = math.clamp(math.floor((r or 12) * 0.75), 4, 14) })
end

-- Crisp 1-2px edge. Default edge = the element's own color, brightened (intentional, not a dark blob).
function Theme.stroke(o, thickness, color)
	local h = Shape.get(o) or Theme.round(o, 12)
	local fill = h.fill and h.fill() or o.BackgroundColor3
	h.setEdge(color or Theme.edgeFor(fill), (thickness or 2) >= 4 and 2 or 1.5)
	return h
end

function Theme.edgeFor(fill)
	local hh, ss, vv = fill:ToHSV()
	if ss < 0.25 then -- neutral/dark panels get the house neon edge
		return Theme.EDGE
	end
	return Color3.fromHSV(hh, math.min(ss * 0.8, 1), math.min(vv * 1.35 + 0.15, 1))
end

-- Gradient now lives inside Shape (per-piece); kept for call-site compatibility.
function Theme.gloss(_o)
	return Instance.new("UIGradient")
end

-- Soft glow blobs removed in favor of crisp edges; returns an invisible stand-in so tweens/callers still work.
function Theme.glow(o, _color, _spread)
	return Theme.make("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0), Visible = false }, o.Parent)
end

-- Header: display font + slanted accent notch on the left.
function Theme.header(props, parent, accent)
	props.Font = props.Font or Theme.FONT
	local l = Theme.label(props, parent)
	Shape.accent(l, accent or Theme.EDGE)
	return l
end

-- Bold outlined label.
function Theme.label(props, parent)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.45,
		TextStrokeColor3 = Theme.OUTLINE,
		TextScaled = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return Theme.make("TextLabel", base, parent)
end

return Theme
