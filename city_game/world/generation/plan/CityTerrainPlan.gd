extends RefCounted

# Terrain + water layer of the city plan: one meandering river, gentle hills.
# Heights are analytic so chunk sampling stays O(1) per point.

const WORLD_HALF_M := 35000.0
const POINT_STEP_M := 500.0

static func build(world_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var width := 50.0 + float(absi(world_seed) % 60)
	var phase := rng.randf_range(0.0, TAU)
	var amp_a := rng.randf_range(220.0, 340.0)
	var amp_b := rng.randf_range(80.0, 140.0)
	var base_a := sin(phase)
	var base_b := sin(phase * 1.7)
	var points: Array = []
	var x := -WORLD_HALF_M
	while x <= WORLD_HALF_M:
		var z := amp_a * (sin(x / 6000.0 + phase) - base_a) + amp_b * (sin(x / 2200.0 + phase * 1.7) - base_b)
		points.append(Vector3(x, 0.0, z))
		x += POINT_STEP_M
	var hills: Array = []
	for index in range(3):
		hills.append({
			"center": Vector2(rng.randf_range(-20000.0, 20000.0), rng.randf_range(-20000.0, 20000.0)),
			"radius_m": rng.randf_range(1800.0, 3600.0),
			"height_m": rng.randf_range(6.0, 18.0),
		})
	return {
		"river": {"points": points, "width_m": width, "depth_m": 3.0},
		"hills": hills,
		"water_level_m": -1.2,
	}

static func river_distance(terrain: Dictionary, x: float, z: float) -> float:
	var river: Dictionary = terrain.get("river", {})
	var points: Array = river.get("points", [])
	if points.size() < 2:
		return INF
	var best := INF
	var target := Vector2(x, z)
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var length_squared := ab.length_squared()
		var t := 0.0
		if length_squared > 0.0001:
			t = clampf((target - Vector2(a.x, a.z)).dot(ab) / length_squared, 0.0, 1.0)
		var closest := Vector2(a.x, a.z) + ab * t
		var distance := target.distance_to(closest)
		if distance < best:
			best = distance
	return best

static func height_at(terrain: Dictionary, x: float, z: float) -> float:
	var height := 3.0 * sin(x * 0.0018) + 2.0 * cos(z * 0.0015)
	for hill_variant in terrain.get("hills", []):
		var hill: Dictionary = hill_variant
		var center: Vector2 = hill.get("center", Vector2.ZERO)
		var radius := float(hill.get("radius_m", 1.0))
		var distance := Vector2(x, z).distance_to(center)
		if distance < radius:
			height += float(hill.get("height_m", 0.0)) * (1.0 - smoothstep(0.0, radius, distance))
	var river: Dictionary = terrain.get("river", {})
	var width := float(river.get("width_m", 0.0))
	var river_d := river_distance(terrain, x, z)
	if river_d < width * 1.6:
		var bank := smoothstep(width * 0.5, width * 1.6, river_d)
		height = lerpf(-float(river.get("depth_m", 3.0)), height, bank)
	return height

static func is_water(terrain: Dictionary, x: float, z: float) -> bool:
	var width := float((terrain.get("river", {}) as Dictionary).get("width_m", 0.0))
	return river_distance(terrain, x, z) < width * 0.5
