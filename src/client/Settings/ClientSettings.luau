-- Client side of player settings: reads the server-validated "Settings" attribute (JSON, from
-- PlayerData), applies it, and sends changes back (SaveSettings; server re-validates + persists).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Settings = require(Shared.Settings)
local Keybinds = require(Shared.Keybinds)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Input = require(script.Parent.Parent.Input)
local log = Log.new("Settings")

local ClientSettings = {}
local player = Players.LocalPlayer
local current = Settings.sanitize(nil, Keybinds)
local listeners = {}
local saveToken = 0
local pendingUntil = 0 -- ignore attribute echoes of older saves while the user is still changing things

-- SoundGroups for future music/SFX: put Sounds in SoundService.Music / SoundService.SFX.
local function group(name)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	return g
end

local function ownedByOther(inst)
	local id = inst:GetAttribute("OwnerId")
	return id and id ~= 0 and id ~= player.UserId
end

-- Local-only transparency for other players' towers (server/other clients unaffected).
local function applyHideOthers()
	local runtime = workspace:FindFirstChild("Runtime")
	if not runtime then
		return
	end
	local hide = current.hideOthers
	for _, inst in ipairs(runtime:GetDescendants()) do
		if inst:GetAttribute("OwnerId") ~= nil and ownedByOther(inst) then
			local parts = inst:GetDescendants()
			table.insert(parts, inst)
			for _, d in ipairs(parts) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = hide and 1 or 0
				elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
					d.Enabled = not hide
				end
			end
		end
	end
end

local function applyLowGraphics()
	local low = current.lowGraphics
	Lighting.GlobalShadows = not low
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = not low
		end
	end
end

local function apply()
	group("Music").Volume = current.music
	group("SFX").Volume = current.sfx
	Log.try("Settings", "lowGraphics", applyLowGraphics)
	Log.try("Settings", "hideOthers", applyHideOthers)
	Input.setOverrides(current.keybinds)
	for _, fn in ipairs(listeners) do
		task.spawn(Log.try, "Settings", "onChanged", fn, current)
	end
end

function ClientSettings.get()
	return current
end

function ClientSettings.onChanged(fn)
	table.insert(listeners, fn)
end

-- Change one field locally (instant), then save (debounced so sliders don't spam).
function ClientSettings.set(key, value)
	local raw = table.clone(current)
	raw[key] = value
	local clean, problems = Settings.sanitize(raw, Keybinds)
	if #problems > 0 then
		log.warn("rejected", key, problems[1])
		return false, problems[1]
	end
	current = clean
	apply()
	pendingUntil = os.clock() + 2
	saveToken += 1
	local my = saveToken
	task.delay(0.6, function()
		if my ~= saveToken then
			return
		end
		local ok, json = pcall(HttpService.JSONEncode, HttpService, current)
		if not ok then
			log.error("encode failed:", json)
			return
		end
		Net.send("SaveSettings", json) -- server rejection -> error toast via Net
	end)
	return true
end

local function loadFromAttribute()
	local json = player:GetAttribute("Settings")
	if type(json) ~= "string" then
		return
	end
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		log.error("bad Settings attribute:", raw)
		return
	end
	current = Settings.sanitize(raw, Keybinds)
	apply()
end

local function damageNumber(pos, amount, crit)
	if not current.damageNumbers then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + Vector3.new(math.random() - 0.5, 1.5, math.random() - 0.5)
	a.Parent = workspace.Terrain
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(crit and 3 or 2.2, crit and 1.4 or 1)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Adornee = a
	g.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = tostring(amount) .. (crit and "!" or "")
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = crit and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent = g
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(a, info, { WorldPosition = a.WorldPosition + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(t, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.75, function()
		a:Destroy()
	end)
end

function ClientSettings.init()
	loadFromAttribute()
	player:GetAttributeChangedSignal("Settings"):Connect(function()
		if os.clock() >= pendingUntil then
			Log.try("Settings", "load", loadFromAttribute)
		end
	end)
	Net.listen("DamageNumber", damageNumber)
	-- keep hide-others/low-graphics applied to towers/effects spawned later
	task.spawn(function()
		while true do
			task.wait(1)
			if current.hideOthers then
				Log.try("Settings", "hideOthers", applyHideOthers)
			end
		end
	end)
	workspace.DescendantAdded:Connect(function(d)
		if current.lowGraphics and (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) then
			d.Enabled = false
		end
	end)
end

return ClientSettings
