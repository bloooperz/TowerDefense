-- Duplicate-copy scan (stale Client/LobbyUI/Remotes saved in the place next to Rojo's copy).
local D = require("../../src/shared/Diagnostics")
local function node(name, parent)
	local n = { Name = name, kids = {}, parent = parent }
	function n:GetFullName() return (self.parent and self.parent:GetFullName() .. "." or "") .. self.Name end
	function n:GetDescendants()
		local out = {}
		local function go(x) for _, k in ipairs(x.kids) do table.insert(out, k); go(k) end end
		go(self)
		return out
	end
	if parent then table.insert(parent.kids, n) end
	return n
end
return function(t)
	t.test("duplicates: finds two Client folders / two LobbyUI, ignores singles", function()
		local ps = node("PlayerScripts")
		local c1 = node("Client", ps); node("LobbyUI", node("Lobby", c1))
		local c2 = node("Client", ps); node("LobbyUI", node("Lobby", c2))
		local rs = node("ReplicatedStorage"); node("Remotes", rs)
		local dup = D.duplicates({ ps, rs, nil }, { "Client", "LobbyUI", "Remotes" })
		t.eq(#dup.Client, 2); t.eq(#dup.LobbyUI, 2); t.eq(dup.Remotes, nil)
		t.eq(dup.LobbyUI[1], "PlayerScripts.Client.Lobby.LobbyUI")
	end)
end
