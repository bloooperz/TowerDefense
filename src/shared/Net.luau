-- Single remote layer. Every remote is declared here with argument types and a rate limit.
-- Server:  Net.initServer(); Net.on(name, fn(plr, ...) -> rejectReason?); Net.fire(name, plr, ...); Net.fireAll(name, ...)
-- Client:  Net.send(name, ...); Net.listen(name, fn(...))
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Log = require(script.Parent.Log)
local log = Log.new("Net")

local Net = {}

-- c2s: client -> server (validated). s2c: server -> client.
Net.DEFS = {
	PlaceUnit = { dir = "c2s", args = { "string", "Vector3" }, rate = 6 },
	UpgradeUnit = { dir = "c2s", args = { "number" }, rate = 6 },
	SellUnit = { dir = "c2s", args = { "number" }, rate = 6 },
	SetTargeting = { dir = "c2s", args = { "number", "string" }, rate = 6 },
	Vote = { dir = "c2s", args = {}, rate = 3 },
	ChooseMap = { dir = "c2s", args = { "string", "string" }, rate = 2 },
	JoinMatch = { dir = "c2s", args = {}, rate = 2 },
	RequestPlay = { dir = "c2s", args = {}, rate = 2 }, -- lobby Play button = stepping into the portal
	ReturnToLobby = { dir = "c2s", args = {}, rate = 2 },
	MatchState = { dir = "s2c" },
	OpenMapSelect = { dir = "s2c" },
	Results = { dir = "s2c" },
	Notify = { dir = "s2c" },
	EnemyDied = { dir = "s2c" }, -- (enemyId) client hides instantly, before Destroy replicates
	-- Studio-only dev menu (server/Dev.luau). studioOnly remotes are NOT created outside Studio.
	DevSandbox = { dir = "c2s", args = { "string", "string", "number", "number", "number", "number", "Vector3" }, rate = 4, studioOnly = true },
	DevToggle = { dir = "c2s", args = { "string", "boolean" }, rate = 6, studioOnly = true },
	DevSkipWave = { dir = "c2s", args = {}, rate = 2, studioOnly = true },
	DevReset = { dir = "c2s", args = {}, rate = 2, studioOnly = true },
	Beam = { dir = "s2c", unreliable = true }, -- (from, to, color) drawn client-side -- (text, kind) toast; kind = "error" | "info"
}

local folder
local remotes = {}

local function bad(v)
	local t = typeof(v)
	if t == "number" then
		return v ~= v or v == math.huge or v == -math.huge
	elseif t == "Vector3" then
		return bad(v.X) or bad(v.Y) or bad(v.Z)
	elseif t == "string" then
		return #v > 64
	end
	return false
end

function Net.validate(def, ...)
	local n = select("#", ...)
	if n < #def.args or n > #def.args then
		return false, ("expected %d args, got %d"):format(#def.args, n)
	end
	for i, want in ipairs(def.args) do
		local v = select(i, ...)
		if typeof(v) ~= want or bad(v) then
			return false, ("arg %d: expected %s, got %s"):format(i, want, typeof(v))
		end
	end
	return true
end

-- Token bucket per player per remote: capacity = rate, refills `rate` tokens per second.
local buckets = {}
local function allow(plr, name, rate)
	local key = plr.UserId .. ":" .. name
	local now = os.clock()
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

function Net.initServer()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name in pairs(Net.DEFS) do
		if Net.DEFS[name].studioOnly and not RunService:IsStudio() then
			continue
		end
		local r = Instance.new(Net.DEFS[name].unreliable and "UnreliableRemoteEvent" or "RemoteEvent")
		r.Name, r.Parent = name, folder
		remotes[name] = r
	end
	folder.Parent = RS
	game:GetService("Players").PlayerRemoving:Connect(function(plr)
		for name in pairs(Net.DEFS) do
			buckets[plr.UserId .. ":" .. name] = nil
		end
	end)
end

local function remote(name)
	if not remotes[name] then
		assert(Net.DEFS[name], "unknown remote " .. name)
		folder = folder or RS:WaitForChild("Remotes")
		remotes[name] = folder:WaitForChild(name)
	end
	return remotes[name]
end

-- Handlers return nil on success or a player-facing reason string on rejection.
-- Rejections are logged with player + action and sent to the client as a toast.
-- Handler errors are caught with a traceback and reported as "Server error".
local rateWarned = {}
function Net.on(name, fn)
	local def = Net.DEFS[name]
	assert(RunService:IsServer() and def and def.dir == "c2s", "Net.on: bad remote " .. name)
	if def.studioOnly and not RunService:IsStudio() then
		return -- remote does not exist in published builds
	end
	remote(name).OnServerEvent:Connect(function(plr, ...)
		if not allow(plr, name, def.rate or 5) then
			local k = plr.UserId .. name
			if not rateWarned[k] or os.clock() - rateWarned[k] > 5 then
				rateWarned[k] = os.clock()
				log.warn(plr.Name, name, "rejected: rate limited")
			end
			return
		end
		local ok, why = Net.validate(def, ...)
		if not ok then
			log.warn(plr.Name, name, "rejected: bad args:", why)
			remote("Notify"):FireClient(plr, "Bad request (" .. name .. ")", "error")
			return
		end
		local success, reason = Log.try("Net", name .. " from " .. plr.Name, fn, plr, ...)
		if not success then
			remote("Notify"):FireClient(plr, "Server error (" .. name .. ")", "error")
		elseif type(reason) == "string" then
			log.warn(plr.Name, name, "rejected:", reason)
			remote("Notify"):FireClient(plr, reason, "error")
		end
	end)
end

function Net.fire(name, plr, ...)
	remote(name):FireClient(plr, ...)
end

function Net.fireAll(name, ...)
	remote(name):FireAllClients(...)
end

function Net.send(name, ...)
	remote(name):FireServer(...)
end

function Net.listen(name, fn)
	return remote(name).OnClientEvent:Connect(fn)
end

return Net
