extends RefCounted

# History layer: the old town sits on the river crossing, main axes grow from
# it, and a ring railway with stations defines the industrial belt.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")

static func build(world_seed: int, terrain: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51A7
	# The river is pinned to z = 0 at x = 0, so the ford is the origin.
	var core := Vector2(0.0, 0.0)
	var axes: Array = []
	for index in range(3):
		var angle := -PI * 0.5 + float(index) * (TAU / 3.0) + rng.randf_range(-0.22, 0.22)
		axes.append({
			"angle_rad": angle,
			"length_m": rng.randf_range(9000.0, 14000.0),
			"width_m": rng.randf_range(18.0, 26.0),
		})
	var rail_radius := 2200.0 + rng.randf_range(-150.0, 150.0)
	var rail_points: Array = []
	var segments := 48
	for index in range(segments + 1):
		var angle := TAU * float(index % segments) / float(segments)
		rail_points.append(Vector3(core.x + cos(angle) * rail_radius, 0.0, core.y + sin(angle) * rail_radius))
	var stations: Array = []
	for index in range(4):
		var angle := TAU * float(index) / 4.0 + rng.randf_range(-0.12, 0.12)
		stations.append({
			"position": Vector2(core.x + cos(angle) * rail_radius, core.y + sin(angle) * rail_radius),
			"name": "Station_%d" % index,
		})
	return {
		"core": core,
		"axes": axes,
		"rail": {"points": rail_points, "radius_m": rail_radius},
		"stations": stations,
	}

static func rail_distance(history: Dictionary, x: float, z: float) -> float:
	var points: Array = (history.get("rail", {}) as Dictionary).get("points", [])
	if points.size() < 2:
		return INF
	var target := Vector2(x, z)
	var best := INF
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var closest := Geometry2D.get_closest_point_to_segment(target, Vector2(a.x, a.z), Vector2(b.x, b.z))
		best = minf(best, target.distance_to(closest))
	return best
