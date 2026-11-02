-- Live enemies. Movement is time-based distance along the map path:
--   dist = dist0 + (now - t0) * speed
-- The server "checkpoints" (dist0/t0/speed + attributes) only when speed changes.
-- The client PathRenderer reads the same attributes and draws the enemy.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatusLogic = require(Shared.StatusLogic)
local World = require(script.Parent.World)

local Enemies = {}
Enemies.list = {} -- [enemy] = true
Enemies.path = nil
Enemies.mapId = nil

function Enemies.now()
	return workspace:GetServerTimeNow()
end
local now = Enemies.now

function Enemies.setPath(path, mapId)
	Enemies.path, Enemies.mapId = path, mapId
end

function Enemies.distance(e, t)
	return math.clamp(e.dist0 + ((t or now()) - e.t0) * e.speed, 0, Enemies.path.length)
end

function Enemies.position(e)
	return Enemies.path:positionAt(Enemies.distance(e)) + Vector3.new(0, e.height, 0)
end

local function writeAttrs(e)
	local p = e.part
	p:SetAttribute("Dist", e.dist0)
	p:SetAttribute("CheckTime", e.t0)
	p:SetAttribute("Speed", e.speed)
end

-- Recompute speed from statuses and lock in the current distance.
function Enemies.checkpoint(e)
	local t = now()
	e.dist0 = Enemies.distance(e, t)
	e.t0 = t
	e.speed = e.baseSpeed * StatusLogic.speedMult(e.status, t)
	writeAttrs(e)
end

local function healthBar(e)
	local g = Instance.new("BillboardGui")
	g.Size, g.StudsOffsetWorldSpace = UDim2.fromOffset(math.clamp(e.def.size * 14, 30, 90), 8), Vector3.new(0, e.def.size / 2 + 1, 0)
	g.MaxDistance = 140
	local bg = Instance.new("Frame")
	bg.Size, bg.BackgroundColor3, bg.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(20, 20, 20), 0
	bg.Parent = g
	local fill = Instance.new("Frame")
	fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(60, 220, 60), 0
	fill.Parent = bg
	local shield = Instance.new("Frame")
	shield.Size, shield.BackgroundColor3, shield.BorderSizePixel = UDim2.fromScale(0, 0.4), Color3.fromRGB(80, 180, 255), 0
	shield.Parent = bg
	g.Parent = e.part
	e.bar, e.shieldBar = fill, shield
end

function Enemies.updateBar(e)
	if e.bar then
		e.bar.Size = UDim2.fromScale(math.clamp(e.hp / e.maxHp, 0, 1), 1)
		e.shieldBar.Size = UDim2.fromScale(e.maxShield > 0 and math.clamp(e.shield / e.maxShield, 0, 1) or 0, 0.4)
	end
end

-- def: enemy definition from shared/Enemies. mods: { hpMult, speedMult }
function Enemies.spawn(def, mods)
	mods = mods or {}
	local hpMult = mods.hpMult or 1
	local height = def.size / 2 + (def.flying and Config.FLY_HEIGHT or 0)
	local startPos = Enemies.path:positionAt(0) + Vector3.new(0, height, 0)
	local p = World.part({
		Name = def.id,
		Size = Vector3.one * def.size,
		CFrame = CFrame.new(startPos),
		Color = def.color,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = def.flying and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	}, nil)
	local e = {
		def = def,
		part = p,
		hp = def.hp * hpMult,
		maxHp = def.hp * hpMult,
		shield = (def.shield or 0) * hpMult,
		maxShield = (def.shield or 0) * hpMult,
		armor = def.armor or 0,
		regen = (def.regen or 0) * hpMult,
		flying = def.flying == true,
		boss = def.boss == true,
		height = height,
		baseSpeed = def.speed * (mods.speedMult or 1),
		status = StatusLogic.new(),
		alive = true,
		dist0 = 0,
		t0 = now(),
	}
	e.speed = e.baseSpeed
	p:SetAttribute("Height", height)
	p:SetAttribute("Enemy", true)
	writeAttrs(e)
	healthBar(e)
	p.Parent = World.movers
	Enemies.list[e] = true
	return e
end

function Enemies.applyStatus(e, id, params)
	if not e.alive then
		return
	end
	StatusLogic.apply(e.status, id, params, now(), { boss = e.boss })
	Enemies.checkpoint(e)
end

function Enemies.remove(e)
	if not e.alive then
		return
	end
	e.alive = false
	e.part:Destroy()
	Enemies.list[e] = nil
end

-- Targeting: First (furthest along), Last, Strongest, Weakest, Closest.
function Enemies.pick(pos, range, mode, canHitAir)
	local best, bestScore = nil, -math.huge
	local t = now()
	for e in pairs(Enemies.list) do
		if canHitAir ~= false or not e.flying then
			local d = (Enemies.position(e) - pos).Magnitude
			if d <= range then
				local progress = Enemies.distance(e, t)
				local score
				if mode == "Last" then
					score = -progress
				elseif mode == "Strongest" then
					score = e.hp + e.shield
				elseif mode == "Weakest" then
					score = -(e.hp + e.shield)
				elseif mode == "Closest" then
					score = -d
				else
					score = progress
				end
				if score > bestScore then
					best, bestScore = e, score
				end
			end
		end
	end
	return best
end

function Enemies.inRange(pos, range, canHitAir)
	local out = {}
	for e in pairs(Enemies.list) do
		if (canHitAir ~= false or not e.flying) and (Enemies.position(e) - pos).Magnitude <= range then
			table.insert(out, e)
		end
	end
	return out
end

function Enemies.count()
	local n = 0
	for _ in pairs(Enemies.list) do
		n += 1
	end
	return n
end

function Enemies.clear()
	for e in pairs(Enemies.list) do
		Enemies.remove(e)
	end
end

return Enemies
