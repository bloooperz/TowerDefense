-- Server entry point.
local RS = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"
local remotes = {}
for _, name in ipairs({ "PlaceUnit", "StartGame", "MatchState" }) do
	local r = Instance.new("RemoteEvent")
	r.Name, r.Parent = name, folder
	remotes[name] = r
end
folder.Parent = RS

require(script.Parent.World).build()
require(script.Parent.Match).init(remotes)
