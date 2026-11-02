-- Draws everything in workspace.Runtime.Movers (enemies, Mogumo dogs, future projectiles)
-- from replicated attributes, so the server never moves parts per-frame:
--   pos = path:positionAt(Dist + (serverNow - CheckTime) * Speed) + (0, Height, 0)
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Maps = require(RS:WaitForChild("Shared"):WaitForChild("Maps"))

local PathRenderer = {}

function PathRenderer.init()
	local info = RS:WaitForChild("MatchInfo")
	local parts, cframes = {}, {}
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
