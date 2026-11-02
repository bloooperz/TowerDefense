-- First-load starter pick. Shown while the server's StarterChosen attribute is false (new
-- accounts own no units). Cards come from Summon.STARTERS; the server validates + grants the unit
-- and Summon.STARTER_GEMS, so a double click is harmless (second claim is rejected server-side).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Units = require(Shared.Units)
local Summon = require(Shared.Summon)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Shape = require(UI.Shape)
local Card = require(UI.Card)
local Toast = require(script.Parent.Parent.Toast)

local log = Log.new("StarterUI")
local player = Players.LocalPlayer
local W = Theme.World
local StarterUI = {}

function StarterUI.init(screen)
	local overlay = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 50, Active = true }, screen)
	local box = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 300), ZIndex = 51 }, overlay)
	Theme.panel(box, Theme.COLORS.Summon)
	Theme.banner(box, "Choose your starter")
	Theme.label({ Text = ("Pick your first unit. You also get %d Gems to summon with."):format(Summon.STARTER_GEMS), Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 56), Font = Theme.BODY, TextColor3 = W.TEXT, ZIndex = 52 }, box)
	local row = Theme.make("Frame", { Size = UDim2.new(1, -40, 0, 170), Position = UDim2.fromOffset(20, 96), BackgroundTransparency = 1, ZIndex = 52 }, box)
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local sent = false
	local done = false -- sticky: once chosen this session, later data refreshes never re-open it
	for i, id in ipairs(Summon.STARTERS) do
		local def = Units.get(id)
		if def then
			local col = Theme.make("Frame", { Size = UDim2.fromOffset(110, 160), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 52 }, row)
			local c = Card.new(def, 1, col)
			c.Position = UDim2.fromOffset(12, 0)
			c.ZIndex = 53
			local b = Theme.make("TextButton", { Text = "Choose", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = W.GREEN, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), ZIndex = 54 }, col)
			Theme.button(b, W.GREEN)
			Shape.outlineText(b, 2)
			b.Activated:Connect(function()
				if sent then
					return
				end
				sent = true
				b.Text = "..."
				Net.send("ClaimStarter", id)
				task.delay(5, function()
					sent = false
					b.Text = "Choose"
					if not done then -- server rejections already toast their reason; this is "no reply"
						log.warn("ClaimStarter: no StarterChosen update from the server after 5s (check server Output for [TD:Net] / [TD:PlayerData])")
						Toast.show("Starter pick didn't go through. Try again.", "error")
					end
				end)
			end)
		else
			log.warn("starter unit missing from registry:", id)
		end
	end
	local function upd()
		-- nil = data not loaded yet (keep hidden); only an explicit false shows the picker
		local chosen = player:GetAttribute("StarterChosen")
		local inv = player:GetAttribute("Inventory")
		local owns = type(inv) == "string" and inv ~= "" and inv ~= "[]"
		if chosen == true or owns then
			done = true
		end
		overlay.Visible = Summon.showStarter(chosen, owns, done)
	end
	player:GetAttributeChangedSignal("StarterChosen"):Connect(upd)
	player:GetAttributeChangedSignal("Inventory"):Connect(upd)
	upd()
end

return StarterUI
