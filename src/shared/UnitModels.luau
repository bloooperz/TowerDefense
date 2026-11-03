--!strict
-- Unit model registry. Each unit id resolves to ONE visual source, in priority order:
--   1. "folder":      a Model at ReplicatedStorage.Assets.UnitModels.<UnitId> (drop in via Studio;
--                     see docs/UNIT_MODELS.md). Scripts inside are stripped on clone.
--   2. "placeholder": a procedural mannequin built from Parts in code (PLACEHOLDERS below).
--   3. "cube":        the original cube (+ optional topper), colored by the caller.
-- Visual only: every part is Anchored, CanCollide/CanQuery/CanTouch false, Massless. Templates are
-- looked up once per unit id and cached; each use gets one clone. No per-frame work.
-- Pure helpers (source, scaleFor, frameDistance, PLACEHOLDERS) run under lune for tests.
local UnitModels = {}

UnitModels.FOLDER = { "Assets", "UnitModels" } -- under ReplicatedStorage

-- Part spec: { name, size = {x,y,z}, pos = {x,y,z} (center, feet at y = 0), color = key|{r,g,b},
--   rot? = {x,y,z} degrees, shape? = "wedge" (WedgePart) }
-- Body colors per unit; "body"/"accent"/"skin"/"metal" keys resolve through the unit's palette.
local MANNEQUIN = {
	{ name = "LeftLeg", size = { 0.9, 2, 0.9 }, pos = { -0.5, 1, 0 }, color = "body" },
	{ name = "RightLeg", size = { 0.9, 2, 0.9 }, pos = { 0.5, 1, 0 }, color = "body" },
	{ name = "Torso", size = { 2, 2, 1 }, pos = { 0, 3, 0 }, color = "accent", primary = true },
	{ name = "LeftArm", size = { 0.8, 2, 0.8 }, pos = { -1.4, 3, 0 }, color = "body" },
	{ name = "RightArm", size = { 0.8, 2, 0.8 }, pos = { 1.4, 3, 0 }, color = "body" },
	{ name = "Head", size = { 1.2, 1.2, 1.2 }, pos = { 0, 4.6, 0 }, color = "skin" },
}
local function with(extra)
	local out = table.clone(MANNEQUIN)
	for _, p in ipairs(extra) do
		table.insert(out, p)
	end
	return out
