-- The ONE shared frame-style helper (no image assets). Rounded 4-8px corners, thick bright UIStroke
-- border, subtle vertical UIGradient; buttons get lighter-top gradient + hover brighten / press 0.95.
-- Also: brush-stroke title banners, card glow, keybind chips, tooltips, blank icon slots.
local TweenService = game:GetService("TweenService")

local Shape = {}
Shape.DEFAULT_EDGE = Color3.fromRGB(214, 168, 74) -- brass
Shape.OUTLINE = Color3.fromRGB(14, 10, 8)
Shape.MIN_RADIUS, Shape.MAX_RADIUS = 4, 8

local QUICK = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local handles = setmetatable({}, { __mode = "k" })

local function new(class, props, parent)
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
Shape.new = new

local function scaleColor(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
Shape.scaleColor = scaleColor

local function isText(o)
	return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
end

-- Dark Contextual outline on text. A GuiObject that already owns a Border stroke cannot also
-- have a Contextual one, so those fall back to the built-in text stroke.
function Shape.outlineText(o, thickness)
	if not isText(o) then
		return
	end
	local border, ctx = nil, nil
	for _, ch in ipairs(o:GetChildren()) do
		if ch:IsA("UIStroke") then
			if ch.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
				border = ch
			else
				ctx = ch
			end
		end
	end
	if border then
		o.TextStrokeColor3, o.TextStrokeTransparency = Shape.OUTLINE, 0
	elseif not ctx then
		new("UIStroke", { Name = "TextOutline", ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Color = Shape.OUTLINE, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round }, o)
		o.TextStrokeTransparency = 1
	end
end

function Shape.get(gui)
	return handles[gui]
end

-- opts = { radius=6, edge=Color3, thickness=2.5, fill=Color3, transparency, gradient=true, hover=true (buttons) }
function Shape.apply(gui, opts)
	opts = opts or {}
	local old = handles[gui]
	if old then
		if opts.edge then
			old.setEdge(opts.edge, opts.thickness)
		end
		return old
	end
	for _, ch in ipairs(gui:GetChildren()) do
		if ch:IsA("UICorner") or ch:IsA("UIGradient") or (ch:IsA("UIStroke") and (ch.ApplyStrokeMode == Enum.ApplyStrokeMode.Border or not isText(gui))) then
			ch:Destroy()
		end
	end
	if opts.fill then
		gui.BackgroundColor3 = opts.fill
	end
	if opts.transparency then
		gui.BackgroundTransparency = opts.transparency
	end
	gui.BorderSizePixel = 0
	local corner = new("UICorner", { CornerRadius = UDim.new(0, math.clamp(opts.radius or 6, Shape.MIN_RADIUS, Shape.MAX_RADIUS)) }, gui)
	local stroke = new("UIStroke", {
		Name = "Border", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
		Color = opts.edge or Shape.DEFAULT_EDGE, Thickness = math.clamp(opts.thickness or 2.5, 2, 3),
	}, gui)
	local isButton = gui:IsA("GuiButton")
	if opts.gradient ~= false then
		-- panels: subtle top-light vertical fade; buttons: stronger lighter top
		local top = isButton and Color3.new(1, 1, 1) or Color3.fromRGB(255, 255, 255)
		local bottom = isButton and Color3.fromRGB(175, 175, 175) or Color3.fromRGB(200, 200, 200)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, gui)
	end
	if isText(gui) then
		gui.TextStrokeColor3, gui.TextStrokeTransparency = Shape.OUTLINE, 0 -- Border stroke owns the UIStroke slot
	end

	local handle = { box = gui, corner = corner, stroke = stroke }
	local baseFill = gui.BackgroundColor3
	local syncing = false
	local bright, tween = 1, nil -- current hover brightness + running hover tween
	function handle.fill()
		return baseFill
	end
	function handle.setFill(col, tr)
		if col then
			-- a running hover/press tween would otherwise overwrite the new color with the old base
			if tween then
				tween:Cancel()
				tween = nil
			end
			baseFill = col
			syncing = true
			gui.BackgroundColor3 = scaleColor(col, bright)
			syncing = false
		end
		if tr then
			gui.BackgroundTransparency = tr
		end
	end
	function handle.setEdge(col, t)
		if col then
			stroke.Color = col
		end
		if t then
			stroke.Thickness = math.clamp(t, 2, 3)
		end
	end
	gui:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if not syncing then
			baseFill = gui.BackgroundColor3
		end
	end)
	-- older call sites adding corners/border strokes later: fold them into ours
	gui.ChildAdded:Connect(function(ch)
		if ch:IsA("UICorner") and ch ~= corner then
			task.defer(ch.Destroy, ch)
		elseif ch:IsA("UIStroke") and ch ~= stroke and (ch.ApplyStrokeMode == Enum.ApplyStrokeMode.Border or not isText(gui)) then
			task.defer(function()
				handle.setEdge(ch.Color, ch.Thickness)
				ch:Destroy()
			end)
		end
	end)

	if isButton and opts.hover ~= false then
		gui.AutoButtonColor = false
		local scale = gui:FindFirstChildOfClass("UIScale") or new("UIScale", {}, gui)
		local hovering = false
		local function show(k, s)
			bright = k
			syncing = true
			if tween then
				tween:Cancel()
			end
			local my = TweenService:Create(gui, QUICK, { BackgroundColor3 = scaleColor(baseFill, k) })
			tween = my
			my.Completed:Connect(function()
				if tween == my then
					tween, syncing = nil, false
				end
			end)
			my:Play()
			TweenService:Create(scale, QUICK, { Scale = s }):Play()
		end
		gui.MouseEnter:Connect(function()
			hovering = true
			show(1.18, 1)
		end)
		gui.MouseLeave:Connect(function()
			hovering = false
			show(1, 1)
		end)
		gui.MouseButton1Down:Connect(function()
			show(1.05, 0.95)
		end)
		gui.MouseButton1Up:Connect(function()
			show(hovering and 1.18 or 1, 1)
		end)
	end
	handles[gui] = handle
	return handle
