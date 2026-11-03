-- PURE view-model for the lobby Inventory ("Collection") panel. UI-only: no server actions.
-- Maps the replicated `Inventory` attribute (decoded JSON list) to grid cards + a detail view.
-- Stats are shown exactly as stored on the unit def (no derived numbers / percentages).
local InventoryView = {}

InventoryView.MAX_UNITS = 100 -- header "Units: N/100" (display cap only)
InventoryView.MAX_LEVEL = 80
InventoryView.ACTIONS = { "Equip", "Sell", "Lock", "View" } -- detail buttons, top -> bottom
InventoryView.LOADING = "Loading units..."
InventoryView.EMPTY = "No units yet - summon some!"

local function traitInfo(traitId, traitsById)
	if traitId == nil or traitId == "" or traitId == "None" then
		return nil
	end
	local t = traitsById and traitsById[traitId]
	local desc = t and t.desc or ""
	if t and desc == "" then -- plain-language text from the trait's own fields (as stored)
		local parts = {}
		for _, k in ipairs({ { "damage", "Damage" }, { "range", "Range" }, { "rate", "Attack cooldown" } }) do
			if t[k[1]] then
				table.insert(parts, ("%s x%s"):format(k[2], tostring(t[k[1]])))
			end
		end
		desc = table.concat(parts, ", ")
	end
	return { id = tostring(traitId), name = t and t.name or tostring(traitId), desc = desc }
end

-- inv: decoded Inventory list or nil (not replicated yet). getDef(unitId) -> def?
-- Returns { loading, count, max, header, cards = { {uid, unitId, name, rarity, level, levelText, equipped, trait?} } }
function InventoryView.cards(inv, getDef, traitsById)
	if type(inv) ~= "table" then
		return { loading = true, count = 0, max = InventoryView.MAX_UNITS, header = "Units: -/" .. InventoryView.MAX_UNITS, cards = {}, message = InventoryView.LOADING }
	end
	local cards = {}
	for _, u in ipairs(inv) do
		local def = getDef(u.unitId)
		local level = tonumber(u.level) or 1
		table.insert(cards, {
			uid = tostring(u.uid),
			unitId = tostring(u.unitId),
			name = def and def.name or tostring(u.unitId),
			rarity = def and def.rarity or "Common",
			level = level,
			levelText = "Lv. " .. level,
			equipped = u.equipped == true,
			trait = traitInfo(u.trait, traitsById),
		})
	end
	table.sort(cards, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return a.uid < b.uid
	end)
	return {
		loading = false, count = #cards, max = InventoryView.MAX_UNITS,
		header = ("Units: %d/%d"):format(#cards, InventoryView.MAX_UNITS),
		cards = cards, message = #cards == 0 and InventoryView.EMPTY or nil,
	}
end

-- Detail panel model for one card. Stat chips read the def's base values as-is.
function InventoryView.detail(card, def, locked)
	local stats = {}
	if def then
		table.insert(stats, { key = "damage", label = "Damage", value = tostring(def.damage) })
		table.insert(stats, { key = "rate", label = "Cooldown", value = tostring(def.rate) .. "s" })
		table.insert(stats, { key = "range", label = "Range", value = tostring(def.range) })
	end
	local extra = {}
	if def then
		for _, k in ipairs({ { "role", "Role" }, { "damageType", "Damage type" }, { "cost", "Place cost" }, { "maxPlaced", "Max placed" } }) do
			if def[k[1]] ~= nil then
				table.insert(extra, { label = k[2], value = tostring(def[k[1]]) })
			end
		end
	end
	local buttons = {}
	for _, a in ipairs(InventoryView.ACTIONS) do
		local text = a
		if a == "Equip" and card.equipped then
			text = "Unequip"
		elseif a == "Lock" and locked then
			text = "Unlock"
		end
		table.insert(buttons, { action = a, text = text })
	end
	return {
		name = card.name, rarity = card.rarity,
		levelText = ("Lvl %d/%d"):format(card.level, InventoryView.MAX_LEVEL),
		trait = card.trait, -- nil = no trait chip text ("No trait")
		traitText = card.trait and card.trait.name or "No trait",
		stats = stats, extra = extra, buttons = buttons,
		lockText = locked and "LOCKED" or "Unlocked",
	}
end

-- Client-only lock toggle (visual state; no server effect).
function InventoryView.newLocks()
	local set = {}
	return {
		toggle = function(uid)
			set[uid] = not set[uid] or nil
			return set[uid] == true
		end,
		isLocked = function(uid)
			return set[uid] == true
		end,
	}
end

-- Detail selection: select(uid) opens, selecting the open uid again closes; close() clears.
function InventoryView.newSelection()
	local cur = nil
	return {
		select = function(uid)
			cur = (cur ~= uid) and uid or nil
			return cur
		end,
		close = function()
			local was = cur ~= nil
			cur = nil
			return was
		end,
		get = function()
			return cur
		end,
	}
end

return InventoryView
