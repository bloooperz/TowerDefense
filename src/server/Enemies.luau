-- Enemies move with one linear tween each; positions are computed from time.
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = require(script.Parent.World)

local Enemies = {}
Enemies.list = {} -- [enemy] = true
Enemies.onLeak = nil -- function() called when an enemy reaches the base
Enemies.onKill = nil -- function() called when an enemy dies

function Enemies.position(e)
	return Config.START + Config.DIR * math.min((os.clock() - e.t0) * e.speed, Config.LENGTH)
end

local function remove(e)
	if not e.alive then
		return
	end
	e.alive = false
	e.tween:Cancel()
	e.part:Destroy()
	Enemies.list[e] = nil
end

function Enemies.spawn(hp, speed)
	local p = World.part({
		Name = "Enemy",
		Size = Vector3.new(3, 3, 3),
		Position = Config.START,
		Color = Color3.new(1, 0, 0),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, World.runtime)
	local e = { part = p, hp = hp, speed = speed, t0 = os.clock(), alive = true }
	e.tween = TweenService:Create(p, TweenInfo.new(Config.LENGTH / speed, Enum.EasingStyle.Linear), { Position = Config.FINISH })
	e.tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and e.alive then
			remove(e)
			if Enemies.onLeak then
				Enemies.onLeak()
			end
		end
	end)
	e.tween:Play()
	Enemies.list[e] = true
	return e
end

function Enemies.damage(e, amount)
	if not e.alive then
		return
	end
	e.hp -= amount
	if e.hp <= 0 then
		remove(e)
		if Enemies.onKill then
			Enemies.onKill()
		end
	end
end

function Enemies.closest(pos, range)
	local best, bestD = nil, range
	for e in pairs(Enemies.list) do
		local d = (Enemies.position(e) - pos).Magnitude
		if d <= bestD then
			best, bestD = e, d
		end
	end
	return best
end

-- Targeting modes: First (furthest along), Last, Strongest, Weakest, Closest.
function Enemies.pick(pos, range, mode)
	local best, bestScore = nil, -math.huge
	local now = os.clock()
	for e in pairs(Enemies.list) do
		local d = (Enemies.position(e) - pos).Magnitude
		if d <= range then
			local progress = (now - e.t0) * e.speed
			local score
			if mode == "Last" then
				score = -progress
			elseif mode == "Strongest" then
				score = e.hp
			elseif mode == "Weakest" then
				score = -e.hp
			elseif mode == "Closest" then
				score = -d
			else -- First
				score = progress
			end
			if score > bestScore then
				best, bestScore = e, score
			end
		end
	end
	return best
end

function Enemies.clear()
	for e in pairs(Enemies.list) do
		remove(e)
	end
end

function Enemies.count()
	local n = 0
	for _ in pairs(Enemies.list) do
		n += 1
	end
	return n
end

return Enemies
