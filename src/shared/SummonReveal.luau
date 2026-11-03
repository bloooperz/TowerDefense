-- PURE view-model for the full-screen summon reveal (client display only).
-- Result shape (from SummonResult.results[i]):
--   { unitId, rarity, uid?, sold? = goldNumber,
--     trait? = traitId,                                   -- optional, future server roll
--     stats? = { damage = "S", cooldown = "A", range = "B" } } -- optional, future stat-roll grades
-- Sections for trait / grades are present only when the result carries that data.
local SummonReveal = {}

SummonReveal.GRADES = { "C", "B", "A", "S", "SS", "Z" } -- low -> high
SummonReveal.GRADE_RANK = {}
for i, g in ipairs(SummonReveal.GRADES) do
	SummonReveal.GRADE_RANK[g] = i
end
SummonReveal.STAT_KEYS = { { key = "damage", label = "Damage" }, { key = "cooldown", label = "Cooldown" }, { key = "range", label = "Range" } }

-- Normalizes a grade string; unknown -> nil.
function SummonReveal.grade(g)
	if type(g) ~= "string" then
		return nil
	end
	g = string.upper(g)
	return SummonReveal.GRADE_RANK[g] and g or nil
end

function SummonReveal.card(r, def, traitsById)
	local m = {
		unitId = tostring(r.unitId),
		name = def and def.name or tostring(r.unitId),
		rarity = r.rarity or (def and def.rarity) or "Common",
		stats = {},
		trait = nil,
		grades = nil,
		soldText = nil,
	}
	if def then
		table.insert(m.stats, { key = "damage", label = "Damage", value = tostring(def.damage) })
		table.insert(m.stats, { key = "cooldown", label = "Cooldown", value = tostring(def.rate) .. "s" })
		table.insert(m.stats, { key = "range", label = "Range", value = tostring(def.range) })
	end
	if r.trait ~= nil and r.trait ~= "" and r.trait ~= "None" then
		local t = traitsById and traitsById[r.trait]
		m.trait = { id = tostring(r.trait), name = t and t.name or tostring(r.trait), desc = t and t.desc or "" }
	end
	if type(r.stats) == "table" then
		local list = {}
		for _, s in ipairs(SummonReveal.STAT_KEYS) do
			local g = SummonReveal.grade(r.stats[s.key])
			if g then
				table.insert(list, { key = s.key, label = s.label, grade = g, rank = SummonReveal.GRADE_RANK[g] })
			end
		end
		if #list > 0 then
			m.grades = list
		end
	end
	if type(r.sold) == "number" then
		m.soldText = ("Auto-sold +%d Gold"):format(r.sold)
	end
	return m
end

-- Card-row reveal (Anime Vanguards style). Units are already granted; this is purely visual.
-- Every result becomes a card, left -> right in result order, popping in STAGGER apart with a
-- flame effect. skipAnim (Settings > Skip summon animation) -> all cards at once, no flame.
SummonReveal.STAGGER = 0.07

-- Screen layout (pixels; h = screen height). The summon button row lives in a dedicated bottom
-- bar (ROW_H tall, ROW_MARGIN from the bottom/right edge); the results band is centered in the
-- space ABOVE that bar so the two never overlap. Mirrors the UDim2s used by SummonUI.
SummonReveal.BAR = 96
SummonReveal.ROW_H = 56
SummonReveal.ROW_MARGIN = 20
SummonReveal.BTN_W = 180
SummonReveal.BAND_SCALE = 0.62
-- Full-screen geometry under a ScreenGui with IgnoreGuiInset = false (the Lobby gui): the root
-- grows UP by the topbar inset so the backdrop covers the WHOLE viewport (no world strip at the
-- top on any resolution), while a "Safe" content frame starts below the inset so title/X/buttons
-- stay clear of the Roblox topbar. Offsets in px; all sizes are scale 1,1 plus offset.
function SummonReveal.screen(insetTop: number?)
	local i = math.max(0, math.floor(tonumber(insetTop) or 0))
	local neg = 0 - i -- explicit (unary minus on i miscompiled to +i in lune's Luau here)
	return {
		root = { sx = 1, sy = 1, oy = i, py = 0.5, poy = neg / 2 }, -- Size (1,0,1,i), Position (0.5,0,0.5,-i/2), anchor .5,.5
		safe = { sx = 1, sy = 1, oy = neg, poy = i }, -- Size (1,0,1,-i), Position (0,0,0,i)
	}
end

function SummonReveal.bandRect(h)
	local center = 0.5 * h - SummonReveal.BAR / 2
	local half = (SummonReveal.BAND_SCALE * h - SummonReveal.BAR) / 2
	return center - half, center + half -- top, bottom
end
function SummonReveal.rowRect(h)
	local bottom = h - SummonReveal.ROW_MARGIN
	return bottom - SummonReveal.ROW_H, bottom
end
-- Full-screen banner: featured units left -> right with the highest rarity in the CENTER
-- (emphasized). rank(id) -> number, higher = rarer. Returns { {id, emphasized}, ... }.
function SummonReveal.featured(ids, rank)
	local sorted = table.clone(ids or {})
	table.sort(sorted, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local out = {}
	if #sorted == 3 then
		sorted = { sorted[2], sorted[1], sorted[3] }
	end
	for i, id in ipairs(sorted) do
		table.insert(out, { id = id, emphasized = (#sorted == 3 and i == 2) or (#sorted ~= 3 and i == 1) })
	end
	return out
end

function SummonReveal.buttonText(tier, cost)
	return ("x%d  %d Gems"):format(tier, cost)
end
function SummonReveal.layout(results, skipAnim, def, traitsById)
	local cards = {}
	for i, r in ipairs(results or {}) do
		local m = SummonReveal.card(r, def and def(r.unitId), traitsById)
		m.order = i
		m.delay = skipAnim and 0 or (i - 1) * SummonReveal.STAGGER
		m.flame = not skipAnim
		m.sold = m.soldText ~= nil
		m.hasModel = true -- every card holds a ViewportFrame (placeholder when the def is missing)
		table.insert(cards, m)
	end
	return { cards = cards, empty = #cards == 0 }
end

-- Click routing while results are up. target: "model" (a result card / its viewport),
-- "button" (summon row: its own action), "other" (empty space -> dismiss on RELEASE).
function SummonReveal.clicks()
	local c = { pressed = nil }
	function c.press(target)
		c.pressed = target
	end
	function c.release(showing): boolean -- true = dismiss now
		local p = c.pressed
		c.pressed = nil
		return showing == true and p == "other"
	end
	-- x1/x10/x50 click: while results show it ONLY dismisses; hidden -> summon.
	function c.summonClick(showing): string
		c.pressed = nil
		return showing and "dismiss" or "summon"
	end
	return c
end

return SummonReveal
