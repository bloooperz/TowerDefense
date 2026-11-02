return {
	name = "Rapid", order = 3, role = "DPS",
	rarity = "Rare", damageType = "Physical", element = "Lightning", -- damageType/element: display-only for now
	cost = 90, size = 2, range = 14, damage = 6, rate = 0.12, maxPlaced = 4,
	upgrades = {
		{ cost = 100, damage = 8 },
		{ cost = 170, damage = 11, range = 16, rate = 0.1 },
		{ cost = 280, damage = 15, range = 18, rate = 0.08 },
	},
}
