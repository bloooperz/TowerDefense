-- End-of-match results screen (Victory/Defeat, waves, time, rewards).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = RS:WaitForChild("Shared")
local Net = require(Shared.Net)
local Style = require(script.Parent.Style)

local Results = {}
local root, title, body

-- Stage XP per equipped unit: "Basic +240 XP (Lv 3 -> 5)"
local function unitLines(r)
	local out = {}
	for _, u in pairs(r.units or {}) do
		local lv = u.levels > 0 and (' <font color="#ffd23c">Lv %d -> %d</font>'):format(u.level - u.levels, u.level) or (" Lv %d"):format(u.level)
		table.insert(out, ("%s +%d XP%s"):format(u.unitId, u.gained, lv))
	end
	table.sort(out)
	if #out == 0 then
		return ""
	end
	return '<font size="16">Unit XP: ' .. table.concat(out, ",  ") .. "</font>"
end

local function fmtTime(s)
	return string.format("%d:%02d", s // 60, s % 60)
end

function Results.init()
	local screen = Style.make("ScreenGui", { Name = "Results", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 30 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	root = Style.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 380), Visible = false }, screen)
	title = Style.text({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 10) }, root)
	body = Style.text({
		Size = UDim2.new(1, -40, 0, 220),
		Position = UDim2.fromOffset(20, 76),
		TextScaled = false,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	}, root)
	local b = Style.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(220, 46),
		BackgroundColor3 = Style.BLUE,
		Font = Style.FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Return to Lobby",
	}, root)
	Style.button(b, Style.BLUE)
	b.MouseButton1Click:Connect(function()
		Net.send("ReturnToLobby")
		root.Visible = false
	end)
	Net.listen("Results", function(r)
		title.Text = r.won and "VICTORY" or "DEFEAT"
		title.TextColor3 = r.won and Style.YELLOW or Style.RED
		body.Text = table.concat({
			("%s  -  %s"):format(r.mapName or "?", r.modeName or "?"),
			("Waves cleared: <b>%d</b>    Time: <b>%s</b>"):format(r.waves, fmtTime(r.time)),
			("Kills: <b>%d</b>    Damage: <b>%d</b>"):format(r.kills, r.damage),
			"",
			('<font color="#7fd4ff">+%d Gems</font>    <font color="#b4ff7f">+%d XP</font>    Player Lv %d'):format(r.gems, r.xp, r.level or 1),
			unitLines(r),
		}, "\n")
		root.Visible = true
	end)
	Net.listen("MatchState", function(s)
		if s == "lobby" then
			root.Visible = false
		end
	end)
end

return Results
