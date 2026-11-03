-- Pure text for the enemy billboard (type name + HP number). Server-side only uses it.
local EnemyLabel = {}

-- 950 -> "950", 1234 -> "1.2K", 15000 -> "15K", 2500000 -> "2.5M". Rounds UP (alive = >= 1).
function EnemyLabel.compact(n)
	n = math.max(0, math.ceil(n or 0))
	local function f(v, suf)
		local s = v < 10 and ("%.1f"):format(math.floor(v * 10) / 10) or tostring(math.floor(v))
		return (s:gsub("%.0$", "")) .. suf
	end
	if n >= 1e6 then
		return f(n / 1e6, "M")
	elseif n >= 1e3 then
		return f(n / 1e3, "K")
	end
	return tostring(n)
end

function EnemyLabel.hp(hp, maxHp)
	return EnemyLabel.compact(hp) .. " / " .. EnemyLabel.compact(maxHp)
end

function EnemyLabel.name(def)
	return (def and (def.name or def.id)) or "Enemy"
end

return EnemyLabel
