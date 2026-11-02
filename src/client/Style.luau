-- Shared GUI helpers for in-match / world UI (HUD, results, map picker, toasts). WORLD palette
-- (warm steampunk) from Theme.World; unit surfaces (hotbar) use Style.unitShape / Theme.Unit.
local Shape = require(script.Parent.UI.Shape)
local Theme = require(script.Parent.UI.Theme)
local Style = {}
local W = Theme.World

Style.DARK = W.BASE
Style.MID = W.BASE_2
Style.STROKE = W.BORDER
Style.GREEN = W.GREEN
Style.RED = W.RED
Style.GREY = Color3.fromRGB(92, 76, 66)
Style.YELLOW = W.YELLOW
Style.BLUE = W.BLUE
Style.ORANGE = W.ORANGE
Style.FONT = Theme.FONT
Style.BODY = Theme.BODY

-- Rounded world surface: dark fill (unless already colored) + thick brass/colored border.
function Style.shape(o, radius, edge)
	return Shape.apply(o, { radius = radius or 6, edge = edge or Style.STROKE, thickness = 2.5 })
end

-- Bright solid button (lighter top, darker stroke, hover brighten, press 0.95).
function Style.button(o, fill)
	return Theme.button(o, fill or o.BackgroundColor3)
end

-- Neutral unit surface (hotbar): charcoal, border recolored by rarity/selection by the caller.
function Style.unitShape(o, edge)
	return Shape.apply(o, { radius = 6, fill = Theme.Unit.BASE, transparency = Theme.Unit.TRANSPARENCY, edge = edge or Theme.Unit.BORDER, thickness = 2.5 })
end

function Style.make(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		o.Text = "" -- never show Roblox's default "Label"/"Button"/"TextBox"
	end
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function Style.panel(props, parent)
	local f = Style.make("Frame", { BackgroundColor3 = Style.DARK, BackgroundTransparency = W.TRANSPARENCY, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		f[k] = v
	end
	Shape.apply(f, { radius = 8, edge = Style.STROKE, thickness = 3 })
	return f
end

function Style.text(props, parent)
	local l = Style.make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Style.FONT,
		TextScaled = true,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	Shape.outlineText(l, 2)
	return l
end

function Style.bar(props, fillColor, parent)
	local bg = Style.make("Frame", { BackgroundColor3 = Style.MID, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		bg[k] = v
	end
	Shape.apply(bg, { radius = 6, edge = Style.STROKE, thickness = 2 })
	local fill = Style.make("Frame", { BackgroundColor3 = fillColor, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, bg)
	Shape.apply(fill, { radius = 6, edge = Theme.darkEdge(fillColor), thickness = 2 })
	local label = Style.text({ Size = UDim2.fromScale(1, 1), ZIndex = 3 }, bg)
	return bg, fill, label
end

return Style
