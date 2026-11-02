-- Mogumo's passive "Divine Dogs": every Nth attack, a dog spawns on the track
-- at the point nearest Mogumo and runs BACKWARD (toward the enemy spawn),
-- hitting each enemy it passes once. Hits use position math, not Touched.
--
-- Ability interface (copy this for new unique units):
--   Ability.new(tower, cfg) -> object
--   object:onAttack(target)  -- called after each normal attack
--   object:cleanup()         -- called when towers are cleared (match reset)
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = require(script.Parent.Parent.World)
local Enemies = require(script.Parent.Parent.Enemies)

local Mogumo = {}
Mogumo.__index = Mogumo

function Mogumo.new(tower, cfg)
	return setmetatable({ tower = tower, cfg = cfg, dogs = {} }, Mogumo)
end

local function removeDog(self, dog)
	if not dog.alive then
		return
	end
	dog.alive = false
	dog.tween:Cancel()
	dog.part:Destroy()
	self.dogs[dog] = nil
end

function Mogumo:spawnDog()
	local cfg = self.cfg
	-- distance along the track nearest to Mogumo
	local rel = self.tower.part.Position - Config.START
	local d0 = math.clamp(rel:Dot(Config.DIR), 0, Config.LENGTH)
	local travel = math.min(cfg.dogSpeed * cfg.dogLifetime, d0)
	if travel <= 0 then
		return
	end
	local duration = travel / cfg.dogSpeed
	local startPos = Config.START + Config.DIR * d0
	local p = World.part({
		Name = "DivineDog",
		Size = Vector3.new(2, 1.5, 1.5),
		CFrame = CFrame.lookAt(startPos, startPos - Config.DIR),
		Color = Color3.new(0.05, 0.05, 0.05),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, World.runtime)
	local dog = { part = p, alive = true, hit = {} }
	dog.tween = TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(startPos - Config.DIR * travel, startPos - Config.DIR * (travel + 1)) })
	dog.tween:Play()
	self.dogs[dog] = true

	task.spawn(function()
		local t0 = os.clock()
		while dog.alive do
			local elapsed = os.clock() - t0
			local pos = startPos - Config.DIR * math.min(elapsed * cfg.dogSpeed, travel)
			for e in pairs(Enemies.list) do
				if not dog.hit[e] and (Enemies.position(e) - pos).Magnitude <= cfg.dogRadius then
					dog.hit[e] = true
					Enemies.damage(e, cfg.dogDamage)
				end
			end
			if elapsed >= duration then
				break
			end
			task.wait(0.05)
		end
		removeDog(self, dog)
	end)
end

function Mogumo:onAttack()
	if self.tower.attacks % self.cfg.every ~= 0 then
		return
	end
	local alive = 0
	for _ in pairs(self.dogs) do
		alive += 1
	end
	if alive < self.cfg.maxDogs then
		self:spawnDog()
	end
end

function Mogumo:cleanup()
	for dog in pairs(self.dogs) do
		removeDog(self, dog)
	end
end

return Mogumo
