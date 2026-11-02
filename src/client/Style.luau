-- Shared GUI helpers for the anime-TD look.
local Style = {}

Style.DARK = Color3.fromRGB(22, 22, 30)
Style.MID = Color3.fromRGB(38, 38, 50)
Style.STROKE = Color3.fromRGB(90, 90, 120)
Style.GREEN = Color3.fromRGB(0, 170, 90)
Style.RED = Color3.fromRGB(200, 55, 55)
Style.GREY = Color3.fromRGB(70, 70, 80)
Style.YELLOW = Color3.fromRGB(255, 215, 60)
Style.BLUE = Color3.fromRGB(60, 140, 255)
Style.FONT = Enum.Font.FredokaOne

function Style.make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function Style.panel(props, parent)
	local f = Style.make("Frame", { BackgroundColor3 = Style.DARK, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		f[k] = v
	end
	Style.make("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
	Style.make("UIStroke", { Color = Style.STROKE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
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
	Style.make("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0) }, l)
	return l
end

function Style.bar(props, fillColor, parent)
	local bg = Style.make("Frame", { BackgroundColor3 = Style.MID, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		bg[k] = v
	end
	Style.make("UICorner", { CornerRadius = UDim.new(1, 0) }, bg)
	local fill = Style.make("Frame", { BackgroundColor3 = fillColor, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, bg)
	Style.make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local label = Style.text({ Size = UDim2.fromScale(1, 1), ZIndex = 3 }, bg)
	return bg, fill, label
end

return Style
