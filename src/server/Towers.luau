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

Towers.byId = {}
local nextId = 0

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
	nextId += 1
	local t = {
		id = nextId, part = p, unit = u, alive = true, owner = owner, index = unitIndex,
		attacks = 0, level = 1, spent = u.cost, stats = Config.statsAt(u, 1),
	}
	p:SetAttribute("UnitId", t.id)
	p:SetAttribute("UnitIndex", unitIndex)
	p:SetAttribute("OwnerId", owner and owner.UserId or 0)
	p:SetAttribute("Level", 1)
	p:SetAttribute("Spent", t.spent)
	p:SetAttribute("Targeting", "First")

	local bb = Instance.new("BillboardGui")
	bb.Name, bb.Size, bb.StudsOffsetWorldSpace = "LevelTag", UDim2.fromOffset(60, 22), Vector3.new(0, u.size / 2 + 1.5, 0)
	bb.MaxDistance = 120
	local lbl = Instance.new("TextLabel")
	lbl.Size, lbl.BackgroundTransparency, lbl.TextScaled = UDim2.fromScale(1, 1), 1, true
	lbl.TextColor3, lbl.Font, lbl.Text = Color3.new(1, 1, 1), Enum.Font.GothamBold, "Lv 1"
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = bb
	bb.Parent = p
	t.levelLabel = lbl

	if u.ability then
		t.ability = require(abilityFolder:WaitForChild(u.ability)).new(t, t.stats.ability)
	end
	table.insert(Towers.placed, t)
	Towers.byId[t.id] = t
	task.spawn(function()
		while t.alive do
			local st = t.stats
			local target = Enemies.pick(p.Position, st.range, p:GetAttribute("Targeting"))
			if target then
				shoot(p.Position, Enemies.position(target))
				Enemies.damage(target, st.damage)
				t.attacks += 1
				if t.ability and t.ability.onAttack then
					t.ability:onAttack(target)
				end
				task.wait(t.stats.rate)
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

-- Returns upgrade cost, or nil if maxed.
function Towers.upgradeCost(t)
	local up = t.unit.upgrades and t.unit.upgrades[t.level]
	return up and up.cost
end

function Towers.upgrade(t)
	t.spent += Towers.upgradeCost(t)
	t.level += 1
	t.stats = Config.statsAt(t.unit, t.level)
	if t.ability then
		t.ability.cfg = t.stats.ability
	end
	t.part:SetAttribute("Level", t.level)
	t.part:SetAttribute("Spent", t.spent)
	t.levelLabel.Text = "Lv " .. t.level
end

local function destroy(t)
	t.alive = false
	if t.ability and t.ability.cleanup then
		t.ability:cleanup()
	end
	t.part:Destroy()
	Towers.byId[t.id] = nil
end

-- Removes the tower and returns the refund amount.
function Towers.sell(t)
	local i = table.find(Towers.placed, t)
	if i then
		table.remove(Towers.placed, i)
	end
	destroy(t)
	return math.floor(t.spent * Config.SELL_REFUND)
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
		destroy(t)
	end
	table.clear(Towers.placed)
end

return Towers
