-- Central keybinds (client runtime). Every key-driven action asks Input.action(keyCode) instead of
-- hardcoding Enum.KeyCode values, so rebinding in Settings > Controls takes effect everywhere.
-- Definitions/validation: shared/Keybinds. Overrides persist via ClientSettings (PlayerData.settings.keybinds).
local Shared = game:GetService("ReplicatedStorage").Shared
local Keybinds = require(Shared.Keybinds)
local Log = require(Shared.Log)
local log = Log.new("Input")

local Input = {}
Input.capturing = false -- true while Settings is waiting for a key; all actions are suppressed

local overrides, map, reverse, listeners = {}, {}, {}, {}

local function rebuild()
	map = Keybinds.resolve(overrides)
	reverse = {}
	for id, name in pairs(map) do
		local ok, kc = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok and kc then
			reverse[kc] = id
		else
			log.warn("unknown KeyCode", name, "for", id, "- using default")
			local def = Keybinds.byId[id].default
			map[id] = def
			reverse[Enum.KeyCode[def]] = id
		end
	end
end
rebuild()

-- Action id bound to this KeyCode (nil while capturing a rebind).
function Input.action(keyCode)
	if Input.capturing then
		return nil
	end
	return reverse[keyCode]
end

function Input.keyFor(id)
	return map[id]
end

function Input.overrides()
	return table.clone(overrides)
end

function Input.setOverrides(o)
	overrides = table.clone(o or {})
	rebuild()
	for _, fn in ipairs(listeners) do
		task.spawn(Log.try, "Input", "onChanged", fn)
	end
end

function Input.onChanged(fn)
	table.insert(listeners, fn)
end

return Input
