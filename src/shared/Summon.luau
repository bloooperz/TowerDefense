--!strict
-- PURE summon + unit-sell config and logic. ALL summon/sell numbers live here.
--  * Standard banner rotates every BANNER.PERIOD seconds. The banner for a window is derived
--    only from floor(time / PERIOD) + the unit roster, so every server shows the same banner
--    with no MemoryStore.
--  * Pool is OPT-IN: only unit defs with `summonable = true` (currently Basic, Rapid, Sniper).
--    Evolution-only units never set it and can never drop.
--  * Banner = up to SLOTS[rarity] units of each rarity from the pool (seeded shuffle).
--    Only banner units can drop. A rarity with no banner units passes its rate down to the
--    next lower rarity that has units (Summon.effectiveRates; shown in the Rates panel).
--  * x1 / x10 / x50 = N independent rolls at the same per-roll price. No bonus/guarantee.
--  * Pity: every roll that isn't the banner's top rarity adds 1; at PITY_THRESHOLD the roll is
--    forced to the top rarity = the HIGHEST rarity actually present in the banner (Epic today,
--    since no summonable unit is Legendary/Mythic; their rates pass down to Epic). Hitting the top rarity (naturally or by pity) resets it to 0.
--  * Summons cost GEMS. Selling a unit pays GOLD (SELL_GOLD[rarity]); Gold has no sink yet.
local Summon = {}
local Limits = if script then require(script.Parent.Limits) else require("./Limits") -- Roblox | lune
Summon.MAX_UNITS = Limits.MAX_UNITS

Summon.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" } -- low -> high
Summon.RATES = { Common = 0, Rare = 0.785, Epic = 0.18, Legendary = 0.03, Mythic = 0.005 } -- sums to 1
Summon.PITY_THRESHOLD = 300 -- the 300th roll without a top-rarity unit is guaranteed top rarity
Summon.COST_PER_ROLL = 50 -- Gems per roll
-- Starter flow: new accounts own NO units until they pick a starter (client starter screen,
-- server PlayerData.claimStarter). The pick grants the unit + STARTER_GEMS once (starterChosen).
Summon.STARTERS = { "Basic" }
Summon.STARTER_GEMS = 500 -- = 10 x1 rolls or exactly one x10 at COST_PER_ROLL 50
Summon.TIERS = { 1, 10, 50 }
Summon.BANNER = {
	PERIOD = 1800, -- 30 minutes
	SLOTS = { Common = 0, Rare = 3, Epic = 2, Legendary = 1, Mythic = 1 },
	SALT = 7919, -- change to reshuffle all future banners
}
Summon.SELL_GOLD = { Common = 5, Rare = 10, Epic = 20, Legendary = 40, Mythic = 100 }
Summon.CONFIRM_FROM = "Mythic" -- selling (or auto-selling) at/above this rarity needs a confirm

function Summon.rank(rarity: string?): number
	return table.find(Summon.RARITIES, rarity or "Common") or 1
end

function Summon.window(t: number): number
	return math.floor(t / Summon.BANNER.PERIOD)
end

function Summon.secondsLeft(t: number): number
	return Summon.BANNER.PERIOD - (math.floor(t) % Summon.BANNER.PERIOD)
end

-- Small deterministic PRNG (same on every server/client, no engine Random needed).
local function prng(seed: number)
	local s = (math.floor(seed) % 2147483646) + 1
	return function(n: number): number -- 1..n
		s = (s * 48271) % 2147483647
		return (s % n) + 1
	end
end

