-- Finds duplicate copies of scripts/folders (e.g. an old "Client" folder saved in the place
-- next to the Rojo-synced one). Both copies RUN, so old code keeps erroring. Pure scan of an
-- instance tree; returns { [name] = { fullName, ... } } for names that appear more than once.
local Diagnostics = {}

function Diagnostics.duplicates(roots, names)
	local want, found = {}, {}
	for _, n in ipairs(names) do
		want[n] = true
	end
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if want[d.Name] then
					found[d.Name] = found[d.Name] or {}
					table.insert(found[d.Name], d:GetFullName())
				end
			end
		end
	end
	local dup = {}
	for n, list in pairs(found) do
		if #list > 1 then
			dup[n] = list
		end
	end
	return dup
end

return Diagnostics
