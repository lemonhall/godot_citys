extends RefCounted

# Road layer: radial arteries grow from the old-town ford along the history
# axes, plus a ring road. Every sampled point must stay out of the water.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")

const STEP_M := 200.0

static func build(terrain: Dictionary, history: Dictionary) -> Dictionary:
	var core: Vector2 = history.get("core", Vector2.ZERO)
	var roads: Array = []
	for axis_variant in history.get("axes", []):
		var axis: Dictionary = axis_variant
		var angle := float(axis.get("angle_rad", 0.0))
		var direction := Vector2(cos(angle), sin(angle))
		var points: Array = []
		var distance := 0.0
		var length := float(axis.get("length_m", 9000.0))
		# The ford itself is water: skip ahead to the first dry point.
		while distance <= length:
			var start_point := core + direction * distance
			if not CityTerrainPlan.is_water(terrain, start_point.x, start_point.y):
				break
			distance += STEP_M
		while distance <= length:
			var point := core + direction * distance
			if CityTerrainPlan.is_water(terrain, point.x, point.y):
				break
			points.append(Vector3(point.x, 0.0, point.y))
			distance += STEP_M
		_append_road(roads, points, "arterial", float(axis.get("width_m", 20.0)))

	var ring_points: Array = []
	var ring_radius := float((history.get("rail", {}) as Dictionary).get("radius_m", 2200.0)) * 1.35
	for index in range(73):
		var angle := TAU * float(index % 72) / 72.0
		var point := core + Vector2(cos(angle), sin(angle)) * ring_radius
		if CityTerrainPlan.is_water(terrain, point.x, point.y):
			_append_road(roads, ring_points, "ring", 16.0)
			ring_points = []
			continue
		ring_points.append(Vector3(point.x, 0.0, point.y))
	_append_road(roads, ring_points, "ring", 16.0)
	return {"roads": roads}

static func _append_road(roads: Array, points: Array, road_class: String, width_m: float) -> void:
	if points.size() < 4:
		return
	roads.append({"class": road_class, "width_m": width_m, "points": points})
