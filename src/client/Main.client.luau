-- Client entry point: wires hotbar, placement, input, and match state.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Hotbar = require(script.Parent.Hotbar)
local Placement = require(script.Parent.Placement)
local UnitPanel = require(script.Parent.UnitPanel)
local Hud = require(script.Parent.Hud)

local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local PathRenderer = require(script.Parent.PathRenderer)
local MapSelect = require(script.Parent.MapSelect)
local Results = require(script.Parent.Results)

-- Remote shim so UnitPanel can keep calling :FireServer(...)
local function sender(name)
	return {
		FireServer = function(_, ...)
			Net.send(name, ...)
		end,
	}
end

local selected = nil
local function clear()
	selected = nil
	Placement.clear()
	Hotbar.highlight(nil)
end

-- Build GUI and connect state BEFORE any other waits so no update is missed.
Hotbar.init()
PathRenderer.init()
MapSelect.init()
Results.init()
Net.listen("MatchState", function(s)
	Hotbar.setState(s)
	Hud.setState(s)
	if s == "lobby" then
		clear()
		UnitPanel.close()
	end
end)

local function select(i)
	local u, id = Hotbar.unitAt(i)
	if not Hotbar.bar.Visible or not u then
		return
	end
	if selected == i then
		clear()
		return
	end
	UnitPanel.close()
	selected = i
	Placement.start(u, id)
	Hotbar.highlight(i)
end
Hotbar.onSelect = select
Hud.onVote = function()
	Net.send("Vote") -- toggles my vote
end
Hud.onUnitClicked = function(p)
	clear()
	UnitPanel.open(p)
end

local cashValue = Players.LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Cash")
Placement.init(cashValue)
Hud.init(cashValue)
UnitPanel.init(cashValue, sender("UpgradeUnit"), sender("SellUnit"), sender("SetTargeting"))
local mouse = Players.LocalPlayer:GetMouse()

-- Find one of MY placed units under the mouse (unit part or its topper).
local function unitUnderMouse()
	local target = mouse.Target
	while target and target ~= workspace do
		if target:GetAttribute("UnitId") then
			if target:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
				return target
			end
			return nil
		end
		target = target.Parent
	end
	return nil
end

local keys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

UIS.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape then
		UnitPanel.close() -- Esc may be marked processed by Roblox, so check first
		return
	end
	if processed then
		return
	end
	if keys[input.KeyCode] then
		select(keys[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 then
		clear()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and selected then
		local why = Placement.reason()
		if why then
			Placement.flash(why) -- keep placing so the player can move and retry
			return
		end
		local pos = Placement.position()
		local _, id = Hotbar.unitAt(selected)
		if pos and id then
			Net.send("PlaceUnit", id, pos)
		end
		clear()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- not placing: click my unit to open its panel, anywhere else closes it
		local unit = unitUnderMouse()
		if unit then
			UnitPanel.open(unit)
		else
			UnitPanel.close()
		end
	end
end)
