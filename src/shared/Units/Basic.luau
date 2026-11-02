return {
	name = "Basic", order = 1, role = "DPS",
	rarity = "Rare", summonable = true, damageType = "Physical", -- damageType/element: display-only for now
	cost = 50, size = 3, range = 18, damage = 20, rate = 0.5, maxPlaced = 4,
	upgrades = {
		{ cost = 60, damage = 28, range = 20 },
		{ cost = 100, damage = 40, range = 22, rate = 0.45 },
		{ cost = 175, damage = 60, range = 25, rate = 0.4 },
	},
}
