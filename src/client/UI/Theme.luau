-- Visual language: dark nearly-opaque rounded panels (4-8px) with thick bright borders, brush-stroke
-- title banners, bright solid buttons with keybind chips, bold rounded outlined text.
-- PALETTE SPLIT: Theme.World (lobby/map/HUD/settings: warm steampunk) vs Theme.Unit (hotbar, cards,
-- unit panel: neutral charcoal, rarity borders only).
local Theme = {}
local Shape = require(script.Parent.Shape)
local LobbyFeatures = require(game:GetService("ReplicatedStorage").Shared.LobbyFeatures)
Theme.shape = Shape
Theme.FONT = Enum.Font.FredokaOne -- headers / buttons
Theme.BODY = Enum.Font.GothamBold -- body
Theme.OUTLINE = Shape.OUTLINE

Theme.World = {
	BASE = Color3.fromRGB(26, 18, 16), -- #1a1210
	BASE_2 = Color3.fromRGB(44, 30, 24), -- raised rows
	BORDER = Color3.fromRGB(214, 168, 74), -- brass
	BORDER_HOT = Color3.fromRGB(255, 196, 70), -- gold
	RED = Color3.fromRGB(220, 52, 40),
	ORANGE = Color3.fromRGB(255, 128, 30),
	YELLOW = Color3.fromRGB(255, 206, 60),
	GREEN = Color3.fromRGB(70, 200, 80),
	BLUE = Color3.fromRGB(50, 140, 235),
	TEXT = Color3.fromRGB(255, 244, 228),
	MUTED = Color3.fromRGB(200, 176, 150),
	TRANSPARENCY = 0.03,
}
Theme.Unit = {
	BASE = Color3.fromRGB(24, 26, 30), -- charcoal
	BASE_2 = Color3.fromRGB(36, 40, 46), -- slate
	BORDER = Color3.fromRGB(96, 104, 116), -- neutral (no rarity)
	TEXT = Color3.fromRGB(236, 240, 245),
	MUTED = Color3.fromRGB(160, 168, 180),
	TRANSPARENCY = 0.03,
}
-- legacy aliases (world surfaces)
Theme.PANEL = Theme.World.BASE
Theme.PANEL_2 = Theme.World.BASE_2
Theme.EDGE = Theme.World.BORDER

-- Bright solid button fills.
Theme.BUTTON = { green = Theme.World.GREEN, red = Theme.World.RED, blue = Theme.World.BLUE, orange = Theme.World.ORANGE }

-- Per-tile accents. Circle features share LobbyFeatures.ACCENTS so tiles, circles and their panels match.
local A = LobbyFeatures.ACCENTS
Theme.COLORS = {
	Summon = A.Summon,
	Trade = A.Trade, -- pink (Trading)
	Quests = A.Quests,
	Inventory = Color3.fromRGB(210, 120, 50), -- copper
	Units = Color3.fromRGB(235, 70, 50), -- scarlet
	Play = Color3.fromRGB(80, 200, 70), -- go-green
	Battlepass = Color3.fromRGB(255, 170, 40), -- amber
	Profile = Color3.fromRGB(60, 150, 230), -- steel blue
	Friends = Color3.fromRGB(40, 200, 160), -- teal
	Event = Color3.fromRGB(255, 100, 30),
}
for k, v in pairs(A) do
	Theme.COLORS[k] = Theme.COLORS[k] or v -- Traits Reroll, Stats Reroll, Shop, Leaderboards, Evolution
end

function Theme.make(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		o.Text = "" -- never show Roblox's default "Label"/"Button"/"TextBox"
	end
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- All surfaces go through UI/Shape: rounded 4-8px, thick bright border, subtle gradient.
function Theme.round(o, r)
	return Shape.apply(o, { radius = math.clamp(math.floor((r or 8) * 0.5), 4, 8) })
end

-- Thick (2-3px) bright border. Default = the element's own color brightened, brass on dark surfaces.
function Theme.stroke(o, thickness, color)
	local h = Shape.get(o) or Theme.round(o, 12)
	h.setEdge(color or Theme.edgeFor(h.fill()), (thickness or 3) >= 3 and 3 or 2)
	return h
end

function Theme.edgeFor(fill)
	local hh, ss, vv = fill:ToHSV()
	if ss < 0.25 or vv < 0.3 then
		return Theme.World.BORDER
	end
	return Color3.fromHSV(hh, ss * 0.85, math.min(vv * 1.3 + 0.1, 1))
end

-- Darker stroke for bright buttons.
function Theme.darkEdge(fill)
	return Shape.scaleColor(fill, 0.55)
end

-- Gradient lives in Shape; kept for call-site compatibility.
function Theme.gloss(_o)
	return Instance.new("UIGradient")
end

-- World panel surface: dark, nearly opaque, thick colored border.
function Theme.panel(o, border, palette)
	palette = palette or Theme.World
	return Shape.apply(o, { radius = 8, fill = palette.BASE, transparency = palette.TRANSPARENCY, edge = border or palette.BORDER, thickness = 3 })
end

-- Bright solid button: lighter-top gradient, darker stroke, hover brighten, press 0.95.
function Theme.button(o, fill)
	return Shape.apply(o, { radius = 6, fill = fill, transparency = 0, edge = Theme.darkEdge(fill), thickness = 2.5 })
end

-- Brush-stroke title banner over a panel's top-left corner.
function Theme.banner(panel, text, opts)
	return Shape.banner(panel, text, opts)
end

-- Bold outlined label.
function Theme.label(props, parent)
	local base = {
		Text = "",
		BackgroundTransparency = 1,
		Font = Theme.FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 1,
		TextScaled = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local l = Theme.make("TextLabel", base, parent)
	Shape.outlineText(l, 2)
	return l
end

return Theme
