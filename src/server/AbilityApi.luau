-- Utility API handed to abilities. Abilities should only touch the game through this.
local Enemies = require(script.Parent.Enemies)
local Combat = require(script.Parent.Combat)
local World = require(script.Parent.World)

local Api = {}

function Api.now()
	return Enemies.now()
end

function Api.path()
	return Enemies.path
end

function Api.enemies()
	return Enemies.list
end

function Api.enemiesInRange(pos, range, canHitAir)
	return Enemies.inRange(pos, range, canHitAir)
end

function Api.enemyDistance(e)
	return Enemies.distance(e)
end

function Api.enemyPosition(e)
	return Enemies.position(e)
end

-- Damage attributed to the tower's owner.
function Api.damage(tower, e, amount, extra)
	local src = { player = tower.owner, tower = tower }
	for k, v in pairs(extra or {}) do
		src[k] = v
	end
	return Combat.damage(e, amount, src)
end

-- id: "slow" | "stun" | "burn"; params per StatusLogic.DEFS
function Api.applyStatus(tower, e, id, params)
	params.source = params.source or tower.owner
	Enemies.applyStatus(e, id, params)
end

-- Spawns a temporary effect part in the FX folder, destroyed after `life` seconds.
function Api.spawnEffect(props, life)
	local p = World.part(props, World.fx)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	if life then
		game:GetService("Debris"):AddItem(p, life)
	end
	return p
end

-- Creates a part that the client moves along the path (like enemies).
-- dist0: starting distance, speed: studs/s (negative = backward), height above track.
function Api.spawnPathMover(props, dist0, speed, height)
	local p = World.part(props, nil)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p:SetAttribute("Dist", dist0)
	p:SetAttribute("CheckTime", Api.now())
	p:SetAttribute("Speed", speed)
	p:SetAttribute("Height", height or 0)
	p.Parent = World.movers
	return p
end

-- Pooled hit-scan beam.
local FAR = CFrame.new(0, -500, 0)
local pool = {}
function Api.beam(from, to, color)
	local b = table.remove(pool)
	if not b then
		b = World.part({
			Name = "Shot",
			Size = Vector3.new(0.3, 0.3, 1),
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			CFrame = FAR,
		}, World.fx)
	end
	local dist = (to - from).Magnitude
	b.Color = color or Color3.new(1, 1, 0)
	b.Size = Vector3.new(0.3, 0.3, dist)
	b.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	task.delay(0.08, function()
		if b.Parent then
			b.CFrame = FAR
			table.insert(pool, b)
		end
	end)
end

return Api
