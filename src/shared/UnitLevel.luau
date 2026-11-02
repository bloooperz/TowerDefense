--!strict
-- PURE account-level progression for OWNED unit instances (inventory), separate from the
-- in-match upgrade tiers in UnitStats. Account level scales DAMAGE ONLY (never rate/range).
--
-- Damage multiplier (t = (L - 1) / 79, L clamped to 1..80):
--     mult(L) = 1 + 4.14 * t^1.1725      (Anime Vanguards-style, ~4x by L60)
--   L1 = 1.00x, L10 = 1.32x, L20 = 1.78x, L30 = 2.28x, L40 = 2.81x, L50 = 3.37x,
--   L60 = 3.94x, L70 = 4.53x, L80 = 5.14x   (48.6 base -> ~191.5 at L60, ~250 at L80)
--
-- XP to go from L to L + 1 (xp is stored as progress INTO the current level):
--     xpToNext(L) = 100 + 20 * (L - 1) + (L - 1)^2      (L1 -> 100, L40 -> 2401, L79 -> 7744)
--   Total XP for 1 -> 80 is about 231k.
local UnitLevel = {}

UnitLevel.MAX = 80
UnitLevel.MAX_MULT = 5.14 -- = 1 + CURVE_A
UnitLevel.CURVE_A = 4.14
UnitLevel.CURVE_P = 1.1725

function UnitLevel.clampLevel(level: number?): number
	local l = math.floor(tonumber(level) or 1)
	return math.clamp(l, 1, UnitLevel.MAX)
end

function UnitLevel.damageMult(level: number?): number
	local t = (UnitLevel.clampLevel(level) - 1) / (UnitLevel.MAX - 1)
	return 1 + UnitLevel.CURVE_A * t ^ UnitLevel.CURVE_P
end

-- Apply the account multiplier to resolved stats (copy). A sandbox damage override (> 0)
-- is absolute and is NOT multiplied. Rate/range untouched.
function UnitLevel.applyDamage(stats, level: number?, overrides)
	if overrides and type(overrides.damage) == "number" and overrides.damage > 0 then
		return stats
	end
	local out = table.clone(stats)
	out.damage = stats.damage * UnitLevel.damageMult(level)
	return out
end

-- XP needed to advance from `level` to level + 1; 0 at max.
function UnitLevel.xpToNext(level: number): number
	local l = UnitLevel.clampLevel(level)
	if l >= UnitLevel.MAX then
		return 0
	end
	local k = l - 1
	return 100 + 20 * k + k * k
end

-- Total XP from level 1 to reach `level` (exact sum of xpToNext).
function UnitLevel.totalXpFor(level: number): number
	local s = 0
	for l = 1, UnitLevel.clampLevel(level) - 1 do
		s += UnitLevel.xpToNext(l)
	end
	return s
end

-- Lifetime XP banked in a unit (used for fuse value).
function UnitLevel.totalXp(u): number
	return UnitLevel.totalXpFor(u.level or 1) + math.max(u.xp or 0, 0)
end

-- Fix up level/xp in place (overflow carries; capped at MAX with xp = 0).
function UnitLevel.normalize(u)
	u.level = UnitLevel.clampLevel(u.level)
	u.xp = math.max(math.floor(tonumber(u.xp) or 0), 0)
	while u.level < UnitLevel.MAX and u.xp >= UnitLevel.xpToNext(u.level) do
		u.xp -= UnitLevel.xpToNext(u.level)
		u.level += 1
	end
	if u.level >= UnitLevel.MAX then
		u.xp = 0
	end
	return u
end

-- Add XP to a unit in place. Returns (levelsGained, wastedXp) -- wasted = XP lost to the cap.
function UnitLevel.addXp(u, amount: number): (number, number)
	amount = math.max(math.floor(tonumber(amount) or 0), 0)
	local before = UnitLevel.clampLevel(u.level)
	if before >= UnitLevel.MAX then
		u.level, u.xp = UnitLevel.MAX, 0
		return 0, amount
	end
	local room = UnitLevel.totalXpFor(UnitLevel.MAX) - UnitLevel.totalXp(u)
	local wasted = math.max(amount - room, 0)
	u.xp = (u.xp or 0) + amount - wasted
	UnitLevel.normalize(u)
	return u.level - before, wasted
end

-- Stage XP for EACH equipped (hotbar) unit at match end.
--   r = { wavesCleared, won, rewardScale? }
--   xp = floor((wavesCleared * 20 + (won and 200 or 0)) * rewardScale), losses still pay waves.
UnitLevel.STAGE_XP_PER_WAVE = 20
UnitLevel.STAGE_WIN_XP = 200
function UnitLevel.stageXp(r): number
	local waves = math.max(r.wavesCleared or 0, 0)
	local xp = waves * UnitLevel.STAGE_XP_PER_WAVE + (r.won and UnitLevel.STAGE_WIN_XP or 0)
	return math.max(math.floor(xp * (r.rewardScale or 1)), 0)
end

-- Fuse: each fed duplicate gives FUSE_BASE + FUSE_SHARE of its own banked XP.
UnitLevel.FUSE_BASE = 300
UnitLevel.FUSE_SHARE = 0.5
UnitLevel.FUSE_MAX = 20 -- per request
function UnitLevel.fuseValue(fed): number
	return math.floor(UnitLevel.FUSE_BASE + UnitLevel.FUSE_SHARE * UnitLevel.totalXp(fed))
end

-- Validate a fuse request against profile data d = { units, loadout }.
-- Returns (nil, xp) when valid, or (reason) when not. Does not mutate.
function UnitLevel.checkFuse(d, targetUid: string, feedUids: { string }): (string?, number?)
	local target = d.units[targetUid]
	if not target then
		return "Target unit not found"
	end
	if type(feedUids) ~= "table" or #feedUids == 0 then
		return "Pick at least one duplicate to fuse"
	end
	if #feedUids > UnitLevel.FUSE_MAX then
		return ("Fuse at most %d at a time"):format(UnitLevel.FUSE_MAX)
	end
	if UnitLevel.clampLevel(target.level) >= UnitLevel.MAX then
		return "Unit is already max level"
	end
	local seen, xp = {}, 0
	for _, uid in ipairs(feedUids) do
		if type(uid) ~= "string" then
			return "Bad unit id"
		end
		if uid == targetUid then
			return "Can't fuse a unit into itself"
		end
		if seen[uid] then
			return "Duplicate unit in fuse list"
		end
		seen[uid] = true
		local u = d.units[uid]
		if not u then
			return "Fuse unit not found"
		end
		if u.unitId ~= target.unitId then
			return "Can only fuse copies of the same unit"
		end
		if table.find(d.loadout, uid) then
			return "Unequip a unit before fusing it"
		end
		if u.locked then
			return "That unit is locked"
		end
		xp += UnitLevel.fuseValue(u)
	end
	return nil, xp
end

return UnitLevel
