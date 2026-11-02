-- PURE passive-description formatting. Unit defs declare:
--   passive = { name = "...", describe = "template with {key} / {key:ord}" | function(levelStats) -> string }
-- {key} looks up levelStats.ability[key] then levelStats[key] (UnitStats.at output). {key:ord} -> "3rd".
-- describe(unit, stats, nextStats?) returns plain text, rich text (changed values shown "40 -> 55" in green),
-- and a list of problems (missing fields/keys) for the caller to log + toast.
local Passive = {}
Passive.CHANGED_COLOR = "#5CFF8A"
Passive.VALUE_COLOR = "#FFD24A"

local function fmt(n)
	if type(n) ~= "number" then
		return tostring(n)
	end
	if math.floor(n) == n then
		return tostring(n)
	end
	return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

function Passive.ordinal(n)
	local s = fmt(n)
	if type(n) ~= "number" or math.floor(n) ~= n then
		return s
	end
	local t, h = n % 10, n % 100
	if h >= 11 and h <= 13 then
		return s .. "th"
	end
	return s .. (t == 1 and "st" or t == 2 and "nd" or t == 3 and "rd" or "th")
end

local function lookup(st, key)
	if not st then
		return nil
	end
	if st.ability and st.ability[key] ~= nil then
		return st.ability[key]
	end
	return st[key]
end

local function render(v, mod)
	if mod == "ord" then
		return Passive.ordinal(v)
	end
	return fmt(v)
end

function Passive.has(u)
	return type(u) == "table" and type(u.passive) == "table"
end

function Passive.describe(u, st, nx)
	local problems = {}
	local p = u and u.passive
	if type(p) ~= "table" then
		return nil, nil, { "no passive" }
	end
	if type(p.name) ~= "string" or p.name == "" then
		table.insert(problems, (u.name or "?") .. ": passive.name missing")
	end
	local d = p.describe
	if type(d) == "function" then
		local ok, a = pcall(d, st)
		local ok2, b = true, nil
		if nx then
			ok2, b = pcall(d, nx)
		end
		if not ok or type(a) ~= "string" then
			table.insert(problems, (u.name or "?") .. ": passive.describe errored: " .. tostring(a))
			return nil, nil, problems
		end
		local rich = a
		if nx and ok2 and type(b) == "string" and b ~= a then
			rich = a .. ('\n<font color="%s">Next: %s</font>'):format(Passive.CHANGED_COLOR, b)
		end
		return a, rich, problems
	end
	if type(d) ~= "string" or d == "" then
		table.insert(problems, (u.name or "?") .. ": passive.describe missing")
		return nil, nil, problems
	end
	local plain = d:gsub("{([%w_]+):?(%w*)}", function(key, mod)
		local v = lookup(st, key)
		if v == nil then
			table.insert(problems, ("%s: unknown placeholder {%s}"):format(u.name or "?", key))
			return "?"
		end
		return render(v, mod)
	end)
	local rich = d:gsub("{([%w_]+):?(%w*)}", function(key, mod)
		local v, n = lookup(st, key), lookup(nx, key)
		if v == nil then
			return "?"
		end
		if n ~= nil and n ~= v then
			return ('<font color="%s">%s -> %s</font>'):format(Passive.CHANGED_COLOR, render(v, mod), render(n, mod))
		end
		return ('<font color="%s">%s</font>'):format(Passive.VALUE_COLOR, render(v, mod))
	end)
	return plain, rich, problems
end

return Passive
