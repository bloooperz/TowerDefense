-- Drag (mouse or touch) on a ViewportFrame spins its model around Y; optional slow auto-rotate
-- while not dragging. Returns a stop() that disconnects everything.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Spin = {}

function Spin.attach(vp, model, opts)
	opts = opts or {}
	local dragging, lastX, angle = false, 0, 0
	local pivot = model:GetPivot()
	local conns = {}
	local function apply()
		model:PivotTo(pivot * CFrame.Angles(0, angle, 0))
	end
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	table.insert(conns, vp.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging, lastX = true, i.Position.X
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			angle += (i.Position.X - lastX) * 0.01
			lastX = i.Position.X
			apply()
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(i)
		if isPress(i) then
			dragging = false
		end
	end))
	if opts.autoRotate then
		local speed = opts.autoRotate == true and 0.6 or opts.autoRotate -- rad/s
		table.insert(conns, RunService.RenderStepped:Connect(function(dt)
			if not dragging and vp.Parent and vp.Visible then
				angle += speed * dt
				apply()
			end
		end))
	end
	local function stop()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		table.clear(conns)
	end
	vp.Destroying:Connect(stop)
	return stop
end

return Spin
