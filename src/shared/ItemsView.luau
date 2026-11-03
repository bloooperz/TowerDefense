-- PURE view-model for the lobby Inventory panel (I): items/materials (read-only).
-- Input: decoded `Items` attribute { [id] = count } or nil (not replicated yet -> loading).
local Items = if script then require(script.Parent.Items) else require("./Items") -- Roblox | lune
local ItemsView = {}

ItemsView.LOADING = "Loading items..."
ItemsView.EMPTY = "No items yet - earn XP food, portals and materials from matches and rewards."
ItemsView.CATEGORIES = { unitXp = "XP Food", portal = "Portal", material = "Material" }
ItemsView.OTHER = "Other"

function ItemsView.category(kind)
	return ItemsView.CATEGORIES[kind or ""] or ItemsView.OTHER
end

function ItemsView.view(raw)
	if type(raw) ~= "table" then
		return { loading = true, rows = {}, message = ItemsView.LOADING, header = "Items: -" }
	end
	local rows, total = {}, 0
	for id, count in pairs(raw) do
		local n = tonumber(count) or 0
		if n > 0 then
			local it = Items.get(tostring(id))
			local cat = ItemsView.category(it and it.kind)
			local name = it and it.name or tostring(id)
			local tip = name .. " - " .. cat
			if it and it.kind == "unitXp" and it.xp then
				tip = ("%s - %s (+%d unit XP)"):format(name, cat, it.xp)
			end
			table.insert(rows, { id = tostring(id), name = name, count = n, countText = "x" .. n, category = cat, tooltip = tip, order = it and it.order or math.huge })
			total += n
		end
	end
	table.sort(rows, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)
	return { loading = false, rows = rows, message = #rows == 0 and ItemsView.EMPTY or nil, header = ("Items: %d"):format(total) }
end

return ItemsView