-- unitList: array of unit defs { id, rarity } (Units.list). Returns banner { window, units = {id...}, byRarity }.
function Summon.banner(window: number, unitList)
	local nextInt = prng(window * 1000003 + Summon.BANNER.SALT)
	local byRarity = {}
	for _, r in ipairs(Summon.RARITIES) do
		local pool = {}
		for _, u in ipairs(unitList) do
			if (u.rarity or "Common") == r and u.summonable == true then
				table.insert(pool, u.id)
			end
		end
		table.sort(pool)
		for i = #pool, 2, -1 do -- Fisher-Yates
			local j = nextInt(i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local picked = {}
		for i = 1, math.min(Summon.BANNER.SLOTS[r] or 0, #pool) do
			table.insert(picked, pool[i])
		end
		byRarity[r] = picked
	end
	local units = {}
	for i = #Summon.RARITIES, 1, -1 do
		for _, id in ipairs(byRarity[Summon.RARITIES[i]]) do
			table.insert(units, id)
		end
	end
	return { window = window, units = units, byRarity = byRarity }
end

-- Rates after passing empty rarities down. Returns { [rarity] = p } (only rarities with units) and top rarity.
function Summon.effectiveRates(banner)
	local out, carry, top = {}, 0, nil
	for i = #Summon.RARITIES, 1, -1 do
		local r = Summon.RARITIES[i]
		local p = (Summon.RATES[r] or 0) + carry
		if #banner.byRarity[r] > 0 then
			out[r], carry = p, 0
			top = top or r
		else
			carry = p
		end
	end
	if carry > 0 then -- nothing below took it: give it to the lowest rarity that has units
		for _, r in ipairs(Summon.RARITIES) do
			if out[r] then
				out[r] += carry
				break
			end
		end
	end
	return out, top
end

-- One roll. rand() -> [0,1). Returns unitId, rarity, newPity.
function Summon.roll(banner, pity: number, rand: () -> number)
	local rates, top = Summon.effectiveRates(banner)
	assert(top, "banner has no units")
	pity += 1
	local rarity
	if pity >= Summon.PITY_THRESHOLD then
		rarity = top
	else
		local x, acc = rand(), 0
		for i = #Summon.RARITIES, 1, -1 do
			local r = Summon.RARITIES[i]
			if rates[r] then
				acc += rates[r]
				rarity = r
				if x < acc then
					break
				end
			end
		end
	end
	local list = banner.byRarity[rarity :: string]
	local id = list[math.clamp(math.floor(rand() * #list) + 1, 1, #list)]
	if rarity == top then
		pity = 0
	end
	return id, rarity, pity
end

-- nil if OK, else player-facing reason. Returns cost too.
function Summon.check(tier: any, gems: number?): (string?, number)
	if type(tier) ~= "number" or not table.find(Summon.TIERS, tier) then
		return "Invalid summon amount", 0
	end
	local cost = tier * Summon.COST_PER_ROLL
	if (gems or 0) < cost then
		return ("Not enough Gems (need %d)"):format(cost), cost
	end
	return nil, cost
end

-- autoSell: { on = bool, max = rarity } | nil
function Summon.shouldAutoSell(rarity: string, autoSell): boolean
	return autoSell ~= nil and autoSell.on == true and Summon.rank(rarity) <= Summon.rank(autoSell.max)
end

-- True when auto-sell would sell EVERY rarity the banner can drop (so no roll takes a slot).
function Summon.autoSellCoversPool(banner, autoSell): boolean
	if not (autoSell and autoSell.on == true) then
		return false
	end
	for _, r in ipairs(Summon.RARITIES) do
		local ids = banner and banner.byRarity and banner.byRarity[r]
		if ids and #ids > 0 and not Summon.shouldAutoSell(r, autoSell) then
			return false
		end
	end
	return true
end

-- Inventory cap check (before any charge). owned >= cap always rejects (players over the cap keep
-- their units but can't summon). Otherwise free slots must be >= tier, unless auto-sell covers the
-- whole pool (then rolls never take a slot). Whole summon rejected, never partial.
function Summon.checkRoom(owned: number, tier: number, cap: number, coversPool: boolean): string?
	if owned >= cap then
		return ("Inventory full (%d/%d). Sell units to make room."):format(owned, cap)
	end
	local free = cap - owned
	if not coversPool and free < tier then
		return ("Not enough room: need %d free slots, you have %d"):format(tier, free)
	end
	return nil
end

-- Full server-side summon on a data table. deps = { rand, genUid, newUnit, rarityOf(unitId) }.
-- Mutates d (gems spent, gold from auto-sell, summonPity, units).
-- Returns reason or nil, results { {unitId, rarity, uid?, sold?} }, goldBack.
function Summon.apply(d, tier, banner, autoSell, deps)
	local why, cost = Summon.check(tier, d.gems)
	if why then
		return why
	end
	local owned = 0
	for _ in pairs(d.units or {}) do
		owned += 1
	end
	local room = Summon.checkRoom(owned, tier, (deps and deps.maxUnits) or Summon.MAX_UNITS, Summon.autoSellCoversPool(banner, autoSell))
	if room then
		return room
	end
	d.gems -= cost
	local pity = d.summonPity or 0
	local results, back = {}, 0
	for _ = 1, tier do
		local id, rarity
		id, rarity, pity = Summon.roll(banner, pity, deps.rand)
		if Summon.shouldAutoSell(rarity, autoSell) then
			local g = Summon.SELL_GOLD[rarity] or 0
			back += g
			table.insert(results, { unitId = id, rarity = rarity, sold = g })
		else
			local uid = deps.genUid()
			d.units[uid] = deps.newUnit(uid, id)
			table.insert(results, { unitId = id, rarity = rarity, uid = uid })
		end
	end
	d.gold = (d.gold or 0) + back
	d.summonPity = pity
	return nil, results, back
end

-- Sell check. placed: set of uids currently placed in a match (optional). Returns reason or nil, gold.
function Summon.checkSell(d, uid: string, rarity: string?, placed): (string?, number)
	local u = d.units[uid]
	if not u then
		return "You don't own that unit", 0
	end
	if table.find(d.loadout, uid) then
		return "Unequip the unit from your hotbar before selling", 0
	end
	if placed and placed[uid] then
		return "That unit is placed in a match", 0
	end
	if u.locked then
		return "That unit is locked", 0
	end
	local n = 0
	for _ in pairs(d.units) do
		n += 1
	end
	if n <= 1 then
		return "You can't sell your last unit", 0
	end
	return nil, Summon.SELL_GOLD[rarity or "Common"] or 0
end

-- Client starter-screen decision. chosen = StarterChosen attribute (nil = not loaded yet),
-- ownsUnits = Inventory attribute is non-empty, seenDone = this session already saw it chosen.
-- Only an explicit false on an account with no units shows it, and never again once done.
function Summon.showStarter(chosen: boolean?, ownsUnits: boolean, seenDone: boolean): boolean
	return chosen == false and not ownsUnits and not seenDone
end

-- Starter claim on a data table. Returns reason or nil, uid.
function Summon.claimStarter(d, unitId: any, genUid, newUnit)
	if d.starterChosen then
		return "Starter already chosen"
	end
	if type(unitId) ~= "string" or not table.find(Summon.STARTERS, unitId) then
		return "That isn't a starter unit"
	end
	local uid = genUid()
	d.units[uid] = newUnit(uid, unitId)
	if #d.loadout < 6 and not table.find(d.loadout, uid) then
		table.insert(d.loadout, uid)
	end
	d.gems += Summon.STARTER_GEMS
	d.starterChosen = true
	return nil, uid
end

return Summon
