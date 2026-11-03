-- Pure visual-state rules for shared UI controls (client resolves palette keys to Theme colors).
local UiState = {}

-- Settings toggle: value -> visual. fill: "GREEN" (on) | "NEUTRAL" (off).
function UiState.toggle(on)
	on = on == true
	return { on = on, text = on and "ON" or "OFF", fill = on and "GREEN" or "NEUTRAL" }
end

-- Click = optimistic flip.
function UiState.flip(on)
	return not (on == true)
end

-- Map/mode picker card. Selected is the same solid orange for every map (independent of map data).
function UiState.pickCard(selected)
	if selected then
		return { fill = "ORANGE", edge = "ORANGE_EDGE", thickness = 3 }
	end
	return { fill = "NEUTRAL", edge = "BORDER", thickness = 2 }
end

-- In-match upgrade button. cost == nil -> max level. fill: "GREEN" (affordable) | "GREY".
function UiState.upgradeButton(cash, cost)
	if cost == nil then
		return { text = "MAX LEVEL", fill = "GREY", enabled = false }
	end
	local ok = (cash or 0) >= cost
	return { text = "UPGRADE  $" .. cost, fill = ok and "GREEN" or "GREY", enabled = ok }
end

return UiState
