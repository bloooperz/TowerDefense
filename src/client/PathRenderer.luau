-- Draws everything in workspace.Runtime.Movers (enemies, Mogumo dogs, future projectiles)
-- from replicated attributes, so the server never moves parts per-frame:
--   pos = path:positionAt(Dist + (serverNow - CheckTime) * Speed) + (0, Height, 0)
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Maps = require(RS:WaitForChild("Shared"):WaitForChild("Maps"))

local Net = require(RS.Shared.Net)

local PathRenderer = {}
local dead = {} -- [enemyId] = true: hidden the instant the server says it died

function PathRenderer.init()
	local info = RS:WaitForChild("MatchInfo")
	local parts, cframes = {}, {}
	local FAR = CFrame.new(0, -1000, 0)
	-- Death arrives as a remote; hide immediately instead of waiting for Destroy to replicate.
	Net.listen("EnemyDied", function(id)
		dead[id] = true
		local runtime = workspace:FindFirstChild("Runtime")
		local movers = runtime and runtime:FindFirstChild("Movers")
		if movers then
			for _, p in ipairs(movers:GetChildren()) do
				if p:GetAttribute("EnemyId") == id and p:IsA("BasePart") then
					p.Transparency = 1
					p.CFrame = FAR
					for _, c in ipairs(p:GetChildren()) do
						if c:IsA("BillboardGui") then
							c.Enabled = false
						end
					end
				end
			end
		end
	end)
	-- Beams: pooled, client-side only.
	local pool = {}
	Net.listen("Beam", function(from, to, color)
		local b = table.remove(pool)
		if not b then
			b = Instance.new("Part")
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
			b.Material = Enum.Material.Neon
			b.Name = "Shot"
			b.Parent = workspace
		end
		local dist = (to - from).Magnitude
		b.Color = color
		b.Size = Vector3.new(0.3, 0.3, dist)
		b.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
		task.delay(0.08, function()
			b.CFrame = FAR
			table.insert(pool, b)
		end)
	end)
	RunService.RenderStepped:Connect(function()
		local runtime = workspace:FindFirstChild("Runtime")
		local movers = runtime and runtime:FindFirstChild("Movers")
		local map = Maps.get(info:GetAttribute("MapId") or "")
		if not movers or not map then
			return
		end
		local path = Maps.path(map)
		local now = workspace:GetServerTimeNow()
		table.clear(parts)
		table.clear(cframes)
		for _, p in ipairs(movers:GetChildren()) do
			local d0, t0, speed = p:GetAttribute("Dist"), p:GetAttribute("CheckTime"), p:GetAttribute("Speed")
			local eid = p:GetAttribute("EnemyId")
			if eid and dead[eid] then
				continue
			end
			if d0 and t0 and speed and p:IsA("BasePart") then
				local pos, dir = path:positionAt(d0 + (now - t0) * speed)
				pos += Vector3.new(0, p:GetAttribute("Height") or 0, 0)
				local face = speed < 0 and -dir or dir
				table.insert(parts, p)
				table.insert(cframes, CFrame.lookAt(pos, pos + Vector3.new(face.X, 0, face.Z)))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PathRenderer
