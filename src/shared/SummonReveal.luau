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

-- Reveal sequence. skipAnim (setting) -> starts in summary.
-- mode: "reveal" (one at a time) | "summary" (grid of all) | "empty"
function SummonReveal.sequence(results, skipAnim)
	local n = #(results or {})
	local s = { index = n > 0 and 1 or 0, count = n, mode = n == 0 and "empty" or (skipAnim and "summary" or "reveal") }
	function s.current()
		return s.mode == "reveal" and results[s.index] or nil
	end
	function s.next() -- Next (click/Space): advance; past the last -> summary (single result: summary too)
		if s.mode ~= "reveal" then
			return s.mode
		end
		if s.index < n then
			s.index += 1
		else
			s.mode = "summary"
		end
		return s.mode
	end
	function s.skip()
		if s.mode == "reveal" then
			s.mode = "summary"
		end
		return s.mode
	end
	function s.counter()
		return ("%d / %d"):format(s.index, n)
	end
	function s.showSkip()
		return s.mode == "reveal" and n > 1
	end
	return s
end

-- Click routing while the reveal/summary is up. target: "model" (unit viewport, drag-to-spin),
-- "button" (Next/Skip: their own action), "other" (anywhere else on the popup).
-- Dismiss fires on RELEASE so a drag that started on a model never dismisses.
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
