-- Placed units: attack loop (driven by the server tick) and the ability host.
-- Ability hooks (all optional, all pcall-guarded so one bad ability can't break a match):
--   onPlace(), onAttack(target), onTick(dt), onUpgrade(level), onEnemyKilled(enemy, source),
--   onWaveStart(wave), cleanup()
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local UnitStats = require(Shared.UnitStats)
local Traits = require(Shared.Traits)
local World = require(script.Parent.World)
local Enemies = require(script.Parent.Enemies)
local Api = require(script.Parent.AbilityApi)
local Log = require(Shared.Log)
local log = Log.new("Towers")

local Towers = {}
Towers.placed = {}
Towers.byId = {}
local nextId = 0
local abilityFolder = script.Parent:WaitForChild("Abilities")

local function hook(t, name, ...)
	local a = t.ability
	if a and a[name] then
		Log.try("Ability", t.unit.id .. "." .. name, a[name], a, ...)
	end
end
Towers.hook = hook

function Towers.broadcast(name, ...)
	for _, t in ipairs(Towers.placed) do
		hook(t, name, ...)
	end
end

-- The ONE place tower stats are resolved: level table, then per-tower overrides (sandbox).
-- Called on place and on every upgrade, so overrides persist. Ticks only read t.stats.
local function resolveStats(t)
	t.stats = Traits.resolve(UnitStats.at(t.unit, t.level), t.overrides)
	if t.ability then
		t.ability.cfg = t.stats.ability
	end
	local p = t.part
	p:SetAttribute("StatDamage", t.stats.damage)
	p:SetAttribute("StatRange", t.stats.range)
	p:SetAttribute("StatRate", t.stats.rate)
end
Towers.resolveStats = resolveStats

-- opts (optional, dev sandbox): { level = n, overrides = { damage, range, rate, trait } }
function Towers.place(unitId, pos, owner, opts)
	local u = Units.get(unitId)
	local p = World.part({
		Name = u.name,
		Size = Vector3.one * u.size,
		Position = pos,
		Color = u.color or Color3.new(1, 1, 1),
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
		id = nextId, part = p, unit = u, alive = true, owner = owner, unitId = unitId,
		attacks = 0, level = 1, spent = u.cost, stats = UnitStats.at(u, 1), cooldown = 0,
	}
	p:SetAttribute("UnitId", t.id)
	p:SetAttribute("UnitType", unitId)
	p:SetAttribute("OwnerId", owner and owner.UserId or 0)
	p:SetAttribute("Level", 1)
	p:SetAttribute("Spent", t.spent)
	p:SetAttribute("Targeting", "First")
	if opts then
		t.level = opts.level or 1
		t.overrides = opts.overrides
		p:SetAttribute("Level", t.level)
		if t.overrides then
			p:SetAttribute("OvDamage", t.overrides.damage or 0)
			p:SetAttribute("OvRange", t.overrides.range or 0)
			p:SetAttribute("OvRate", t.overrides.rate or 0)
			p:SetAttribute("Trait", t.overrides.trait or "None")
		end
	end
	resolveStats(t)

	local bb = Instance.new("BillboardGui")
	bb.Name, bb.Size, bb.StudsOffsetWorldSpace = "LevelTag", UDim2.fromOffset(60, 22), Vector3.new(0, u.size / 2 + 1.5, 0)
	bb.MaxDistance = 120
	local lbl = Instance.new("TextLabel")
	lbl.Size, lbl.BackgroundTransparency, lbl.TextScaled = UDim2.fromScale(1, 1), 1, true
	lbl.TextColor3, lbl.Font, lbl.Text = Color3.new(1, 1, 1), Enum.Font.GothamBold, "Lv " .. t.level
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = bb
	bb.Parent = p
	t.levelLabel = lbl

	if u.ability then
		local mod = abilityFolder:FindFirstChild(u.ability)
		if mod then
			local ok, res = Log.try("Ability", u.ability .. ".new", function()
				return require(mod).new(t, t.stats.ability, Api)
			end)
			if ok then
				t.ability = res
			end
		else
			log.error("missing ability module", u.ability, "for unit", u.id)
		end
	end
	table.insert(Towers.placed, t)
	Towers.byId[t.id] = t
	hook(t, "onPlace")
	return t
end

local function attack(t, target)
	if not Enemies.targetable(target) then
		return false
	end
	local pos = t.part.Position
	Api.beam(pos, Enemies.position(target), t.unit.beamColor)
	Api.damage(t, target, t.stats.damage, {
		armorPen = t.unit.armorPen,
		critChance = t.unit.critChance,
		critMult = t.unit.critMult,
	})
	t.attacks += 1
	hook(t, "onAttack", target)
	return true
end

function Towers.tick(dt)
	for _, t in ipairs(Towers.placed) do
		if t.alive then
			t.cooldown -= dt
			if t.cooldown <= 0 then
				local target = Enemies.pick(t.part.Position, t.stats.range, t.part:GetAttribute("Targeting"), t.unit.hitsAir)
				if target then
					Log.try("Towers", "attack " .. t.unit.id, attack, t, target)
					t.cooldown = math.max(t.cooldown, -Config.TICK_RATE) + t.stats.rate
				end
			end
			hook(t, "onTick", dt)
		end
	end
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

function Towers.upgradeCost(t)
	return UnitStats.upgradeCost(t.unit, t.level)
end

function Towers.upgrade(t)
	t.spent += Towers.upgradeCost(t)
	t.level += 1
	t.part:SetAttribute("Level", t.level)
	resolveStats(t) -- keeps sandbox overrides
	t.part:SetAttribute("Spent", t.spent)
	t.levelLabel.Text = "Lv " .. t.level
	hook(t, "onUpgrade", t.level)
end

local function destroy(t)
	t.alive = false
	hook(t, "cleanup")
	t.part:Destroy()
	Towers.byId[t.id] = nil
end

function Towers.sell(t)
	local i = table.find(Towers.placed, t)
	if i then
		table.remove(Towers.placed, i)
	end
	destroy(t)
	return math.floor(t.spent * Config.SELL_REFUND)
end

function Towers.countFor(owner, unitId)
	local n = 0
	for _, t in ipairs(Towers.placed) do
		if t.owner == owner and t.unitId == unitId then
			n += 1
		end
	end
	return n
end

function Towers.removeOwner(owner)
	for i = #Towers.placed, 1, -1 do
		local t = Towers.placed[i]
		if t.owner == owner then
			table.remove(Towers.placed, i)
			destroy(t)
		end
	end
end

function Towers.clear()
	for _, t in ipairs(Towers.placed) do
		destroy(t)
	end
	table.clear(Towers.placed)
end

return Towers
