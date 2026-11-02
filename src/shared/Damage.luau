--!strict
-- PURE damage formula. One place to change how damage is computed.
--   final = base * mult * (crit and critMult or 1) * (1 - max(armor - armorPen, 0))
local Damage = {}

Damage.MAX_ARMOR = 0.9

export type Opts = {
	mult: number?,
	armor: number?,
	armorPen: number?,
	critChance: number?,
	critMult: number?,
	roll: number?, -- 0..1 random roll (inject for deterministic tests)
}

function Damage.compute(base: number, o: Opts?): (number, boolean)
	local opts: Opts = o or {}
	local mult = opts.mult or 1
	local armor = math.clamp((opts.armor or 0) - (opts.armorPen or 0), 0, Damage.MAX_ARMOR)
	local crit = (opts.critChance or 0) > 0 and (opts.roll or 1) < (opts.critChance or 0)
	local amount = base * mult * (crit and (opts.critMult or 2) or 1) * (1 - armor)
	return math.max(amount, 0), crit
end

-- Split damage between shield and HP. Returns (newShield, newHp, hpDamage).
function Damage.applyToPools(amount: number, shield: number, hp: number): (number, number, number)
	local absorbed = math.min(shield, amount)
	local rest = amount - absorbed
	return shield - absorbed, hp - rest, rest
end

return Damage
