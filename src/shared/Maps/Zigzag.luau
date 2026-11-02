-- A zigzag path: more corners, more decisions about where to place.
return {
	name = "Zigzag Valley",
	order = 2,
	waypoints = {
		Vector3.new(-95, 0, -45),
		Vector3.new(-40, 0, -45),
		Vector3.new(-40, 0, 35),
		Vector3.new(20, 0, 35),
		Vector3.new(20, 0, -25),
		Vector3.new(90, 0, -25),
	},
	trackWidth = 8,
	bounds = Vector3.new(100, 0, 60),
	groundSize = Vector3.new(220, 1, 140),
	spawnOffset = Vector3.new(-75, 4, 10),
	groundColor = Color3.fromRGB(120, 150, 70),
}
