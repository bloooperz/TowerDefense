-- Server entry point.
local RS = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"
local remotes = {}
for _, name in ipairs({ "PlaceUnit", "StartGame", "MatchState", "UpgradeUnit", "SellUnit", "SetTargeting" }) do
	local r = Instance.new("RemoteEvent")
	r.Name, r.Parent = name, folder
	remotes[name] = r
end
folder.Parent = RS

-- Match info replicated to clients via attributes (no remote spam).
local info = Instance.new("Folder")
info.Name = "MatchInfo"
info.Parent = RS

require(script.Parent.World).build()
require(script.Parent.Match).init(remotes, info)
