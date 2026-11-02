-- Unique control/DPS unit. Passive "Divine Dogs" lives in server/Abilities/Mogumo.
return {
	name = "Mogumo", order = 4, role = "Control",
	rarity = "Mythic", damageType = "Magical", element = "Shadow", -- damageType/element: display-only for now
	cost = 150, size = 3, range = 22, damage = 15, rate = 0.8, maxPlaced = 1,
	unique = true,
	topper = Color3.new(0, 0, 0),
	ability = "Mogumo",
	passive = {
		name = "Divine Dogs",
		describe = "Every {every:ord} attack, Mogumo summons a Divine Dog that charges back along the path, dealing {dogDamage} damage and stunning enemies it hits for {dogStun}s. Up to {maxDogs} dogs at once.",
	},
	abilityConfig = {
		every = 4, -- every Nth attack spawns a dog
		maxDogs = 2,
		dogDamage = 40,
		dogSpeed = 20, -- studs/s backward along the path
		dogLifetime = 3,
		dogRadius = 3, -- hit distance along the path
		dogStun = 0.4, -- brief pounce stun on hit
	},
	upgrades = {
		{ cost = 150, damage = 22, ability = { dogDamage = 60 } },
		{ cost = 250, damage = 30, range = 25, ability = { dogDamage = 90, maxDogs = 3 } },
		{ cost = 400, damage = 42, range = 28, rate = 0.65, ability = { dogDamage = 140, maxDogs = 4, every = 3 } },
	},
}
