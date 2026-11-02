-- Placed units, shooting loop, and a pooled shot-beam effect.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = require(script.Parent.World)
local Enemies = require(script.Parent.Enemies)

local Towers = {}
Towers.placed = {} -- list of tower records

local FAR = CFrame.new(0, -500, 0)
local pool = {}
local function getBeam()
	local b = table.remove(pool)
	if not b then
		b = World.part({
			Name = "Shot",
			Size = Vector3.new(0.3, 0.3, 1),
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Color = Color3.new(1, 1, 0),
			Material = Enum.Material.Neon,
			CFrame = FAR,
		}, World.runtime)
	end
	return b
end

local function shoot(from, to)
	local b = getBeam()
	local dist = (to - from).Magnitude
	b.Size = Vector3.new(0.3, 0.3, dist)
	b.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	task.delay(0.08, function()
		if b.Parent then
			b.CFrame = FAR
			table.insert(pool, b)
		end
	end)
end

local abilityFolder = script.Parent:WaitForChild("Abilities")

function Towers.place(unitIndex, pos, owner)
	local u = Config.UNITS[unitIndex]
	local p = World.part({
		Name = u.name,
		Size = Vector3.one * u.size,
		Position = pos,
		Color = Color3.new(1, 1, 1),
	}, World.runtime)
	if u.topper then
		World.part({
			Name = "Topper",
			Size = Vector3.new(u.size, 0.4, u.size),
			Position = pos + Vector3.new(0, u.size / 2 + 0.2, 0),
			Color = u.topper,
			CanCollide = false,
		}, p)
	end
	local t = { part = p, unit = u, alive = true, owner = owner, index = unitIndex, attacks = 0 }
	if u.ability then
		t.ability = require(abilityFolder:WaitForChild(u.ability)).new(t, u.abilityConfig or {})
	end
	table.insert(Towers.placed, t)
	task.spawn(function()
		while t.alive do
			local target = Enemies.closest(p.Position, u.range)
			if target then
				shoot(p.Position, Enemies.position(target))
				Enemies.damage(target, u.damage)
				t.attacks += 1
				if t.ability and t.ability.onAttack then
					t.ability:onAttack(target)
				end
				task.wait(u.rate)
			else
				task.wait(0.1)
			end
		end
	end)
	return t
end

function Towers.overlaps(pos, size)
	for _, t in ipairs(Towers.placed) do
		local minDist = (t.unit.size + size) / 2
		local d = t.part.Position - pos
		if math.abs(d.X) < minDist and math.abs(d.Z) < minDist then
			return true
		end
	end
	return false
end

function Towers.countFor(owner, unitIndex)
	local n = 0
	for _, t in ipairs(Towers.placed) do
		if t.owner == owner and t.index == unitIndex then
			n += 1
		end
	end
	return n
end

function Towers.clear()
	for _, t in ipairs(Towers.placed) do
		t.alive = false
		if t.ability and t.ability.cleanup then
			t.ability:cleanup()
		end
		t.part:Destroy()
	end
	table.clear(Towers.placed)
end

return Towers
