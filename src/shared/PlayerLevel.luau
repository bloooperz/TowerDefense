--!strict
-- PURE player (account) level: XP curve, level-gated unlocks, and helpers.
-- Player xp is stored as LIFETIME total; level is derived (and mirrored into data.level).
--     xpForLevel(L) = 100 * (L - 1)^2   (total to reach L)   -> L2 = 100, L10 = 8100
--     levelForXp(x) = floor(sqrt(x / 100)) + 1, capped at MAX
-- Unlock gates are enforced on the server (PlayerLevel.check in remotes); the client only
-- uses them to show locks.
local PlayerLevel = {}

PlayerLevel.MAX = 100

-- feature -> required player level. Keys match LobbyFeatures/Theme panel names.
PlayerLevel.UNLOCKS = {
	Fuse = 3,
	["Traits Reroll"] = 5,
	["Stats Reroll"] = 8,
	Trade = 10,
	Evolution = 15,
}

function PlayerLevel.levelForXp(xp: number): number
	return math.min(math.floor(math.sqrt(math.max(tonumber(xp) or 0, 0) / 100)) + 1, PlayerLevel.MAX)
end

function PlayerLevel.xpForLevel(level: number): number
	return 100 * (math.clamp(level, 1, PlayerLevel.MAX) - 1) ^ 2
end

-- (level, intoLevel, neededForNext); neededForNext = 0 at max.
function PlayerLevel.progress(xp: number): (number, number, number)
	local l = PlayerLevel.levelForXp(xp)
	local base = PlayerLevel.xpForLevel(l)
	if l >= PlayerLevel.MAX then
		return l, 0, 0
	end
	return l, xp - base, PlayerLevel.xpForLevel(l + 1) - base
end

function PlayerLevel.required(feature: string): number
	return PlayerLevel.UNLOCKS[feature] or 1
end

function PlayerLevel.isUnlocked(level: number, feature: string): boolean
	return (level or 1) >= PlayerLevel.required(feature)
end

-- nil if allowed, else a player-facing reason.
function PlayerLevel.check(level: number, feature: string): string?
	if PlayerLevel.isUnlocked(level, feature) then
		return nil
	end
	return ("%s unlocks at player level %d"):format(feature, PlayerLevel.required(feature))
end

return PlayerLevel
