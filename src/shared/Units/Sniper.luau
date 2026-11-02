return {
	name = "Sniper", order = 2, role = "DPS",
	rarity = "Epic", summonable = true, damageType = "Physical", -- damageType/element: display-only for now
	cost = 120, size = 3, range = 45, damage = 80, rate = 2.0, maxPlaced = 3,
	armorPen = 0.25,
	upgrades = {
		{ cost = 130, damage = 120 },
		{ cost = 220, damage = 180, range = 55, rate = 1.8 },
		{ cost = 350, damage = 280, range = 65, rate = 1.6 },
	},
}
