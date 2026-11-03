-- Lobby leveling UI, built into existing lobby panels:
--  * Profile panel: player level/XP, level-gated unlocks, milestone claim list.
-- Read-only views of server attributes (Milestones / Level / Xp); every
-- action goes through a validated remote (ClaimMilestone).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local UnitLevel = require(Shared.UnitLevel)
local PlayerLevel = require(Shared.PlayerLevel)
local Items = require(Shared.Items)
local Milestones = require(Shared.Milestones)
local Summon = require(Shared.Summon)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Theme = require(script.Parent.Parent.UI.Theme)
local Shape = require(script.Parent.Parent.UI.Shape)
local Toast = require(script.Parent.Parent.Toast)

local log = Log.new("Progression")
local player = Players.LocalPlayer
local U = Theme.Unit
local Progression = {}

local function decode(attr, default)
	local raw = player:GetAttribute(attr)
	if type(raw) ~= "string" or raw == "" then
		return default
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		log.warn("bad", attr, "attribute:", v)
		return default
	end
	return v
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function list(parent, props)
	local s = Theme.make("ScrollingFrame", {
		BackgroundColor3 = U.BASE_2, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
	}, parent)
	for k, v in pairs(props) do
		s[k] = v
	end
	Shape.apply(s, { radius = 6, edge = U.BORDER, thickness = 2, gradient = false })
	Theme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, s)
	return s
end

local function btn(text, color, parent, props)
	local b = Theme.make("TextButton", {
		Text = text, Font = Theme.BODY, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 30), ZIndex = 23, AutoButtonColor = false,
	}, parent)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	Theme.button(b, color)
	Theme.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	return b
end

local function label(text, parent, props)
	local l = Theme.label({ Text = text, Size = UDim2.new(1, 0, 0, 22), ZIndex = 23, TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BODY }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

local function bar(parent, props, color)
	local bg = Theme.make("Frame", { BackgroundColor3 = U.BASE, ZIndex = 23 }, parent)
	for k, v in pairs(props) do
		bg[k] = v
	end
	Shape.apply(bg, { radius = 6, edge = U.BORDER, thickness = 2 })
	local fill = Theme.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, ZIndex = 24 }, bg)
	Theme.button(fill, color)
	local txt = Theme.label({ Size = UDim2.fromScale(1, 1), ZIndex = 25, Font = Theme.BODY }, bg)
	return fill, txt
end

-- (Units panel moved to Lobby/UnitsUI: Collection grid + detail sidebar with Feed/Fuse.)

------------------------------------------------------------------ Profile panel
local function rewardText(m)
	local parts = {}
	if m.gems then
		table.insert(parts, m.gems .. " gems")
	end
	if m.rerolls then
		table.insert(parts, m.rerolls .. " rerolls")
	end
	for id, n in pairs(m.items or {}) do
		local it = Items.get(id)
		table.insert(parts, ("%d %s"):format(n, it and it.name or id))
	end
	return table.concat(parts, ", ")
end

local function buildProfile(panel)
	panel.root.Size = UDim2.fromOffset(560, 440)
	panel.body.Visible = false
	local root = panel.root
	local head = Theme.make("Frame", { Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 84), BackgroundTransparency = 1, ZIndex = 22 }, root)
	local lvl = label("", head, { Font = Theme.FONT, Size = UDim2.new(1, 0, 0, 28) })
	local fill, txt = bar(head, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 22) }, Theme.World.YELLOW)
	local unlocks = label("", head, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 22), TextColor3 = Theme.World.MUTED, TextScaled = true })
	label("MILESTONES", root, { Position = UDim2.fromOffset(20, 150), Size = UDim2.new(1, -40, 0, 24), Font = Theme.FONT })
	local ms = list(root, { Position = UDim2.fromOffset(20, 178), Size = UDim2.new(1, -40, 1, -198) })

	local function render()
		local xp = player:GetAttribute("Xp") or 0
		local l, into, need = PlayerLevel.progress(xp)
		lvl.Text = ("Player Level %d"):format(l)
		fill.Size = UDim2.fromScale(need > 0 and math.clamp(into / need, 0, 1) or 1, 1)
		txt.Text = need > 0 and ("%d / %d XP"):format(into, need) or "MAX"
		local gates = {}
		for f, req in pairs(PlayerLevel.UNLOCKS) do
			table.insert(gates, { f, req })
		end
		table.sort(gates, function(a, b)
			return a[2] < b[2]
		end)
		local parts = {}
		for _, g in ipairs(gates) do
			table.insert(parts, ("%s Lv%d%s"):format(g[1], g[2], l >= g[2] and " (open)" or ""))
		end
		unlocks.Text = "Unlocks: " .. table.concat(parts, "  |  ")
		local claimed = {}
		for _, v in ipairs(decode("Milestones", {})) do
			claimed[v] = true
		end
		clear(ms)
		for i, m in ipairs(Milestones.LIST) do
			local row = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.World.BASE, LayoutOrder = i, ZIndex = 22 }, ms)
			Shape.apply(row, { radius = 6, edge = Theme.World.BORDER, thickness = 2 })
			label(("Lv %d:  %s"):format(m.level, rewardText(m)), row, { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -130, 1, -12), TextScaled = true })
			local state = claimed[m.level] and "Claimed" or (l >= m.level and "Claim" or "Locked")
			local col = state == "Claim" and Theme.World.GREEN or Color3.fromRGB(80, 66, 58)
			local b = btn(state, col, row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(110, 26) })
			b.Activated:Connect(function()
				if state == "Claim" then
					Net.send("ClaimMilestone", m.level)
				elseif state == "Locked" then
					Toast.show(("Reach player level %d to claim"):format(m.level), "error")
				end
			end)
		end
	end
	for _, a in ipairs({ "Xp", "Milestones" }) do
		player:GetAttributeChangedSignal(a):Connect(function()
			Log.try("Progression", "profile render", render)
		end)
	end
	Log.try("Progression", "profile render", render)
end

function Progression.build(panels)
	if panels.Profile then
		Log.try("Progression", "build Profile", buildProfile, panels.Profile)
	end
	-- level-gated lobby panels: show the requirement instead of "Coming soon" (server enforces)
	for name, p in pairs(panels) do
		if PlayerLevel.UNLOCKS[name] and p.body and p.body.Visible then
			local function upd()
				local lv = player:GetAttribute("Level") or 1
				p.body.Text = PlayerLevel.isUnlocked(lv, name) and "Coming soon" or ("Unlocks at player level %d"):format(PlayerLevel.required(name))
			end
			player:GetAttributeChangedSignal("Level"):Connect(upd)
			upd()
		end
	end
end

return Progression
