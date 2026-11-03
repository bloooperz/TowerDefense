-- Live enemies. Movement is time-based distance along the map path:
--   dist = dist0 + (now - t0) * speed
-- The server "checkpoints" (dist0/t0/speed + attributes) only when speed changes.
-- The client PathRenderer reads the same attributes and draws the enemy.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatusLogic = require(Shared.StatusLogic)
local World = require(script.Parent.World)
local Net = require(Shared.Net)
local EnemyLife = require(Shared.EnemyLife)
local EnemyLabel = require(Shared.EnemyLabel)
local nextId = 0

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

-- Billboard: type name (top), HP number, bar (bottom). Text is set with real values at spawn
-- and the HP number only changes with the bar's 2% steps (no per-frame work, no extra connections).
local function outlined(parent, y, h, text, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Size, l.Position = 1, UDim2.new(1, 0, 0, h), UDim2.fromOffset(0, y)
	l.Font, l.TextScaled, l.Text = Enum.Font.GothamBold, true, text
	l.TextColor3, l.TextStrokeColor3, l.TextStrokeTransparency = color, Color3.new(0, 0, 0), 0
	l.Parent = parent
	return l
end
local function healthBar(e)
	local w = math.clamp(e.def.size * 14, 30, 90)
	local g = Instance.new("BillboardGui")
	g.Size, g.StudsOffsetWorldSpace = UDim2.fromOffset(math.max(w, 80), 34), Vector3.new(0, e.def.size / 2 + 1.8, 0)
	g.MaxDistance = 140
	outlined(g, 0, 14, EnemyLabel.name(e.def), Color3.new(1, 1, 1)).Name = "TypeName"
	e.hpText = outlined(g, 14, 12, EnemyLabel.hp(e.hp, e.maxHp), Color3.fromRGB(220, 255, 220))
	e.hpText.Name = "HpText"
	local bg = Instance.new("Frame")
	bg.AnchorPoint, bg.Position = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1)
	bg.Size, bg.BackgroundColor3, bg.BorderSizePixel = UDim2.fromOffset(w, 8), Color3.fromRGB(20, 20, 20), 0
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

-- Quantized to 2% steps so constant chip damage / boss regen doesn't flood replication
-- (that backlog is what delayed death replication on late waves).
local function q(x)
	return math.floor(math.clamp(x, 0, 1) * 50 + 0.5) / 50
end
function Enemies.updateBar(e)
	if e.bar and e.alive then
		local h = q(e.hp / e.maxHp)
		local s = e.maxShield > 0 and q(e.shield / e.maxShield) or 0
		if h ~= e.barH then
			e.barH = h
			e.bar.Size = UDim2.fromScale(h, 1)
			local t = EnemyLabel.hp(e.hp, e.maxHp)
			if e.hpText and t ~= e.hpText.Text then
				e.hpText.Text = t
			end
		end
		if s ~= e.barS then
			e.barS = s
			e.shieldBar.Size = UDim2.fromScale(s, 0.4)
		end
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
	nextId += 1
	local e = {
		id = nextId,
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
	p:SetAttribute("EnemyId", e.id)
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

-- Removes an enemy from the world immediately (death or leak). Safe to call twice.
-- e.alive may already be false (EnemyLife.hit marks death); list membership is the guard.
function Enemies.remove(e)
	e.alive = false
	if not Enemies.list[e] then
		return false
	end
	Enemies.list[e] = nil
	Net.fireAll("EnemyDied", e.id)
	e.part:Destroy()
	return true
end
Enemies.targetable = EnemyLife.targetable

-- Targeting: First (furthest along), Last, Strongest, Weakest, Closest.
function Enemies.pick(pos, range, mode, canHitAir)
	local best, bestScore = nil, -math.huge
	local t = now()
	for e in pairs(Enemies.list) do
		if EnemyLife.targetable(e) and (canHitAir ~= false or not e.flying) then
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
		if EnemyLife.targetable(e) and (canHitAir ~= false or not e.flying) and (Enemies.position(e) - pos).Magnitude <= range then
			table.insert(out, e)
		end
	end
	return out
end

-- Snapshot of live enemies: safe to iterate while hits remove enemies.
function Enemies.all()
	local out = {}
	for e in pairs(Enemies.list) do
		if e.alive then
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
	for _, e in ipairs(Enemies.all()) do
		Enemies.remove(e)
	end
end

return Enemies