end

-- Colored glow (cards only): soft rings OUTSIDE the card edge (transparent frames with fading
-- strokes), so nothing tints the card face and it works inside layouts.
function Shape.glow(card, color)
	local holder = new("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, card)
	for i, spec in ipairs({ { 3, 3, 0.45 }, { 6, 3, 0.7 }, { 9, 3, 0.86 } }) do
		local g = new("Frame", {
			Name = "Halo" .. i, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, spec[1] * 2, 1, spec[1] * 2), ZIndex = 0,
		}, holder)
		new("UICorner", { CornerRadius = UDim.new(0, 8 + spec[1]) }, g)
		new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color, Thickness = spec[2], Transparency = spec[3] }, g)
	end
	return holder
end

-- Slanted brush-stroke title banner (Anime Origins style) hanging over the panel's top-left corner.
-- Orange -> cream gradient, rotated -5deg, ragged ends from small offset/rotated slices, white
-- sparkle at the left tip, heavy italic white outlined text. Returns { root, label }.
Shape.BANNER_FROM = Color3.fromRGB(255, 120, 30)
Shape.BANNER_TO = Color3.fromRGB(255, 236, 196)
function Shape.banner(panel, text, opts)
	opts = opts or {}
	local w, h = opts.width or math.max(180, #text * 17 + 70), opts.height or 46
	local from, to = opts.from or Shape.BANNER_FROM, opts.to or Shape.BANNER_TO
	local z = (panel.ZIndex or 1) + 5
	local root = new("Frame", {
		Name = "TitleBanner", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(-18, 2), Size = UDim2.fromOffset(w, h), Rotation = -5, ZIndex = z,
	}, panel)
	local grad = ColorSequence.new(from, to)
	local function stroke(props)
		props.BorderSizePixel, props.ZIndex = 0, props.ZIndex or z
		local f = new("Frame", props, root)
		new("UIGradient", { Color = grad }, f)
		return f
	end
	-- main body, slightly narrower than the banner so the ragged slices make the ends
	stroke({ Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -30, 1, -8) })
	-- ragged ends: short skewed slices of varying length/offset (left uses the FROM end of the gradient)
	local slices = { { -2, 0.0, 0.22, -7 }, { 4, 0.2, 0.2, 5 }, { -6, 0.38, 0.24, -3 }, { 2, 0.6, 0.2, 8 }, { -4, 0.78, 0.2, -6 } }
	for i, s in ipairs(slices) do
		local l = new("Frame", {
			Name = "RagL" .. i, BorderSizePixel = 0, BackgroundColor3 = scaleColor(from, 1), ZIndex = z,
			Position = UDim2.new(0, 8 + s[1], s[2], 2), Size = UDim2.new(0, 22, s[3], 0), Rotation = s[4],
		}, root)
		local r = new("Frame", {
			Name = "RagR" .. i, BorderSizePixel = 0, BackgroundColor3 = to, ZIndex = z,
			Position = UDim2.new(1, -30 - s[1], s[2], 2), Size = UDim2.new(0, 22 - i % 2 * 6, s[3], 0), Rotation = -s[4],
		}, root)
		local _ = l, r
	end
	-- thin dry-brush streaks off the right end
	for i, s in ipairs({ { 0.18, 18, 3 }, { 0.5, 26, 2 }, { 0.74, 14, 3 } }) do
		new("Frame", { Name = "Streak" .. i, BorderSizePixel = 0, BackgroundColor3 = to, BackgroundTransparency = 0.15, ZIndex = z,
			Position = UDim2.new(1, -12, s[1], 0), Size = UDim2.fromOffset(s[2], s[3]) }, root)
	end
	-- sparkle at the left tip: two crossed thin rects + a small rotated square core
	local sp = new("Frame", { Name = "Sparkle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = z + 2 }, root)
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 3), ZIndex = z + 2 }, sp)
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 3, 1, 0), ZIndex = z + 2 }, sp)
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Rotation = 45, ZIndex = z + 2 }, sp)
	local label = new("TextLabel", {
		Name = "Title", Text = text, BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, 6), Size = UDim2.new(1, -48, 1, -12), ZIndex = z + 1,
	}, root)
	new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Color = Shape.OUTLINE, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round }, label)
	return { root = root, label = label }
