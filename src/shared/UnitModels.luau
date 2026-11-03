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
	Basic = { -- original dark-haired summoner: spiky black hair, high-collar black uniform, short dark blade
		palette = {
			skin = { 236, 218, 204 }, hair = { 20, 20, 24 }, jacket = { 30, 30, 34 }, seam = { 58, 58, 66 },
			pants = { 22, 22, 28 }, shoes = { 12, 12, 14 }, blade = { 60, 64, 70 }, grip = { 40, 30, 28 },
		},
		parts = {
			{ name = "LeftShoe", size = { 0.95, 0.4, 1.1 }, pos = { -0.5, 0.2, -0.05 }, color = "shoes" },
			{ name = "RightShoe", size = { 0.95, 0.4, 1.1 }, pos = { 0.5, 0.2, -0.05 }, color = "shoes" },
			{ name = "LeftLeg", size = { 0.9, 1.6, 0.9 }, pos = { -0.5, 1.2, 0 }, color = "pants" },
			{ name = "RightLeg", size = { 0.9, 1.6, 0.9 }, pos = { 0.5, 1.2, 0 }, color = "pants" },
			{ name = "Torso", size = { 2, 2, 1 }, pos = { 0, 3, 0 }, color = "jacket", primary = true },
			{ name = "Belt", size = { 2.05, 0.25, 1.05 }, pos = { 0, 2.15, 0 }, color = "seam" },
			{ name = "Seam", size = { 0.12, 1.7, 0.05 }, pos = { 0, 3.05, -0.52 }, color = "seam" },
			{ name = "Collar", size = { 1.5, 0.6, 1.25 }, pos = { 0, 4.15, 0.02 }, color = "jacket" },
			{ name = "LeftArm", size = { 0.8, 1.8, 0.8 }, pos = { -1.4, 3.1, 0 }, color = "jacket" },
			{ name = "RightArm", size = { 0.8, 1.8, 0.8 }, pos = { 1.4, 3.1, 0 }, color = "jacket" },
			{ name = "LeftHand", size = { 0.6, 0.55, 0.6 }, pos = { -1.4, 1.93, 0 }, color = "skin" },
			{ name = "RightHand", size = { 0.6, 0.55, 0.6 }, pos = { 1.4, 1.93, 0 }, color = "skin" },
			{ name = "Head", size = { 1.2, 1.2, 1.2 }, pos = { 0, 4.6, 0 }, color = "skin" },
			{ name = "HairTop", size = { 1.4, 0.4, 1.4 }, pos = { 0, 5.35, 0.02 }, color = "hair" },
			{ name = "HairBack", size = { 1.4, 1.0, 0.3 }, pos = { 0, 4.95, 0.68 }, color = "hair" },
			{ name = "HairLeft", size = { 0.25, 0.8, 1.3 }, pos = { -0.7, 4.95, 0.05 }, color = "hair" },
			{ name = "HairRight", size = { 0.25, 0.8, 1.3 }, pos = { 0.7, 4.95, 0.05 }, color = "hair" },
			{ name = "SpikeL", size = { 0.35, 0.8, 0.5 }, pos = { -0.4, 5.75, 0.1 }, rot = { 0, 0, 25 }, color = "hair", shape = "wedge" },
			{ name = "SpikeR", size = { 0.35, 0.8, 0.5 }, pos = { 0.4, 5.7, 0.2 }, rot = { 0, 180, 25 }, color = "hair", shape = "wedge" },
			{ name = "FringeL", size = { 0.35, 0.5, 0.25 }, pos = { -0.38, 4.95, -0.68 }, rot = { 180, 0, 10 }, color = "hair", shape = "wedge" },
			{ name = "FringeM", size = { 0.35, 0.6, 0.25 }, pos = { 0.02, 4.9, -0.68 }, rot = { 180, 0, -5 }, color = "hair", shape = "wedge" },
			{ name = "FringeR", size = { 0.35, 0.5, 0.25 }, pos = { 0.4, 4.95, -0.68 }, rot = { 180, 0, -12 }, color = "hair", shape = "wedge" },
			{ name = "Handle", size = { 0.22, 0.22, 0.7 }, pos = { 1.4, 1.85, -0.25 }, rot = { -30, 0, 0 }, color = "grip" },
			{ name = "Guard", size = { 0.6, 0.15, 0.15 }, pos = { 1.4, 1.7, -0.55 }, color = "blade" },
			{ name = "Blade", size = { 0.1, 0.3, 2.6 }, pos = { 1.4, 1.05, -1.68 }, rot = { -30, 0, 0 }, color = "blade" },
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
