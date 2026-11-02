-- The original straight map.
return {
	name = "Training Grounds",
	order = 1,
	waypoints = { Vector3.new(-80, 0, 0), Vector3.new(80, 0, 0) },
	trackWidth = 8,
	bounds = Vector3.new(100, 0, 60), -- half extents for placement
	groundSize = Vector3.new(220, 1, 140),
	spawnOffset = Vector3.new(-60, 4, 25),
	groundColor = Color3.fromRGB(70, 140, 70),
}
