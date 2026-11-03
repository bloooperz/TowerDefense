--!strict
-- Unit model registry. Each unit id resolves to ONE visual source, in priority order:
--   1. "folder":      a Model at ReplicatedStorage.Assets.UnitModels.<UnitId> (drop in via Studio;
--                     see docs/UNIT_MODELS.md). Scripts inside are stripped on clone.
--   2. "placeholder": a procedural mannequin built from Parts in code (PLACEHOLDERS below).
--   3. "cube":        the original cube (+ optional topper), colored by the caller.
-- Visual only: every part is Anchored, CanCollide/CanQuery/CanTouch/CastShadow false, Massless. Templates are
-- looked up once per unit id and cached; each use gets one clone. No per-frame work.
-- Pure helpers (source, scaleFor, frameDistance, PLACEHOLDERS) run under lune for tests.
local UnitModels = {}

UnitModels.FOLDER = { "Assets", "UnitModels" } -- under ReplicatedStorage

-- Part spec: { name, size = {x,y,z}, pos = {x,y,z} (center, feet at y = 0), color = key|{r,g,b},
--   rot? = {x,y,z} degrees, shape? = "wedge" (WedgePart) | "cylinder" (Part, axis = local X) }
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
	-- original dark-haired summoner, stocky R6 build built from many thin parts: wide layered spiky hair
	-- (3 stacked tapering wedges per spike), chin-high collar, charcoal-navy jacket with layered lapels/seams/folds,
	-- tapered wedge-panel sleeves, pants with knee + cuff wedges, brass accents, 6-segment curved steel blade.
	Basic = {
		palette = {
			skin = { 236, 218, 204 }, hair = { 18, 18, 22 }, jacket = { 38, 40, 52 }, jacket2 = { 32, 34, 45 }, lapel = { 48, 50, 64 },
			trim = { 70, 70, 80 }, belt = { 24, 24, 28 }, pants = { 28, 28, 34 }, pants2 = { 34, 34, 42 }, shoes = { 14, 14, 16 },
			sole = { 40, 38, 36 }, brass = { 160, 136, 80 }, blade = { 110, 116, 126 }, fuller = { 70, 74, 84 }, grip = { 22, 20, 22 },
			wrap = { 44, 48, 66 },
		},
		parts = {
			{ name = "LeftSole", size = { 0.99, 0.08, 1.12 }, pos = { -0.5, 0.04, -0.05 }, color = "sole" },
			{ name = "LeftShoe", size = { 0.95, 0.3, 0.9 }, pos = { -0.5, 0.23, 0.05 }, color = "shoes" },
			{ name = "LeftToe", size = { 0.95, 0.3, 0.3 }, pos = { -0.5, 0.23, -0.45 }, color = "shoes", shape = "wedge" },
			{ name = "LeftShin", size = { 0.9, 0.62, 0.88 }, pos = { -0.5, 0.68, 0.0 }, color = "pants" },
			{ name = "LeftThigh", size = { 0.96, 0.6, 0.94 }, pos = { -0.5, 1.3, 0.0 }, color = "pants" },
			{ name = "LeftKneeFront", size = { 0.92, 0.22, 0.12 }, pos = { -0.5, 1.0, -0.48 }, color = "pants2", shape = "wedge" },
			{ name = "LeftKneeBack", size = { 0.92, 0.22, 0.12 }, pos = { -0.5, 1.0, 0.48 }, rot = { 0.0, 180.0, 0.0 }, color = "pants2", shape = "wedge" },
			{ name = "LeftPantCuff", size = { 1.0, 0.2, 0.3 }, pos = { -0.5, 0.48, -0.52 }, color = "pants", shape = "wedge" },
			{ name = "LeftPantCuffBack", size = { 1.0, 0.2, 0.3 }, pos = { -0.5, 0.48, 0.52 }, rot = { 0.0, 180.0, 0.0 }, color = "pants", shape = "wedge" },
			{ name = "LeftPantCuffSide", size = { 0.3, 0.2, 0.94 }, pos = { -1.0, 0.48, 0.0 }, rot = { 0.0, 90.0, 0.0 }, color = "pants", shape = "wedge" },
			{ name = "LeftLegSeam", size = { 0.03, 1.1, 0.06 }, pos = { -0.99, 1.0, 0.0 }, color = "pants2" },
			{ name = "RightSole", size = { 0.99, 0.08, 1.12 }, pos = { 0.5, 0.04, -0.05 }, color = "sole" },
			{ name = "RightShoe", size = { 0.95, 0.3, 0.9 }, pos = { 0.5, 0.23, 0.05 }, color = "shoes" },
			{ name = "RightToe", size = { 0.95, 0.3, 0.3 }, pos = { 0.5, 0.23, -0.45 }, color = "shoes", shape = "wedge" },
			{ name = "RightShin", size = { 0.9, 0.62, 0.88 }, pos = { 0.5, 0.68, 0.0 }, color = "pants" },
			{ name = "RightThigh", size = { 0.96, 0.6, 0.94 }, pos = { 0.5, 1.3, 0.0 }, color = "pants" },
			{ name = "RightKneeFront", size = { 0.92, 0.22, 0.12 }, pos = { 0.5, 1.0, -0.48 }, color = "pants2", shape = "wedge" },
			{ name = "RightKneeBack", size = { 0.92, 0.22, 0.12 }, pos = { 0.5, 1.0, 0.48 }, rot = { 0.0, 180.0, 0.0 }, color = "pants2", shape = "wedge" },
			{ name = "RightPantCuff", size = { 1.0, 0.2, 0.3 }, pos = { 0.5, 0.48, -0.52 }, color = "pants", shape = "wedge" },
			{ name = "RightPantCuffBack", size = { 1.0, 0.2, 0.3 }, pos = { 0.5, 0.48, 0.52 }, rot = { 0.0, 180.0, 0.0 }, color = "pants", shape = "wedge" },
			{ name = "RightPantCuffSide", size = { 0.3, 0.2, 0.94 }, pos = { 1.0, 0.48, 0.0 }, rot = { 0.0, -90.0, 0.0 }, color = "pants", shape = "wedge" },
			{ name = "RightLegSeam", size = { 0.03, 1.1, 0.06 }, pos = { 0.99, 1.0, 0.0 }, color = "pants2" },
			{ name = "Torso", size = { 2.0, 1.8, 1.0 }, pos = { 0.0, 2.5, 0.0 }, color = "jacket", primary = true },
			{ name = "Hem", size = { 2.08, 0.2, 1.08 }, pos = { 0.0, 1.7, 0.0 }, color = "trim" },
			{ name = "HemFoldL", size = { 0.5, 0.22, 0.12 }, pos = { -0.6, 1.86, -0.53 }, color = "jacket2", shape = "wedge" },
			{ name = "HemFoldR", size = { 0.5, 0.22, 0.12 }, pos = { 0.6, 1.86, -0.53 }, color = "jacket2", shape = "wedge" },
			{ name = "Belt", size = { 2.06, 0.18, 1.06 }, pos = { 0.0, 1.95, 0.0 }, color = "belt" },
			{ name = "Buckle", size = { 0.08, 0.3, 0.3 }, pos = { 0.0, 1.95, -0.55 }, rot = { 0.0, 90.0, 0.0 }, color = "brass", shape = "cylinder" },
			{ name = "BucklePin", size = { 0.04, 0.14, 0.04 }, pos = { 0.0, 1.95, -0.6 }, color = "belt" },
			{ name = "FrontSeam", size = { 0.07, 1.2, 0.04 }, pos = { 0.0, 2.45, -0.52 }, color = "trim" },
			{ name = "BackSeam", size = { 0.05, 1.5, 0.04 }, pos = { 0.0, 2.6, 0.52 }, color = "jacket2" },
			{ name = "SideFoldL", size = { 0.05, 1.2, 0.6 }, pos = { -1.01, 2.5, 0.0 }, color = "jacket2" },
			{ name = "SideFoldR", size = { 0.05, 1.2, 0.6 }, pos = { 1.01, 2.5, 0.0 }, color = "jacket2" },
			{ name = "ChestPanelL", size = { 0.6, 0.55, 0.05 }, pos = { -0.55, 2.55, -0.52 }, color = "jacket2" },
			{ name = "ChestPanelR", size = { 0.6, 0.55, 0.05 }, pos = { 0.55, 2.55, -0.52 }, color = "jacket2" },
			{ name = "Button1", size = { 0.13, 0.13, 0.06 }, pos = { 0.17, 2.25, -0.55 }, color = "brass" },
			{ name = "Button2", size = { 0.13, 0.13, 0.06 }, pos = { 0.17, 2.7, -0.55 }, color = "brass" },
			{ name = "LapelL", size = { 0.5, 0.85, 0.14 }, pos = { -0.3, 2.95, -0.57 }, rot = { 0.0, 180.0, 0.0 }, color = "lapel", shape = "wedge" },
			{ name = "LapelLUpper", size = { 0.35, 0.4, 0.1 }, pos = { -0.42, 3.2, -0.62 }, rot = { 0.0, 180.0, 10.0 }, color = "lapel", shape = "wedge" },
			{ name = "LapelLEdge", size = { 0.06, 0.8, 0.08 }, pos = { -0.08, 2.95, -0.64 }, rot = { 0.0, 0.0, 12.0 }, color = "trim" },
			{ name = "LapelR", size = { 0.5, 0.85, 0.14 }, pos = { 0.3, 2.95, -0.57 }, rot = { 0.0, 180.0, 0.0 }, color = "lapel", shape = "wedge" },
			{ name = "LapelRUpper", size = { 0.35, 0.4, 0.1 }, pos = { 0.42, 3.2, -0.62 }, rot = { 0.0, 180.0, -10.0 }, color = "lapel", shape = "wedge" },
			{ name = "LapelREdge", size = { 0.06, 0.8, 0.08 }, pos = { 0.08, 2.95, -0.64 }, rot = { 0.0, 0.0, -12.0 }, color = "trim" },
			{ name = "LeftShoulder", size = { 0.6, 0.5, 1.05 }, pos = { -1.05, 3.15, 0.0 }, color = "jacket" },
			{ name = "LeftShoulderCap", size = { 1.05, 0.22, 0.35 }, pos = { -1.23, 3.46, 0.0 }, rot = { 0.0, 90.0, 0.0 }, color = "jacket", shape = "wedge" },
			{ name = "RightShoulder", size = { 0.6, 0.5, 1.05 }, pos = { 1.05, 3.15, 0.0 }, color = "jacket" },
			{ name = "RightShoulderCap", size = { 1.05, 0.22, 0.35 }, pos = { 1.23, 3.46, 0.0 }, rot = { 0.0, -90.0, 0.0 }, color = "jacket", shape = "wedge" },
			{ name = "LeftSleeve", size = { 0.66, 1.5, 0.66 }, pos = { -1.6, 2.65, 0.0 }, color = "jacket" },
			{ name = "LeftSleeveOutU", size = { 0.72, 0.75, 0.11 }, pos = { -1.98, 3.0, 0.0 }, rot = { 0.0, -90.0, 0.0 }, color = "jacket2", shape = "wedge" },
			{ name = "LeftSleeveFrontU", size = { 0.72, 0.75, 0.11 }, pos = { -1.6, 3.0, -0.38 }, color = "jacket", shape = "wedge" },
			{ name = "LeftSleeveBackU", size = { 0.72, 0.75, 0.11 }, pos = { -1.6, 3.0, 0.38 }, rot = { 0.0, 180.0, 0.0 }, color = "jacket", shape = "wedge" },
			{ name = "LeftSleeveOutL", size = { 0.72, 0.65, 0.09 }, pos = { -1.98, 2.3, 0.0 }, rot = { 0.0, -90.0, 180.0 }, color = "jacket2", shape = "wedge" },
			{ name = "LeftSleeveFrontL", size = { 0.72, 0.65, 0.09 }, pos = { -1.6, 2.3, -0.38 }, rot = { 0.0, 0.0, 180.0 }, color = "jacket", shape = "wedge" },
			{ name = "LeftSleeveBackL", size = { 0.72, 0.65, 0.09 }, pos = { -1.6, 2.3, 0.38 }, rot = { 0.0, 180.0, 180.0 }, color = "jacket", shape = "wedge" },
			{ name = "LeftCuff", size = { 0.86, 0.22, 0.86 }, pos = { -1.6, 1.95, 0.0 }, color = "trim" },
			{ name = "LeftCuffFlare", size = { 0.86, 0.12, 0.2 }, pos = { -1.6, 2.1, -0.48 }, color = "trim", shape = "wedge" },
			{ name = "LeftHand", size = { 0.6, 0.5, 0.6 }, pos = { -1.6, 1.6, 0.0 }, color = "skin" },
			{ name = "RightSleeve", size = { 0.66, 1.5, 0.66 }, pos = { 1.6, 2.65, 0.0 }, color = "jacket" },
			{ name = "RightSleeveOutU", size = { 0.72, 0.75, 0.11 }, pos = { 1.98, 3.0, 0.0 }, rot = { 0.0, 90.0, 0.0 }, color = "jacket2", shape = "wedge" },
			{ name = "RightSleeveFrontU", size = { 0.72, 0.75, 0.11 }, pos = { 1.6, 3.0, -0.38 }, color = "jacket", shape = "wedge" },
			{ name = "RightSleeveBackU", size = { 0.72, 0.75, 0.11 }, pos = { 1.6, 3.0, 0.38 }, rot = { 0.0, 180.0, 0.0 }, color = "jacket", shape = "wedge" },
			{ name = "RightSleeveOutL", size = { 0.72, 0.65, 0.09 }, pos = { 1.98, 2.3, 0.0 }, rot = { 0.0, 90.0, 180.0 }, color = "jacket2", shape = "wedge" },
			{ name = "RightSleeveFrontL", size = { 0.72, 0.65, 0.09 }, pos = { 1.6, 2.3, -0.38 }, rot = { 0.0, 0.0, 180.0 }, color = "jacket", shape = "wedge" },
			{ name = "RightSleeveBackL", size = { 0.72, 0.65, 0.09 }, pos = { 1.6, 2.3, 0.38 }, rot = { 0.0, 180.0, 180.0 }, color = "jacket", shape = "wedge" },
			{ name = "RightCuff", size = { 0.86, 0.22, 0.86 }, pos = { 1.6, 1.95, 0.0 }, color = "trim" },
			{ name = "RightCuffFlare", size = { 0.86, 0.12, 0.2 }, pos = { 1.6, 2.1, -0.48 }, color = "trim", shape = "wedge" },
			{ name = "RightHand", size = { 0.6, 0.5, 0.6 }, pos = { 1.6, 1.6, 0.0 }, color = "skin" },
			{ name = "CollarBack", size = { 1.6, 0.55, 0.25 }, pos = { 0.0, 3.6, 0.5 }, color = "jacket" },
			{ name = "CollarLeft", size = { 0.25, 0.5, 1.2 }, pos = { -0.8, 3.58, 0.0 }, color = "jacket" },
			{ name = "CollarRight", size = { 0.25, 0.5, 1.2 }, pos = { 0.8, 3.58, 0.0 }, color = "jacket" },
			{ name = "CollarFrontL", size = { 0.72, 0.32, 0.22 }, pos = { -0.4, 3.52, -0.72 }, color = "jacket" },
			{ name = "CollarFrontR", size = { 0.72, 0.32, 0.22 }, pos = { 0.4, 3.52, -0.72 }, color = "jacket" },
			{ name = "CollarEdge", size = { 1.6, 0.07, 0.24 }, pos = { 0.0, 3.71, -0.72 }, color = "trim" },
			{ name = "CollarEdgeBack", size = { 1.66, 0.07, 0.27 }, pos = { 0.0, 3.9, 0.5 }, color = "trim" },
			{ name = "CollarEdgeL", size = { 0.27, 0.07, 1.2 }, pos = { -0.8, 3.85, 0.0 }, color = "trim" },
			{ name = "CollarEdgeR", size = { 0.27, 0.07, 1.2 }, pos = { 0.8, 3.85, 0.0 }, color = "trim" },
			{ name = "Head", size = { 1.35, 1.35, 1.35 }, pos = { 0.0, 4.12, 0.0 }, color = "skin" },
			{ name = "HairCap", size = { 1.5, 0.3, 1.5 }, pos = { 0.0, 4.9, 0.02 }, color = "hair" },
			{ name = "HairBack", size = { 1.5, 0.9, 0.3 }, pos = { 0.0, 4.4, 0.75 }, color = "hair" },
			{ name = "HairBackLow", size = { 1.3, 0.3, 0.22 }, pos = { 0.0, 3.9, 0.8 }, color = "hair", shape = "wedge" },
			{ name = "HairLeft", size = { 0.22, 0.6, 1.3 }, pos = { -0.78, 4.5, 0.05 }, color = "hair" },
			{ name = "HairRight", size = { 0.22, 0.6, 1.3 }, pos = { 0.78, 4.5, 0.05 }, color = "hair" },
			{ name = "SpikeTop1", size = { 0.34, 0.32, 0.46 }, pos = { -0.613, 5.093, 0.25 }, rot = { 0.0, 0.0, 45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop1b", size = { 0.245, 0.23, 0.331 }, pos = { -0.785, 5.265, 0.25 }, rot = { 0.0, 0.0, 45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop1c", size = { 0.153, 0.144, 0.207 }, pos = { -0.901, 5.381, 0.25 }, rot = { 0.0, 0.0, 45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop2", size = { 0.34, 0.32, 0.46 }, pos = { -0.12, 5.119, -0.1 }, rot = { 0.0, 180.0, 30.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop2b", size = { 0.245, 0.23, 0.331 }, pos = { 0.002, 5.329, -0.1 }, rot = { 0.0, 180.0, 30.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop2c", size = { 0.153, 0.144, 0.207 }, pos = { 0.084, 5.471, -0.1 }, rot = { 0.0, 180.0, 30.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop3", size = { 0.34, 0.32, 0.46 }, pos = { 0.235, 5.116, 0.3 }, rot = { 0.0, 0.0, -32.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop3b", size = { 0.245, 0.23, 0.331 }, pos = { 0.364, 5.322, 0.3 }, rot = { 0.0, 0.0, -32.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop3c", size = { 0.153, 0.144, 0.207 }, pos = { 0.451, 5.461, 0.3 }, rot = { 0.0, 0.0, -32.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop4", size = { 0.34, 0.32, 0.46 }, pos = { 0.387, 5.093, -0.05 }, rot = { 0.0, 180.0, -45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop4b", size = { 0.245, 0.23, 0.331 }, pos = { 0.215, 5.265, -0.05 }, rot = { 0.0, 180.0, -45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop4c", size = { 0.153, 0.144, 0.207 }, pos = { 0.099, 5.381, -0.05 }, rot = { 0.0, 180.0, -45.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop5", size = { 0.34, 0.32, 0.46 }, pos = { -0.022, 5.138, 0.5 }, rot = { 0.0, 0.0, 8.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop5b", size = { 0.245, 0.23, 0.331 }, pos = { -0.056, 5.379, 0.5 }, rot = { 0.0, 0.0, 8.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeTop5c", size = { 0.153, 0.144, 0.207 }, pos = { -0.079, 5.542, 0.5 }, rot = { 0.0, 0.0, 8.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL1", size = { 0.32, 0.3, 0.4 }, pos = { -0.98, 4.875, 0.1 }, rot = { 0.0, 0.0, 60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL1b", size = { 0.23, 0.216, 0.288 }, pos = { -1.177, 4.989, 0.1 }, rot = { 0.0, 0.0, 60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL1c", size = { 0.144, 0.135, 0.18 }, pos = { -1.311, 5.066, 0.1 }, rot = { 0.0, 0.0, 60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL2", size = { 0.32, 0.3, 0.4 }, pos = { -1.049, 4.563, 0.3 }, rot = { 0.0, 0.0, 85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL2b", size = { 0.23, 0.216, 0.288 }, pos = { -1.277, 4.583, 0.3 }, rot = { 0.0, 0.0, 85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL2c", size = { 0.144, 0.135, 0.18 }, pos = { -1.43, 4.596, 0.3 }, rot = { 0.0, 0.0, 85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL3", size = { 0.32, 0.3, 0.4 }, pos = { -1.018, 4.274, 0.5 }, rot = { 0.0, 0.0, 100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL3b", size = { 0.23, 0.216, 0.288 }, pos = { -1.242, 4.234, 0.5 }, rot = { 0.0, 0.0, 100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutL3c", size = { 0.144, 0.135, 0.18 }, pos = { -1.394, 4.208, 0.5 }, rot = { 0.0, 0.0, 100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR1", size = { 0.32, 0.3, 0.4 }, pos = { 0.98, 4.875, 0.1 }, rot = { 0.0, 0.0, -60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR1b", size = { 0.23, 0.216, 0.288 }, pos = { 1.177, 4.989, 0.1 }, rot = { 0.0, 0.0, -60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR1c", size = { 0.144, 0.135, 0.18 }, pos = { 1.311, 5.066, 0.1 }, rot = { 0.0, 0.0, -60.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR2", size = { 0.32, 0.3, 0.4 }, pos = { 1.049, 4.563, 0.3 }, rot = { 0.0, 0.0, -85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR2b", size = { 0.23, 0.216, 0.288 }, pos = { 1.277, 4.583, 0.3 }, rot = { 0.0, 0.0, -85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR2c", size = { 0.144, 0.135, 0.18 }, pos = { 1.43, 4.596, 0.3 }, rot = { 0.0, 0.0, -85.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR3", size = { 0.32, 0.3, 0.4 }, pos = { 1.018, 4.274, 0.5 }, rot = { 0.0, 0.0, -100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR3b", size = { 0.23, 0.216, 0.288 }, pos = { 1.242, 4.234, 0.5 }, rot = { 0.0, 0.0, -100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeOutR3c", size = { 0.144, 0.135, 0.18 }, pos = { 1.394, 4.208, 0.5 }, rot = { 0.0, 0.0, -100.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack1", size = { 0.34, 0.3, 0.36 }, pos = { -0.501, 4.686, 0.714 }, rot = { -75.0, 0.0, 20.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack1b", size = { 0.245, 0.216, 0.259 }, pos = { -0.579, 4.742, 0.507 }, rot = { -75.0, 0.0, 20.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack1c", size = { 0.153, 0.135, 0.162 }, pos = { -0.632, 4.779, 0.367 }, rot = { -75.0, 0.0, 20.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack2", size = { 0.34, 0.3, 0.36 }, pos = { -0.074, 4.338, 0.707 }, rot = { -75.0, 0.0, -10.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack2b", size = { 0.245, 0.216, 0.259 }, pos = { -0.034, 4.396, 0.49 }, rot = { -75.0, 0.0, -10.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack2c", size = { 0.153, 0.135, 0.162 }, pos = { -0.008, 4.436, 0.344 }, rot = { -75.0, 0.0, -10.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack3", size = { 0.34, 0.3, 0.36 }, pos = { 0.211, 4.637, 0.71 }, rot = { -75.0, 0.0, 15.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack3b", size = { 0.245, 0.216, 0.259 }, pos = { 0.152, 4.694, 0.497 }, rot = { -75.0, 0.0, 15.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack3c", size = { 0.153, 0.135, 0.162 }, pos = { 0.112, 4.733, 0.354 }, rot = { -75.0, 0.0, 15.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack4", size = { 0.34, 0.3, 0.36 }, pos = { 0.551, 4.286, 0.714 }, rot = { -75.0, 0.0, -20.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack4b", size = { 0.245, 0.216, 0.259 }, pos = { 0.629, 4.342, 0.507 }, rot = { -75.0, 0.0, -20.0 }, color = "hair", shape = "wedge" },
			{ name = "SpikeBack4c", size = { 0.153, 0.135, 0.162 }, pos = { 0.682, 4.379, 0.367 }, rot = { -75.0, 0.0, -20.0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe1", size = { 0.27, 0.3, 0.22 }, pos = { -0.52, 4.62, -0.76 }, rot = { 180.0, 0.0, -12.0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe2", size = { 0.27, 0.38, 0.22 }, pos = { -0.26, 4.62, -0.76 }, rot = { 180.0, 0.0, -6.0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe3", size = { 0.27, 0.3, 0.22 }, pos = { 0.0, 4.62, -0.76 }, rot = { 180.0, 0.0, 0.0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe4", size = { 0.27, 0.38, 0.22 }, pos = { 0.26, 4.62, -0.76 }, rot = { 180.0, 0.0, 6.0 }, color = "hair", shape = "wedge" },
			{ name = "Fringe5", size = { 0.27, 0.3, 0.22 }, pos = { 0.52, 4.62, -0.76 }, rot = { 180.0, 0.0, 12.0 }, color = "hair", shape = "wedge" },
			{ name = "Pommel", size = { 0.14, 0.3, 0.3 }, pos = { 1.35, 1.817, 0.375 }, rot = { -30.0, 60.0, 0.0 }, color = "brass", shape = "cylinder" },
			{ name = "Wrap1", size = { 0.13, 0.28, 0.28 }, pos = { 1.42, 1.756, 0.27 }, rot = { -30.0, 60.0, 0.0 }, color = "wrap", shape = "cylinder" },
			{ name = "Wrap2", size = { 0.15, 0.23, 0.23 }, pos = { 1.495, 1.691, 0.158 }, rot = { -30.0, 60.0, 0.0 }, color = "grip", shape = "cylinder" },
			{ name = "Wrap3", size = { 0.13, 0.28, 0.28 }, pos = { 1.57, 1.626, 0.045 }, rot = { -30.0, 60.0, 0.0 }, color = "wrap", shape = "cylinder" },
			{ name = "Wrap4", size = { 0.15, 0.23, 0.23 }, pos = { 1.645, 1.561, -0.067 }, rot = { -30.0, 60.0, 0.0 }, color = "grip", shape = "cylinder" },
			{ name = "Wrap5", size = { 0.13, 0.28, 0.28 }, pos = { 1.72, 1.496, -0.18 }, rot = { -30.0, 60.0, 0.0 }, color = "wrap", shape = "cylinder" },
			{ name = "Guard", size = { 0.8, 0.8, 0.1 }, pos = { 1.81, 1.418, -0.315 }, rot = { -30.0, -30.0, 0.0 }, color = "brass" },
			{ name = "GuardRim", size = { 0.86, 0.12, 0.12 }, pos = { 1.84, 1.392, -0.36 }, rot = { -30.0, -30.0, 0.0 }, color = "brass" },
			{ name = "Blade1", size = { 0.2, 0.3, 0.403 }, pos = { 1.956, 1.285, -0.529 }, rot = { -33.0, -30.0, 0.0 }, color = "blade" },
			{ name = "Fuller1", size = { 0.02, 0.08, 0.666 }, pos = { 2.142, 1.229, -0.628 }, rot = { -31.5, -30.0, 0.0 }, color = "fuller" },
			{ name = "Blade2", size = { 0.2, 0.3, 0.403 }, pos = { 2.147, 1.111, -0.812 }, rot = { -30.0, -30.0, 0.0 }, color = "blade" },
			{ name = "Blade3", size = { 0.2, 0.3, 0.403 }, pos = { 2.339, 0.953, -1.103 }, rot = { -27.0, -30.0, 0.0 }, color = "blade" },
			{ name = "Fuller2", size = { 0.02, 0.08, 0.666 }, pos = { 2.525, 0.908, -1.207 }, rot = { -25.5, -30.0, 0.0 }, color = "fuller" },
			{ name = "Blade4", size = { 0.2, 0.3, 0.403 }, pos = { 2.53, 0.81, -1.402 }, rot = { -24.0, -30.0, 0.0 }, color = "blade" },
			{ name = "Blade5", size = { 0.2, 0.3, 0.403 }, pos = { 2.722, 0.683, -1.709 }, rot = { -21.0, -30.0, 0.0 }, color = "blade" },
			{ name = "Fuller3", size = { 0.02, 0.08, 0.666 }, pos = { 2.908, 0.65, -1.817 }, rot = { -19.5, -30.0, 0.0 }, color = "fuller" },
			{ name = "Blade6", size = { 0.2, 0.3, 0.403 }, pos = { 2.913, 0.573, -2.021 }, rot = { -18.0, -30.0, 0.0 }, color = "blade", shape = "wedge" },
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
			d.CastShadow = false -- many small visual parts: skip shadow cost
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
		if p.shape == "cylinder" then
			(part :: Part).Shape = Enum.PartType.Cylinder -- axis = local X (size.X = length)
		end
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