end

-- KeyCode name -> short chip text.
local SHORT = { One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	LeftShift = "Shift", RightShift = "Shift", LeftControl = "Ctrl", RightControl = "Ctrl", Space = "Space", Tab = "Tab" }
function Shape.keyText(name)
	return name and (SHORT[name] or name) or nil
end

-- Small dark rounded keybind chip in a button's top-left corner. getKey() -> KeyCode name | nil;
-- call the returned refresh() on rebind. Hidden when there is no key.
function Shape.keyChip(button, getKey)
	local chip = new("TextLabel", {
		Name = "KeyChip", BackgroundColor3 = Color3.fromRGB(16, 12, 10), BackgroundTransparency = 0.1, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack, TextScaled = true, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(20, 18),
		ZIndex = (button.ZIndex or 1) + 3,
	}, button)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, chip)
	new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, chip)
	local function refresh()
		local t = Shape.keyText(getKey())
		chip.Visible = t ~= nil and t ~= ""
		chip.Text = t or ""
		chip.Size = UDim2.fromOffset(math.max(20, #chip.Text * 8 + 8), 18)
	end
	refresh()
	return chip, refresh
end

-- Hover tooltip (names a blank icon slot etc).
function Shape.tooltip(target, text, edge)
	local tip = new("TextLabel", {
		Name = "Tip", Text = text, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(math.max(56, #text * 7 + 16), 20), BackgroundColor3 = Color3.fromRGB(18, 14, 12),
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, Visible = false, ZIndex = 30,
	}, target)
	Shape.apply(tip, { radius = 4, edge = edge or Shape.DEFAULT_EDGE, thickness = 2, gradient = false })
	target.MouseEnter:Connect(function()
		tip.Visible = true
	end)
	target.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	return tip
end

function Shape.iconSlot(props, parent)
	local s = new("ImageLabel", { Name = "IconSlot", BackgroundTransparency = 1, Image = "", BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		s[k] = v
	end
	return s
end

-- Global text pass: bold rounded fonts + dark outline on every text object under `root`, now and later.
local SWAP = { [Enum.Font.Gotham] = Enum.Font.GothamBold, [Enum.Font.GothamMedium] = Enum.Font.GothamBold, [Enum.Font.SourceSans] = Enum.Font.GothamBold, [Enum.Font.Legacy] = Enum.Font.GothamBold }
function Shape.styleText(root)
	local function one(o)
		if isText(o) then
			if SWAP[o.Font] then
				o.Font = SWAP[o.Font]
			end
			task.defer(Shape.outlineText, o) -- after the creator finishes adding its own strokes
		end
	end
	for _, d in ipairs(root:GetDescendants()) do
		one(d)
	end
	root.DescendantAdded:Connect(one)
end

return Shape
