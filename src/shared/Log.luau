-- Tagged logging + error capture. Convention: no silent failures.
--   local log = Log.new("Match")      -- prints as [TD:Match]
--   log.info(...), log.warn(...), log.error(...)  (error logs, does NOT throw)
--   Log.try("Match", "spawnWave", fn, ...) -> ok, result  (xpcall + traceback)
local Log = {}
Log.PREFIX = "TD"

local function fmt(tag, ...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	return ("[%s:%s] %s"):format(Log.PREFIX, tag, table.concat(parts, " ", 1, parts.n))
end

function Log.new(tag)
	return {
		info = function(...)
			print(fmt(tag, ...))
		end,
		warn = function(...)
			warn(fmt(tag, ...))
		end,
		error = function(...)
			warn(fmt(tag, "ERROR", ...)) -- warn (not error) so callers keep running
		end,
	}
end

function Log.try(tag, what, fn, ...)
	local res = table.pack(xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback(nil, 2)
	end, ...))
	if not res[1] then
		warn(fmt(tag, "ERROR in " .. what .. ": " .. tostring(res[2])))
	end
	return table.unpack(res, 1, res.n)
end

return Log
