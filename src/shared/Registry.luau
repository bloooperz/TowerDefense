-- Loads every ModuleScript child of a folder into { byId, list, get }.
-- Each module returns a table; `id` defaults to the module name. Sorted by `order`, then id.
local Registry = {}

function Registry.load(folder: Instance)
	local reg = { byId = {}, list = {} }
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("ModuleScript") then
			local def = require(m)
			def.id = def.id or m.Name
			reg.byId[def.id] = def
			table.insert(reg.list, def)
		end
	end
	table.sort(reg.list, function(a, b)
		local oa, ob = a.order or 999, b.order or 999
		if oa ~= ob then
			return oa < ob
		end
		return a.id < b.id
	end)
	function reg.get(id)
		return reg.byId[id]
	end
	return reg
end

return Registry
