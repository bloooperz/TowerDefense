-- Reusable drop-rates button + popup (summon panel AND the map/mode picker).
-- Reads shared/Summon for the CURRENT standard banner (server time), so the numbers shown are
-- exactly what the server rolls with. Popup is a child overlay (doesn't go through the
-- one-panel manager, so opening it never closes the panel it sits in).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Summon = require(Shared.Summon)
local Units = require(Shared.Units)
local Theme = require(script.Parent.Theme)

local Rates = {}

local function now()
	return workspace:GetServerTimeNow()
end

-- Lines for the current banner: { text, color }.
function Rates.lines()
	local banner = Summon.banner(Summon.window(now()), Units.list)
	local eff, top = Summon.effectiveRates(banner)
	local out = {}
	for i = #Summon.RARITIES, 1, -1 do
		local r = Summon.RARITIES[i]
		if eff[r] then
			local names = {}
			for _, id in ipairs(banner.byRarity[r]) do
				local u = Units.get(id)
				table.insert(names, u and u.name or id)
			end
			table.insert(out, { text = ("%s  %.2f%%  (%s)"):format(r, eff[r] * 100, table.concat(names, ", ")), color = Config.RARITY_COLORS[r] })
		end
	end
	table.insert(out, { text = ("Pity: %s guaranteed by roll %d"):format(top or "?", Summon.PITY_THRESHOLD), color = Theme.World.MUTED })
	table.insert(out, { text = ("Cost: %d Gems per roll (x1 / x10 / x50, no bonus)"):format(Summon.COST_PER_ROLL), color = Theme.World.MUTED })
	return out
end

-- Adds a "Rates" button to `parent` (props applied to the button). Returns button, popup.
function Rates.button(parent, props)
	local b = Theme.make("TextButton", {
		Text = "Rates", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Theme.World.BLUE, AutoButtonColor = false, Size = UDim2.fromOffset(90, 32), ZIndex = 24,
	}, parent)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	Theme.button(b, Theme.World.BLUE)
	local pop = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 200),
		BackgroundColor3 = Theme.World.BASE, Visible = false, ZIndex = 40,
	}, parent)
	Theme.panel(pop, Theme.World.BORDER_HOT)
	Theme.label({ Text = "Drop Rates", Size = UDim2.new(1, -60, 0, 28), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, TextColor3 = Theme.World.YELLOW }, pop)
	local close = Theme.make("TextButton", { Text = "X", Font = Theme.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Theme.World.RED, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -40, 0, 8), ZIndex = 42 }, pop)
	Theme.button(close, Theme.World.RED)
	local body = Theme.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 1, -52), ZIndex = 41 }, pop)
	Theme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	local function render()
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		for i, l in ipairs(Rates.lines()) do
			Theme.label({ Text = l.text, TextColor3 = l.color, Font = Theme.BODY, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41 }, body)
		end
	end
	b.Activated:Connect(function()
		if not pop.Visible then
			render()
		end
		pop.Visible = not pop.Visible
	end)
	close.Activated:Connect(function()
		pop.Visible = false
	end)
	return b, pop
end

return Rates
