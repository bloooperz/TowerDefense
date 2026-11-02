-- Mogumo passive "Divine Dogs": every Nth attack, a divine dog spawns at the nearest
-- point on the path and runs BACKWARD toward the spawn, biting each ground enemy it
-- meets (damage + brief stun). Dogs are path movers, rendered by the client like enemies.
-- Collision is pure path math: |enemyDist - dogDist| <= dogRadius.
local Ability = {}
Ability.__index = Ability

function Ability.new(tower, cfg, api)
	return setmetatable({ tower = tower, cfg = cfg, api = api, dogs = {} }, Ability)
end

function Ability:onAttack(_target)
	local cfg = self.cfg
	if self.tower.attacks % cfg.every ~= 0 or #self.dogs >= cfg.maxDogs then
		return
	end
	local path = self.api.path()
	local d0 = path:nearest(self.tower.part.Position)
	local part = self.api.spawnPathMover({
		Name = "DivineDog",
		Size = Vector3.new(1.6, 1.6, 2.6),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
	}, d0, -cfg.dogSpeed, 0.8)
	table.insert(self.dogs, { part = part, d0 = d0, t0 = self.api.now(), hit = {} })
end

function Ability:onTick(_dt)
	local cfg, api = self.cfg, self.api
	local now = api.now()
	for i = #self.dogs, 1, -1 do
		local dog = self.dogs[i]
		local age = now - dog.t0
		local dist = dog.d0 - age * cfg.dogSpeed
		if age >= cfg.dogLifetime or dist <= 0 then
			dog.part:Destroy()
			table.remove(self.dogs, i)
		else
			for _, e in ipairs(api.enemies()) do
				if e.alive and not e.flying and not dog.hit[e] and math.abs(api.enemyDistance(e) - dist) <= cfg.dogRadius then
					dog.hit[e] = true
					api.damage(self.tower, e, cfg.dogDamage)
					if e.alive then
						api.applyStatus(self.tower, e, "stun", { duration = cfg.dogStun })
					end
				end
			end
		end
	end
end

function Ability:cleanup()
	for _, dog in ipairs(self.dogs) do
		dog.part:Destroy()
	end
	table.clear(self.dogs)
end

return Ability
