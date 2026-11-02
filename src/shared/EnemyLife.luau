--!strict
-- PURE enemy life rules (no Roblox APIs) so death is decided in exactly one place.
-- e: { hp, shield, maxHp, regen, alive }
local EnemyLife = {}

-- Apply an already-computed amount. Returns (dealt, killedNow).
-- killedNow is true exactly once per enemy, so kill rewards can't double up.
function EnemyLife.hit(e, amount: number): (number, boolean)
	if not e.alive or amount <= 0 then
		return 0, false
	end
	local before = math.max(e.hp, 0) + e.shield
	local absorbed = math.min(e.shield, amount) -- same split as Damage.applyToPools
	e.shield, e.hp = e.shield - absorbed, e.hp - (amount - absorbed)
	local dealt = before - math.max(e.hp, 0) - e.shield
	if e.hp <= 0 then
		e.hp = 0
		e.alive = false -- marked dead synchronously, before any listener/tower sees it
		return dealt, true
	end
	return dealt, false
end

-- Regen never revives: a dead (or 0 HP) enemy stays dead. Shield does not regen.
function EnemyLife.regen(e, dt: number)
	if e.alive and e.hp > 0 and e.regen > 0 and e.hp < e.maxHp then
		e.hp = math.min(e.maxHp, e.hp + e.regen * dt)
		return true
	end
	return false
end

-- A target is usable only while alive with HP > 0 (shield alone never keeps it alive).
function EnemyLife.targetable(e): boolean
	return e ~= nil and e.alive == true and e.hp > 0
end

return EnemyLife
