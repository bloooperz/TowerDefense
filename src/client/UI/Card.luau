-- Unit card: portrait (ViewportFrame unit model via shared/UnitModels), rarity border, Lv, cost, name,
-- damage-type badge and optional element badge (blank icon slots, name on hover), in a non-overlapping row.
local Theme = require(script.Parent.Theme)
local Shape = require(script.Parent.Shape)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UnitModels = require(game:GetService("ReplicatedStorage").Shared.UnitModels)

local Card = {}

local function viewport(parent)
	local vp = Theme.make("ViewportFrame", {
		BackgroundColor3 = Theme.Unit.BASE_2,
		Ambient = Color3.fromRGB(150, 150, 150),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	local cam = Theme.make("Camera", {}, vp)
	vp.CurrentCamera = cam
	return vp, cam
end

-- Loading portrait: blank neutral grey R6 block figure (head, torso, arms, legs), shown until
-- the player's real unit data arrives (Anime Last Stand-style loading silhouette).
Card.PLACEHOLDER_COLOR = Color3.fromRGB(150, 150, 156)
function Card.placeholder(parent)
	local vp, cam = viewport(parent)
	vp.Name = "PlaceholderPortrait"
	local model = Theme.make("Model", { Name = "R6Placeholder" }, vp)
	local grey = Card.PLACEHOLDER_COLOR
	local function part(name, size, pos)
		Theme.make("Part", { Name = name, Anchored = true, Size = size, CFrame = CFrame.new(pos), Color = grey, Material = Enum.Material.SmoothPlastic }, model)
	end
	part("Head", Vector3.new(1.2, 1, 1), Vector3.new(0, 2, 0))
	part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0.5, 0))
	part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0.5, 0))
	part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0.5, 0))
	part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -1.5, 0))
	part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -1.5, 0))
	cam.CFrame = CFrame.lookAt(Vector3.new(2.6, 1.4, 5.2), Vector3.new(0, 0.3, 0))
	return vp
end

-- Unit defs carry no `color` (there are no character meshes yet), so the cube used to fall
-- back to plain white. Fall back to the rarity color instead so portraits read at a glance.
function Card.modelColor(u)
	return (u and u.color) or (u and Config.RARITY_COLORS[u.rarity]) or Color3.fromRGB(200, 200, 205)
end

-- Same registry model the server builds in Towers.place (shared/UnitModels), framed 3/4.
-- u == nil -> loading placeholder.
function Card.portrait(u, parent)
	if not u then
		return Card.placeholder(parent)
	end
	local vp, cam = viewport(parent)
	vp.Name = "Portrait"
	-- registry model (Assets folder model > procedural placeholder > rarity-colored cube)
	local model = UnitModels.clone(u, { color = Card.modelColor(u) })
	model.Parent = vp
	UnitModels.frame(cam, model)
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

-- u: unit def or nil (empty slot). level: number (defaults to 1).
-- loading = true: data not replicated yet -> grey R6 placeholder portrait (still "Lv 1").
function Card.new(u, level, parent, loading)
	level = level or 1
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
	local vp = loading and Card.placeholder(c) or Card.portrait(u, c)
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
