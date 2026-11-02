-- Utility API handed to abilities. Abilities should only touch the game through this.
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
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
	return Enemies.all() -- snapshot of LIVE enemies; check e.alive after each hit
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
	if not Enemies.targetable(e) then
		return
	end
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

-- Hit-scan beam: drawn on clients (unreliable remote, fire-and-forget) instead of
-- replicating 3 property writes per shot, which flooded replication on late waves.
function Api.beam(from, to, color)
	Net.fireAll("Beam", from, to, color or Color3.new(1, 1, 0))
end

return Api
