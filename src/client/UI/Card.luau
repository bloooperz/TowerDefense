-- Unit card: portrait (ViewportFrame cube model), rarity border, Lv, cost, name,
-- damage-type badge and optional element badge (blank icon slots, name on hover), in a non-overlapping row.
local Theme = require(script.Parent.Theme)
local Shape = require(script.Parent.Shape)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Card = {}

-- Same cube (+ optional topper) the server builds in Towers.place, at the origin.
function Card.portrait(u, parent)
	local vp = Theme.make("ViewportFrame", {
		BackgroundColor3 = Theme.Unit.BASE_2,
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

local BADGE = 18
-- Rounded badge with a colored edge and a blank icon slot (art drops in later); word appears on hover.
local function badge(word, rim, parent, order)
	local b = Theme.make("Frame", { Name = word .. "Badge", Size = UDim2.fromOffset(BADGE, BADGE), BackgroundColor3 = Theme.OUTLINE, LayoutOrder = order, ZIndex = 5 }, parent)
	Shape.apply(b, { radius = 4, edge = rim, thickness = 2, gradient = false })
	Shape.iconSlot({ Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 6 }, b)
	local tip = Shape.tooltip(b, word, rim)
	tip.AnchorPoint, tip.Position = Vector2.new(1, 1), UDim2.new(1, 0, 0, -3)
	return b
end

-- u: unit def or nil (empty slot). level: number.
function Card.new(u, level, parent)
	local rarity = u and Config.RARITY_COLORS[u.rarity or "Common"] or Theme.Unit.BORDER
	local c = Theme.make("Frame", { Size = UDim2.fromOffset(86, 104), ZIndex = 2 }, parent)
	-- unit palette: neutral charcoal, rarity-colored border + glow (glow is cards-only)
	Shape.apply(c, { radius = 8, fill = Theme.Unit.BASE, transparency = 0, edge = rarity, thickness = 3 })
	if u then
		Shape.glow(c, rarity)
	end
	if not u then
		Theme.label({ Text = "+", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.25), TextTransparency = 0.5, ZIndex = 3 }, c)
		return c
	end
	local vp = Card.portrait(u, c)
	vp.Size, vp.Position, vp.ZIndex = UDim2.new(1, -8, 0, 62), UDim2.fromOffset(4, 4), 3
	Shape.apply(vp, { radius = 6, edge = Theme.Unit.BORDER, thickness = 2, gradient = false })
	Theme.label({ Text = "Lv " .. level, Size = UDim2.fromOffset(40, 14), Position = UDim2.fromOffset(6, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, c)
	Theme.label({ Text = "$" .. u.cost, Size = UDim2.fromOffset(40, 14), Position = UDim2.new(1, -46, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(120, 255, 120), ZIndex = 4 }, c)
	-- Icon row: bottom-right of the portrait, below the Lv/cost row (y 6..20), right-aligned
	-- list layout so badges can never overlap each other or the text, whatever the card size.
	local row = Theme.make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -7, 0, 63), Size = UDim2.new(1, -14, 0, BADGE), BackgroundTransparency = 1, ZIndex = 5 }, c)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local dt = u.damageType or "Physical"
	badge(dt, Config.DAMAGE_TYPE_COLORS[dt] or Color3.new(0.5, 0.5, 0.5), row, 1)
	if u.element then
		badge(u.element, Config.ELEMENT_COLORS[u.element] or Color3.new(1, 1, 1), row, 2)
	end
	Theme.label({ Text = u.name, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -34), ZIndex = 4 }, c)
	Theme.label({ Text = u.rarity or "Common", Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0, 4, 1, -14), TextColor3 = rarity, ZIndex = 4 }, c)
	return c
end

return Card
