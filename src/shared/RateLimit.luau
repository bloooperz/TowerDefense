-- Pure token bucket used by Net (per player + remote). `rate` = burst size AND refill per second.
-- e.g. rate 15: 15 instant clicks allowed, then 15/s sustained; anything faster is dropped.
local RateLimit = {}

function RateLimit.new()
	local buckets = {}
	local self = {}
	function self.allow(key, rate, now)
		local b = buckets[key] or { tokens = rate, t = now }
		b.tokens = math.min(rate, b.tokens + (now - b.t) * rate)
		b.t = now
		buckets[key] = b
		if b.tokens < 1 then
			return false
		end
		b.tokens -= 1
		return true
	end
	function self.forget(key)
		buckets[key] = nil
	end
	return self
end

return RateLimit
