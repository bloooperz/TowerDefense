--!strict
-- PURE reward formulas. Every run pays; losses pay ~50% of the wave portion.
local Rewards = {}

Rewards.GEMS_PER_WAVE = 5
Rewards.WIN_GEMS = 50
Rewards.XP_PER_WAVE = 10
Rewards.WIN_XP = 50
Rewards.LOSS_MULT = 0.5
Rewards.GEM_CAP = 500 -- per run, anti-macro

function Rewards.compute(r)
	local waves = math.max(r.wavesCleared or 0, 0)
	local scale = r.rewardScale or 1
	local lossMult = r.won and 1 or Rewards.LOSS_MULT
	local gems = waves * Rewards.GEMS_PER_WAVE * lossMult + (r.won and Rewards.WIN_GEMS or 0)
	local xp = waves * Rewards.XP_PER_WAVE * lossMult + (r.won and Rewards.WIN_XP or 0)
	if r.firstClear and r.won then
		gems += Rewards.WIN_GEMS
	end
	gems = math.min(math.floor(gems * scale), Rewards.GEM_CAP)
	xp = math.floor(xp * scale)
	-- participation floor: a run where you did something always pays a little
	if (r.engaged ~= false) and gems < 1 then
		gems = 1
	end
	return { gems = gems, xp = xp } -- unit XP: shared/UnitLevel.stageXp
end

return Rewards
