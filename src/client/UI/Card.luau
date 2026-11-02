-- Unit card: portrait (ViewportFrame cube model), rarity border, Lv, cost, name,
-- damage type badge (Physical/Magical) and optional element badge.
local Theme = require(script.Parent.Theme)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Card = {}

-- Same cube (+ optional topper) the server builds in Towers.place, at the origin.
function Card.portrait(u, parent)
	local vp = Theme.make("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(45, 40, 70),
		Ambient = Color3.fromRGB(150, 150, 150),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	local cam = Theme.make("Camera", {}, vp)
	vp.CurrentCamera = cam
	local model = Theme.make("Model", {}, vp)
	Theme.make("Part", { Anchored = true, Size = Vector3.one * u.size, CFrame = CFrame.new(), Color = u.color or Color3.new(1, 1, 1) }, model)
	if u.topper then
		Theme.make("Part", { Anchored = true, Size = Vector3.new(u.size, 0.4, u.size), CFrame = CFrame.new(0, u.size / 2 + 0.2, 0), Color = u.topper }, model)
	end
	local d = u.size * 1.9
	cam.CFrame = CFrame.lookAt(Vector3.new(d * 0.7, d * 0.55, d * 0.7), Vector3.zero)
	return vp
end

local function badge(text, color, pos, parent)
	local b = Theme.label({ Text = text, Size = UDim2.fromOffset(52, 14), Position = pos, BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = 4 }, parent)
	Theme.round(b, 4)
	Theme.stroke(b, 1.5)
	return b
end

-- u: unit def or nil (empty slot). level: number.
function Card.new(u, level, parent)
	local rarity = u and Config.RARITY_COLORS[u.rarity or "Common"] or Color3.fromRGB(80, 80, 90)
	local c = Theme.make("Frame", { Size = UDim2.fromOffset(86, 104), BackgroundColor3 = Theme.PANEL, ZIndex = 2 }, parent)
	Theme.round(c, 12)
	Theme.make("UIStroke", { Thickness = 3, Color = rarity, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, c)
	if not u then
		Theme.label({ Text = "+", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.25), TextTransparency = 0.5, ZIndex = 3 }, c)
		return c
	end
	local vp = Card.portrait(u, c)
	vp.Size, vp.Position, vp.ZIndex = UDim2.new(1, -8, 0, 62), UDim2.fromOffset(4, 4), 3
	Theme.round(vp, 9)
	Theme.label({ Text = "Lv " .. level, Size = UDim2.fromOffset(40, 14), Position = UDim2.fromOffset(6, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, c)
	Theme.label({ Text = "$" .. u.cost, Size = UDim2.fromOffset(40, 14), Position = UDim2.new(1, -46, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(120, 255, 120), ZIndex = 4 }, c)
	local dt = u.damageType or "Physical"
	badge(dt, Config.DAMAGE_TYPE_COLORS[dt] or Color3.new(0.5, 0.5, 0.5), UDim2.fromOffset(4, 52), c)
	if u.element then
		badge((Config.ELEMENT_ICONS[u.element] or "") .. u.element, Color3.fromRGB(40, 40, 60), UDim2.new(1, -56, 0, 52), c).Size = UDim2.fromOffset(52, 14)
	end
	Theme.label({ Text = u.name, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -34), ZIndex = 4 }, c)
	Theme.label({ Text = u.rarity or "Common", Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0, 4, 1, -14), TextColor3 = rarity, ZIndex = 4 }, c)
	return c
end

return Card
