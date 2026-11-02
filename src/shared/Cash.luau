-- Single accessor for match cash. The source of truth is the player ATTRIBUTE "Cash"
-- (always present, never yields). leaderstats.Cash is only a display mirror that
-- exists while the player is in a match (Cash.setVisible).
-- Cash.of(plr) returns a handle: h.Value (read/write; writes are server-only), h.Changed:Connect(fn).
local Cash = {}
local ATTR = "Cash"

local function mirror(plr)
	local ls = plr:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Cash")
end

local mt = {}
function mt.__index(h, k)
	if k == "Value" then
		return h.plr:GetAttribute(ATTR) or 0
	elseif k == "Changed" then
		return h.plr:GetAttributeChangedSignal(ATTR)
	end
	return nil
end
function mt.__newindex(h, k, v)
	assert(k == "Value", "Cash handle: only .Value is writable")
	v = math.floor(v)
	h.plr:SetAttribute(ATTR, v)
	local m = mirror(h.plr)
	if m then
		m.Value = v
	end
end

function Cash.of(plr)
	return setmetatable({ plr = plr }, mt)
end

function Cash.get(plr): number
	return plr:GetAttribute(ATTR) or 0
end

-- Server: show/hide the leaderboard column. newValue: optional factory for tests.
function Cash.setVisible(plr, visible, newValue)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local m = ls:FindFirstChild("Cash")
	if visible and not m then
		m = (newValue or Instance.new)("IntValue")
		m.Name = "Cash"
		m.Value = Cash.get(plr)
		m.Parent = ls
	elseif not visible and m then
		m:Destroy()
	end
end

return Cash
