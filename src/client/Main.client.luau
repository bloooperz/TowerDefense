-- Client entry point: wires hotbar, placement, input, and match state.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Hotbar = require(script.Parent.Hotbar)
local Placement = require(script.Parent.Placement)

local remotes = RS:WaitForChild("Remotes")
local placeEvent = remotes:WaitForChild("PlaceUnit")
local startEvent = remotes:WaitForChild("StartGame")
local stateEvent = remotes:WaitForChild("MatchState")

local selected = nil
local function clear()
	selected = nil
	Placement.clear()
	Hotbar.highlight(nil)
end

-- Build GUI and connect state BEFORE any other waits so no update is missed.
Hotbar.init()
stateEvent.OnClientEvent:Connect(function(s)
	Hotbar.setState(s)
	if s == "lobby" then
		clear()
	end
end)

local function select(i)
	if not Hotbar.bar.Visible or not Config.UNITS[i] then
		return
	end
	if selected == i then
		clear()
		return
	end
	selected = i
	Placement.start(Config.UNITS[i])
	Hotbar.highlight(i)
end
Hotbar.onSelect = select
Hotbar.onStart = function()
	startEvent:FireServer()
end

local cashValue = Players.LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Cash")
Placement.init(cashValue)

local keys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if keys[input.KeyCode] then
		select(keys[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 then
		clear()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and selected then
		local pos = Placement.position()
		if pos then
			placeEvent:FireServer(selected, pos)
		end
		clear()
	end
end)
