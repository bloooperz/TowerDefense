--!strict
-- PURE status effect rules. State per enemy is a plain table.
-- Stacking:
--   "max"     strongest amount wins; duration refreshes to the longer of the two
--   "longest" keeps whichever ends later (stun)
--   "stack"   independent stacks up to maxStacks; oldest replaced when full (burn)
local StatusLogic = {}

StatusLogic.DEFS = {
	slow = { stacking = "max" }, -- params: amount (0..1), duration
	stun = { stacking = "longest", bossMult = 0.5 }, -- params: duration
	burn = { stacking = "stack", maxStacks = 5 }, -- params: dps, duration, source
}

function StatusLogic.new()
	return {}
end

-- opts.boss reduces control durations by bossMult.
function StatusLogic.apply(state, id: string, p, now: number, opts)
	local def = StatusLogic.DEFS[id]
	assert(def, "unknown status " .. id)
	local duration = p.duration or 1
	if opts and opts.boss and def.bossMult then
		duration *= def.bossMult
	end
	local expires = now + duration
	if def.stacking == "max" then
		local cur = state[id]
		if not cur or now >= cur.expires then
			state[id] = { amount = p.amount or 0, expires = expires, source = p.source }
		else
			cur.amount = math.max(cur.amount, p.amount or 0)
			cur.expires = math.max(cur.expires, expires)
		end
	elseif def.stacking == "longest" then
		local cur = state[id]
		if not cur or expires > cur.expires then
			state[id] = { expires = expires, source = p.source }
		end
	elseif def.stacking == "stack" then
		local cur = state[id] or { stacks = {} }
		state[id] = cur
		if #cur.stacks >= def.maxStacks then
			table.sort(cur.stacks, function(a, b)
				return a.expires < b.expires
			end)
			table.remove(cur.stacks, 1)
		end
		table.insert(cur.stacks, { dps = p.dps or 0, expires = expires, source = p.source })
	end
end

-- Remove expired entries. Returns true if anything changed (caller re-checkpoints speed).
function StatusLogic.prune(state, now: number): boolean
	local changed = false
	for id, s in pairs(state) do
		if s.stacks then
			for i = #s.stacks, 1, -1 do
				if now >= s.stacks[i].expires then
					table.remove(s.stacks, i)
				end
			end
			if #s.stacks == 0 then
				state[id] = nil
			end
		elseif now >= s.expires then
			state[id] = nil
			changed = true
		end
	end
	return changed
end

function StatusLogic.speedMult(state, now: number): number
	local stun = state.stun
	if stun and now < stun.expires then
		return 0
	end
	local slow = state.slow
	if slow and now < slow.expires then
		return math.clamp(1 - slow.amount, 0, 1)
	end
	return 1
end

-- Active damage-over-time sources: list of { dps, source }.
function StatusLogic.dots(state, now: number)
	local out = {}
	local burn = state.burn
	if burn then
		for _, s in ipairs(burn.stacks) do
			if now < s.expires then
				table.insert(out, { dps = s.dps, source = s.source })
			end
		end
	end
	return out
end

function StatusLogic.has(state, id: string, now: number): boolean
	local s = state[id]
	if not s then
		return false
	end
	if s.stacks then
		return #s.stacks > 0
	end
	return now < s.expires
end

return StatusLogic