end
UnitModels.PLACEHOLDERS = {
	-- original dark-haired summoner: layered spiky hair, high-collar black uniform (seam, buttons,
	-- cuffs, hem, belt + buckle), pale face/hands, curved multi-part blade (fuller, guard, wrapped hilt, pommel)
	Basic = {
		palette = {
			skin = { 236, 218, 204 }, hair = { 20, 20, 24 }, jacket = { 30, 30, 34 }, seam = { 58, 58, 66 },
			pants = { 22, 22, 28 }, pants2 = { 30, 30, 38 }, shoes = { 14, 14, 16 }, sole = { 40, 38, 36 },
			brass = { 150, 128, 78 }, blade = { 60, 64, 70 }, fuller = { 92, 98, 108 }, grip = { 22, 20, 22 }, wrap = { 44, 48, 66 },
		},
		parts = {
			{ name = "LeftSole", size = { 0.97, 0.08, 1.12 }, pos = { -0.5, 0.04, -0.05 }, color = "sole" },
			{ name = "RightSole", size = { 0.97, 0.08, 1.12 }, pos = { 0.5, 0.04, -0.05 }, color = "sole" },
			{ name = "LeftShoe", size = { 0.95, 0.35, 1.08 }, pos = { -0.5, 0.255, -0.05 }, color = "shoes" },
			{ name = "RightShoe", size = { 0.95, 0.35, 1.08 }, pos = { 0.5, 0.255, -0.05 }, color = "shoes" },
			{ name = "LeftLeg", size = { 0.9, 1.55, 0.9 }, pos = { -0.5, 1.2, 0 }, color = "pants" },
			{ name = "RightLeg", size = { 0.9, 1.55, 0.9 }, pos = { 0.5, 1.2, 0 }, color = "pants" },
			{ name = "LeftPantCuff", size = { 0.96, 0.18, 0.96 }, pos = { -0.5, 0.52, 0 }, color = "pants2" },
			{ name = "RightPantCuff", size = { 0.96, 0.18, 0.96 }, pos = { 0.5, 0.52, 0 }, color = "pants2" },
			{ name = "Torso", size = { 2, 2, 1 }, pos = { 0, 3, 0 }, color = "jacket", primary = true },
			{ name = "Hem", size = { 2.08, 0.28, 1.08 }, pos = { 0, 2.1, 0 }, color = "jacket" },
			{ name = "Belt", size = { 2.06, 0.2, 1.06 }, pos = { 0, 2.34, 0 }, color = "seam" },
			{ name = "Buckle", size = { 0.36, 0.26, 0.06 }, pos = { 0, 2.34, -0.55 }, color = "brass" },
			{ name = "FrontSeam", size = { 0.08, 1.5, 0.04 }, pos = { 0, 3.2, -0.52 }, color = "seam" },
			{ name = "Button1", size = { 0.14, 0.14, 0.06 }, pos = { 0.18, 2.7, -0.53 }, color = "brass" },
			{ name = "Button2", size = { 0.14, 0.14, 0.06 }, pos = { 0.18, 3.05, -0.53 }, color = "brass" },
			{ name = "Button3", size = { 0.14, 0.14, 0.06 }, pos = { 0.18, 3.4, -0.53 }, color = "brass" },
			{ name = "Button4", size = { 0.14, 0.14, 0.06 }, pos = { 0.18, 3.75, -0.53 }, color = "brass" },
			{ name = "CollarBack", size = { 1.6, 0.75, 0.25 }, pos = { 0, 4.3, 0.45 }, color = "jacket" },
			{ name = "CollarLeft", size = { 0.25, 0.75, 1.1 }, pos = { -0.72, 4.3, 0 }, color = "jacket" },
			{ name = "CollarRight", size = { 0.25, 0.75, 1.1 }, pos = { 0.72, 4.3, 0 }, color = "jacket" },
			{ name = "CollarFrontL", size = { 0.72, 0.6, 0.22 }, pos = { -0.37, 4.22, -0.5 }, color = "jacket" },
			{ name = "CollarFrontR", size = { 0.72, 0.6, 0.22 }, pos = { 0.37, 4.22, -0.5 }, color = "jacket" },
			{ name = "LeftSleeve", size = { 0.8, 1.6, 0.8 }, pos = { -1.4, 3.2, 0 }, color = "jacket" },
			{ name = "LeftCuff", size = { 0.86, 0.25, 0.86 }, pos = { -1.4, 2.4, 0 }, color = "seam" },
			{ name = "LeftHand", size = { 0.6, 0.5, 0.6 }, pos = { -1.4, 2.05, 0 }, color = "skin" },
			{ name = "RightSleeve", size = { 0.8, 1.6, 0.8 }, pos = { 1.4, 3.2, 0 }, color = "jacket" },
			{ name = "RightCuff", size = { 0.86, 0.25, 0.86 }, pos = { 1.4, 2.4, 0 }, color = "seam" },
			{ name = "RightHand", size = { 0.6, 0.5, 0.6 }, pos = { 1.4, 2.05, 0 }, color = "skin" },
			{ name = "Head", size = { 1.2, 1.2, 1.2 }, pos = { 0, 4.6, 0 }, color = "skin" },
			{ name = "HairCap", size = { 1.35, 0.35, 1.35 }, pos = { 0, 5.3, 0.02 }, color = "hair" },
			{ name = "HairBack", size = { 1.35, 1.0, 0.3 }, pos = { 0, 4.9, 0.66 }, color = "hair" },
			{ name = "HairLeft", size = { 0.22, 0.75, 1.2 }, pos = { -0.7, 5.0, 0.05 }, color = "hair" },
			{ name = "HairRight", size = { 0.22, 0.75, 1.2 }, pos = { 0.7, 5.0, 0.05 }, color = "hair" },
			{ name = "SpikeTop1", size = { 0.32, 0.75, 0.45 }, pos = { -0.45, 5.75, 0.25 }, rot = { 0, 0, 28 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop2", size = { 0.32, 0.75, 0.45 }, pos = { -0.15, 5.75, -0.1 }, rot = { 0, 180, 12 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop3", size = { 0.32, 0.75, 0.45 }, pos = { 0.15, 5.75, 0.3 }, rot = { 0, 0, -14 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop4", size = { 0.32, 0.75, 0.45 }, pos = { 0.45, 5.75, -0.05 }, rot = { 0, 180, -30 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop5", size = { 0.32, 0.75, 0.45 }, pos = { 0, 5.75, 0.5 }, rot = { 0, 0, 4 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack1", size = { 0.32, 0.7, 0.35 }, pos = { -0.45, 5.2, 0.85 }, rot = { -75, 0, 20 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack2", size = { 0.32, 0.7, 0.35 }, pos = { -0.1, 4.75, 0.85 }, rot = { -75, 0, -10 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack3", size = { 0.32, 0.7, 0.35 }, pos = { 0.25, 5.15, 0.85 }, rot = { -75, 0, 15 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack4", size = { 0.32, 0.7, 0.35 }, pos = { 0.5, 4.7, 0.85 }, rot = { -75, 0, -20 }, color = "hair", shape = "wedge" },
			{ name = "SpikeSideL1", size = { 0.3, 0.6, 0.35 }, pos = { -0.85, 5.15, 0.15 }, rot = { 0, 0, 65 }, color = "hair", shape = "wedge" },
			{ name = "SpikeSideL2", size = { 0.3, 0.55, 0.35 }, pos = { -0.85, 4.8, 0.4 }, rot = { 0, 0, 80 }, color = "hair", shape = "wedge" },
			{ name = "SpikeSideR1", size = { 0.3, 0.6, 0.35 }, pos = { 0.85, 5.15, 0.15 }, rot = { 0, 0, -65 }, color = "hair", shape = "wedge" },
			{ name = "SpikeSideR2", size = { 0.3, 0.55, 0.35 }, pos = { 0.85, 4.8, 0.4 }, rot = { 0, 0, -80 }, color = "hair", shape = "wedge" },
			{ name = "Fringe1", size = { 0.26, 0.45, 0.22 }, pos = { -0.48, 4.95, -0.66 }, rot = { 180, 0, -12 }, color = "hair", shape = "wedge" },
			{ name = "Fringe2", size = { 0.26, 0.57, 0.22 }, pos = { -0.24, 4.95, -0.66 }, rot = { 180, 0, -6 }, color = "hair", shape = "wedge" },
			{ name = "Fringe3", size = { 0.26, 0.45, 0.22 }, pos = { 0, 4.95, -0.66 }, rot = { 180, 0, 0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe4", size = { 0.26, 0.57, 0.22 }, pos = { 0.24, 4.95, -0.66 }, rot = { 180, 0, 6 }, color = "hair", shape = "wedge" },
			{ name = "Fringe5", size = { 0.26, 0.45, 0.22 }, pos = { 0.48, 4.95, -0.66 }, rot = { 180, 0, 12 }, color = "hair", shape = "wedge" },
			{ name = "Pommel", size = { 0.26, 0.26, 0.14 }, pos = { 1.4, 2.3, 0.433 }, rot = { -30, 0, 0 }, color = "brass" },
			{ name = "Wrap1", size = { 0.26, 0.26, 0.13 }, pos = { 1.4, 2.23, 0.312 }, rot = { -30, 0, 0 }, color = "wrap" },
			{ name = "Wrap2", size = { 0.22, 0.22, 0.15 }, pos = { 1.4, 2.155, 0.182 }, rot = { -30, 0, 0 }, color = "grip" },
			{ name = "Wrap3", size = { 0.26, 0.26, 0.13 }, pos = { 1.4, 2.08, 0.052 }, rot = { -30, 0, 0 }, color = "wrap" },
			{ name = "Wrap4", size = { 0.22, 0.22, 0.15 }, pos = { 1.4, 2.005, -0.078 }, rot = { -30, 0, 0 }, color = "grip" },
			{ name = "Wrap5", size = { 0.26, 0.26, 0.13 }, pos = { 1.4, 1.93, -0.208 }, rot = { -30, 0, 0 }, color = "wrap" },
			{ name = "Guard", size = { 0.58, 0.58, 0.08 }, pos = { 1.4, 1.84, -0.364 }, rot = { -30, 0, 0 }, color = "blade" },
			{ name = "GuardRim", size = { 0.64, 0.1, 0.1 }, pos = { 1.4, 1.81, -0.416 }, rot = { -30, 0, 0 }, color = "brass" },
			{ name = "Blade1", size = { 0.1, 0.3, 0.9 }, pos = { 1.4, 1.565, -0.84 }, rot = { -30, 0, 0 }, color = "blade" },
			{ name = "Fuller1", size = { 0.02, 0.08, 0.8 }, pos = { 1.455, 1.565, -0.84 }, rot = { -30, 0, 0 }, color = "fuller" },
			{ name = "Blade2", size = { 0.1, 0.3, 0.9 }, pos = { 1.4, 1.15, -1.638 }, rot = { -25, 0, 0 }, color = "blade" },
			{ name = "Fuller2", size = { 0.02, 0.08, 0.8 }, pos = { 1.455, 1.15, -1.638 }, rot = { -25, 0, 0 }, color = "fuller" },
			{ name = "Blade3", size = { 0.1, 0.3, 0.9 }, pos = { 1.4, 0.806, -2.468 }, rot = { -20, 0, 0 }, color = "blade" },
			{ name = "Fuller3", size = { 0.02, 0.08, 0.8 }, pos = { 1.455, 0.806, -2.468 }, rot = { -20, 0, 0 }, color = "fuller" },
		},
	},
	Rapid = { -- twin barrels
		palette = { body = { 160, 70, 30 }, accent = { 220, 120, 40 }, skin = { 230, 190, 150 }, metal = { 40, 40, 45 } },
		parts = with({
			{ name = "Visor", size = { 1.25, 0.35, 0.2 }, pos = { 0, 4.7, -0.6 }, color = "metal" },
			{ name = "BarrelL", size = { 0.25, 0.25, 2 }, pos = { 1.25, 2.7, -1.1 }, color = "metal" },
			{ name = "BarrelR", size = { 0.25, 0.25, 2 }, pos = { 1.6, 2.7, -1.1 }, color = "metal" },
		}),
	},
	Sniper = { -- long barrel + scope + hood
		palette = { body = { 40, 46, 60 }, accent = { 70, 80, 110 }, skin = { 210, 175, 140 }, metal = { 25, 25, 30 } },
		parts = with({
			{ name = "Hood", size = { 1.4, 0.7, 1.4 }, pos = { 0, 5.1, 0.1 }, color = "accent" },
			{ name = "Barrel", size = { 0.25, 0.25, 4 }, pos = { 1.4, 2.8, -2 }, color = "metal" },
			{ name = "Scope", size = { 0.3, 0.3, 0.8 }, pos = { 1.4, 3.15, -1 }, color = "metal" },
		}),
	},
}

-- Which source a unit uses. hasFolderModel: bool from the Assets lookup.
function UnitModels.source(unitId: string?, hasFolderModel: boolean?): string
	if hasFolderModel then
		return "folder"
	end
	if unitId and UnitModels.PLACEHOLDERS[unitId] then
		return "placeholder"
	end
	return "cube"
end

-- Uniform scale factor so the model's largest extent equals `target` studs.
function UnitModels.scaleFor(extents: { number }, target: number): number
	local m = math.max(extents[1] or 0, extents[2] or 0, extents[3] or 0)
	if m <= 0 or target <= 0 then
		return 1
	end
	return target / m
end

-- Camera distance that fits a bounding box of max extent `size` in a ~70 deg viewport FOV.
function UnitModels.frameDistance(size: number): number
	return math.max(size, 0.5) * 1.9
end

-------------------------------------------------------------------------- Roblox side
if not script then
	return UnitModels
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local cache = {} -- unitId -> Model | false (looked up once)

local function folderTemplate(unitId: string)
	if cache[unitId] ~= nil then
		return cache[unitId] or nil
	end
	local node: Instance? = ReplicatedStorage
	for _, n in ipairs(UnitModels.FOLDER) do
		node = node and node:FindFirstChild(n)
	end
	local m = node and node:FindFirstChild(unitId)
	if m and not m:IsA("Model") then
		m = nil
	end
	cache[unitId] = m or false
	return m
end

-- Clear the lookup cache (e.g. after models are added at runtime in Studio).
function UnitModels.reset()
	table.clear(cache)
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Anchored, non-colliding, no scripts, PrimaryPart set.
function UnitModels.prepare(model: Model): Model
	local biggest, vol = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = true, false, false, false, true
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then
				biggest, vol = d, v
			end
		end
	end
	if not model.PrimaryPart then
		local hrp = model:FindFirstChild("HumanoidRootPart", true)
		model.PrimaryPart = (hrp and hrp:IsA("BasePart") and hrp) or biggest
	end
	return model
end

local function buildPlaceholder(unitId: string): Model
	local spec = UnitModels.PLACEHOLDERS[unitId]
	local model = Instance.new("Model")
	model.Name = unitId
	for _, p in ipairs(spec.parts) do
		local part = Instance.new(p.shape == "wedge" and "WedgePart" or "Part")
		part.Name = p.name
		part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
		local r = p.rot or { 0, 0, 0 }
		part.CFrame = CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		part.Color = rgb(type(p.color) == "string" and spec.palette[p.color] or p.color)
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		if p.primary then
			model.PrimaryPart = part
		end
	end
	return model
end

local function buildCube(def, color: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Cube"
	local s = def and def.size or 3
	local c = Instance.new("Part")
	c.Name, c.Size, c.CFrame, c.Color = "Body", Vector3.one * s, CFrame.new(0, s / 2, 0), color or Color3.new(1, 1, 1)
	c.Parent = model
	model.PrimaryPart = c
	if def and def.topper then
		local t = Instance.new("Part")
		t.Name, t.Size, t.CFrame, t.Color = "Topper", Vector3.new(s, 0.4, s), CFrame.new(0, s + 0.2, 0), def.topper
		t.Parent = model
	end
	return model
end

-- Source this def resolves to ("folder" | "placeholder" | "cube") without building anything.
function UnitModels.kind(def): string
	local id = def and def.id
	return UnitModels.source(id, id ~= nil and folderTemplate(id) ~= nil)
end

-- One ready-to-use Model for `def` (unit def with .id/.size/.topper).
-- opts: { size = largest extent in studs (default def.size * 1.5; cube keeps def.size), color = cube color }
-- The model's pivot sits at its feet (bottom-center), so PivotTo(CFrame.new(groundPos)) stands it up.
function UnitModels.clone(def, opts): (Model, string)
	opts = opts or {}
	local id = def and def.id
	local tpl = id and folderTemplate(id)
	local kind = UnitModels.source(id, tpl ~= nil)
	local model
	if kind == "folder" then
		model = (tpl :: Model):Clone()
	elseif kind == "placeholder" then
		model = buildPlaceholder(id)
	else
		model = buildCube(def, opts.color)
	end
	UnitModels.prepare(model)
	if kind ~= "cube" then
		local _, ext = model:GetBoundingBox()
		local f = UnitModels.scaleFor({ ext.X, ext.Y, ext.Z }, opts.size or ((def and def.size or 3) * 1.5))
		if math.abs(f - 1) > 1e-3 then
			model:ScaleTo(model:GetScale() * f)
		end
	end
	-- feet pivot: bottom-center of the bounding box
	local cf, ext = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, ext.Y / 2, 0))
	model:PivotTo(CFrame.new())
	model:SetAttribute("ModelSource", kind)
	return model, kind
end

-- Point a viewport camera at `model` (3/4 view, whole model in frame).
function UnitModels.frame(cam: Camera, model: Model)
	local cf, ext = model:GetBoundingBox()
	local d = UnitModels.frameDistance(math.max(ext.X, ext.Y, ext.Z))
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(d * 0.7, d * 0.55, d * 0.7), cf.Position)
end

return UnitModels
