-- Chamfered ("cut corner") frame style, no image assets. ONE helper for every UI surface.
-- Shape.apply(gui, opts) turns `gui`'s own background into: a cross of two rects + four 45deg diamonds
-- (the diamond edge IS the chamfer line), a subtle vertical gradient, crisp 1-2px neon edges
-- (4 straight + 4 diagonal hairlines) and an inner top highlight line. gui's background goes transparent;
-- pieces live in a ZIndex-0 "Shape" container so content always draws on top.
-- opts = { cut = px (default 10), edge = Color3?, thickness = 1..2, fill = Color3?, transparency = 0..1,
--          gradient = bool (default true), highlight = bool (default true), hover = bool (auto for buttons) }
local TweenService = game:GetService("TweenService")

local Shape = {}
Shape.DEFAULT_EDGE = Color3.fromRGB(120, 110, 200)
local handles = setmetatable({}, { __mode = "k" })
local QUICK = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SQRT2 = math.sqrt(2)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function scaleColor(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
Shape.scaleColor = scaleColor

-- a UIStroke draws the gui's rectangular border unless it is a text outline on a text object
local function isBorderStroke(gui, ch)
	if not ch:IsA("UIStroke") then
		return false
	end
	local text = gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")
	return ch.ApplyStrokeMode == Enum.ApplyStrokeMode.Border or not text
end

local function clean(gui)
	for _, ch in ipairs(gui:GetChildren()) do
		if ch:IsA("UICorner") or isBorderStroke(gui, ch) then
			ch:Destroy()
		end
	end
end

function Shape.get(gui)
	return handles[gui]
end

function Shape.apply(gui, opts)
	opts = opts or {}
	local existing = handles[gui]
	if existing then
		if opts.edge or opts.thickness then
			existing.setEdge(opts.edge, opts.thickness)
		end
		return existing
	end
	clean(gui)
	local c = math.max(opts.cut or 10, 2)
	if gui:IsA("ViewportFrame") or gui:IsA("TextBox") then
		-- children would cover a ViewportFrame's 3D render / a TextBox's typed text: keep it square, no pieces
		local dummy = { cut = c }
		function dummy.setFill() end
		function dummy.setEdge() end
		handles[gui] = dummy
		return dummy
	end
	local fill = opts.fill or gui.BackgroundColor3
	local tr = opts.transparency or gui.BackgroundTransparency
	if tr >= 1 then
		tr = 1 -- invisible background: keep only edges
	end
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 0

	local box = new("Frame", { Name = "Shape", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, nil)
	local base = UDim2.new()
	local isSibling = false
	local function goSibling()
		-- gui lays out its children: a child box would become a layout cell, so draw behind it instead
		if isSibling then
			return
		end
		isSibling = true
		local function follow()
			box.AnchorPoint, box.Size, box.Visible = gui.AnchorPoint, gui.Size, gui.Visible
			box.Position = gui.Position
			box.ZIndex = gui.ZIndex - 1
			base = gui.Position
		end
		follow()
		for _, prop in ipairs({ "Position", "Size", "AnchorPoint", "Visible", "ZIndex" }) do
			gui:GetPropertyChangedSignal(prop):Connect(follow)
		end
		gui.AncestryChanged:Connect(function()
			if gui.Parent then
				box.Parent = gui.Parent
			else
				box:Destroy()
			end
		end)
		box.Parent = gui.Parent
	end
	if gui:FindFirstChildWhichIsA("UIGridStyleLayout") then
		goSibling()
	else
		-- UIPadding would inset the box: stretch it back out to the real edges
		local function pad()
			if isSibling then
				return
			end
			local p = gui:FindFirstChildOfClass("UIPadding")
			if p then
				base = UDim2.new(-p.PaddingLeft.Scale, -p.PaddingLeft.Offset, -p.PaddingTop.Scale, -p.PaddingTop.Offset)
				box.Size = UDim2.new(1 + p.PaddingLeft.Scale + p.PaddingRight.Scale, p.PaddingLeft.Offset + p.PaddingRight.Offset,
					1 + p.PaddingTop.Scale + p.PaddingBottom.Scale, p.PaddingTop.Offset + p.PaddingBottom.Offset)
			else
				base, box.Size = UDim2.new(), UDim2.fromScale(1, 1)
			end
			box.Position = base
		end
		pad()
		gui.ChildAdded:Connect(function(ch)
			if ch:IsA("UIPadding") and not isSibling then
				task.defer(pad)
			elseif ch:IsA("UIGridStyleLayout") then
				goSibling()
			end
		end)
		box.Parent = gui
		-- text drawn by gui itself would sit UNDER child pieces: mirror it into a child label above them
		if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and tr < 1 then
			local m = new("TextLabel", { Name = "ShapeText", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, gui)
			local PROPS = { "Text", "TextColor3", "TextScaled", "TextSize", "Font", "TextXAlignment", "TextYAlignment",
				"TextWrapped", "RichText", "TextStrokeTransparency", "TextStrokeColor3", "TextTruncate" }
			for _, prop in ipairs(PROPS) do
				m[prop] = gui[prop]
				gui:GetPropertyChangedSignal(prop):Connect(function()
					m[prop] = gui[prop]
				end)
			end
			m.TextTransparency = gui.TextTransparency
			gui.TextTransparency = 1
			gui:GetPropertyChangedSignal("TextTransparency"):Connect(function()
				if gui.TextTransparency ~= 1 then
					m.TextTransparency = gui.TextTransparency
					gui.TextTransparency = 1
				end
			end)
			for _, ch in ipairs(gui:GetChildren()) do -- text outline strokes belong on the visible text
				if ch:IsA("UIStroke") and ch.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
					ch.Parent = m
				end
			end
		end
	end
	local pieces, diamonds, edges = {}, {}, {}
	local function piece(props)
		props.BorderSizePixel = 0
		props.BackgroundTransparency = tr
		props.ZIndex = 0
		local f = new("Frame", props, box)
		table.insert(pieces, f)
		return f
	end
	local grad = opts.gradient ~= false
	local h = piece({ Name = "H", Position = UDim2.fromOffset(0, c), Size = UDim2.new(1, 0, 1, -2 * c) })
	local v = piece({ Name = "V", Position = UDim2.fromOffset(c, 0), Size = UDim2.new(1, -2 * c, 1, 0) })
	for _, p in ipairs({ { 0, c, 0, c, true }, { 1, -c, 0, c, true }, { 1, -c, 1, -c, false }, { 0, c, 1, -c, false } }) do
		local d = piece({
			Name = "D", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = UDim2.new(p[1], p[2], p[3], p[4]), Size = UDim2.fromOffset(c * SQRT2, c * SQRT2),
		})
		table.insert(diamonds, { f = d, top = p[5] })
	end
	if grad then
		for _, f in ipairs({ h, v }) do
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 195)) }, f)
		end
	end

	-- crisp neon edges
	local t = opts.thickness or 1.5
	local function line(props)
		props.BorderSizePixel = 0
		props.ZIndex = 0
		local f = new("Frame", props, box)
		table.insert(edges, f)
		return f
	end
	line({ Position = UDim2.fromOffset(c, 0), Size = UDim2.new(1, -2 * c, 0, t) })
	line({ Position = UDim2.new(0, c, 1, -t), Size = UDim2.new(1, -2 * c, 0, t) })
	line({ Position = UDim2.fromOffset(0, c), Size = UDim2.new(0, t, 1, -2 * c) })
	line({ Position = UDim2.new(1, -t, 0, c), Size = UDim2.new(0, t, 1, -2 * c) })
	for _, p in ipairs({ { 0, c / 2, 0, c / 2, -45 }, { 1, -c / 2, 0, c / 2, 45 }, { 1, -c / 2, 1, -c / 2, -45 }, { 0, c / 2, 1, -c / 2, 45 } }) do
		line({
			AnchorPoint = Vector2.new(0.5, 0.5), Rotation = p[5],
			Position = UDim2.new(p[1], p[2], p[3], p[4]), Size = UDim2.fromOffset(c * SQRT2 + t, t),
		})
	end
	if opts.highlight ~= false and tr < 1 then
		new("Frame", { Name = "Highlight", BorderSizePixel = 0, ZIndex = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
			Position = UDim2.fromOffset(c, t + 2), Size = UDim2.new(1, -2 * c, 0, 1) }, box)
	end

	local handle = { box = box, cut = c }
	local curFill, curEdge, curT = fill, opts.edge or Shape.DEFAULT_EDGE, t
	function handle.setFill(col, transparency)
		curFill = col or curFill
		for _, f in ipairs(pieces) do
			f.BackgroundColor3 = curFill
			if transparency then
				f.BackgroundTransparency = transparency
			end
		end
		if grad then -- bottom diamonds match the gradient's darker end
			for _, d in ipairs(diamonds) do
				d.f.BackgroundColor3 = d.top and curFill or scaleColor(curFill, 0.74)
			end
		end
	end
	function handle.setEdge(col, thickness)
		curEdge = col or curEdge
		curT = thickness or curT
		for _, e in ipairs(edges) do
			e.BackgroundColor3 = curEdge
		end
	end
	function handle.fill()
		return curFill
	end
	handle.setFill(fill)
	handle.setEdge(curEdge)
	-- keep in sync if code later sets gui.BackgroundColor3 (e.g. button state colors)
	gui:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		handle.setFill(gui.BackgroundColor3)
	end)
	-- corners/strokes added later by older call sites: corners dropped, border strokes become our edge
	gui.ChildAdded:Connect(function(ch)
		if ch:IsA("UICorner") then
			task.defer(ch.Destroy, ch)
		elseif isBorderStroke(gui, ch) then
			task.defer(function()
				handle.setEdge(ch.Color, math.clamp(ch.Thickness, 1, 2))
				ch:Destroy()
			end)
		end
	end)

	-- hover/press: brighten + 2px lift (buttons only)
	if gui:IsA("GuiButton") and opts.hover ~= false then
		gui.AutoButtonColor = false
		local hovering = false
		local function show(k, dy)
			local col = scaleColor(curFill, k)
			for _, f in ipairs(pieces) do
				TweenService:Create(f, QUICK, { BackgroundColor3 = col }):Play()
			end
			TweenService:Create(box, QUICK, { Position = base + UDim2.fromOffset(0, dy) }):Play()
		end
		gui.MouseEnter:Connect(function()
			hovering = true
			show(1.18, -2)
		end)
		gui.MouseLeave:Connect(function()
			hovering = false
			show(1, 0)
		end)
		gui.MouseButton1Down:Connect(function()
			show(0.85, 1)
		end)
		gui.MouseButton1Up:Connect(function()
			show(hovering and 1.18 or 1, hovering and -2 or 0)
		end)
	end
	handles[gui] = handle
	return handle
end

-- Sharp accent notch for headers: a bright slanted bar left of a title label.
function Shape.accent(label, color)
	local bar = new("Frame", {
		Name = "Accent", BorderSizePixel = 0, BackgroundColor3 = color or Shape.DEFAULT_EDGE,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.new(0, 4, 0.8, 0),
		Rotation = 12, ZIndex = label.ZIndex,
	}, label)
	return bar
end

-- Empty, sized icon slot (real images drop in later via slot.Image). Keeps layouts stable.
-- Hover tooltip (name of a blank icon slot etc). Sharp dark plate with a neon edge, above the target.
function Shape.tooltip(target, text, edge)
	local tip = new("TextLabel", {
		Name = "Tip", Text = text, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(math.max(56, #text * 7 + 14), 18), BackgroundColor3 = Color3.fromRGB(10, 8, 20),
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, Visible = false, ZIndex = 20,
	}, target)
	Shape.apply(tip, { cut = 4, edge = edge or Shape.DEFAULT_EDGE, thickness = 1 })
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

return Shape
