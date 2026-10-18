extends RefCounted

# v63 city plan generator. Deterministic: every random value derives from
# world_seed, so the same seed yields the same plan_hash across runs.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")
const CityHistoryPlan := preload("res://city_game/world/generation/plan/CityHistoryPlan.gd")
const CityRoadPlan := preload("res://city_game/world/generation/plan/CityRoadPlan.gd")
const CityDistrictPlan := preload("res://city_game/world/generation/plan/CityDistrictPlan.gd")

const VERSION := 1

static func generate(world_seed: int) -> Dictionary:
	var terrain: Dictionary = CityTerrainPlan.build(world_seed)
	var history: Dictionary = CityHistoryPlan.build(world_seed, terrain)
	var roads: Dictionary = CityRoadPlan.build(terrain, history)
	var districts: Dictionary = CityDistrictPlan.build(world_seed, terrain, history)
	var plan := {
		"version": VERSION,
		"seed": world_seed,
		"terrain": terrain,
		"history": history,
		"roads": roads,
		"districts": districts,
	}
	plan["plan_hash"] = _hash_plan(plan)
	return plan

static func _hash_plan(plan: Dictionary) -> String:
	var terrain: Dictionary = plan.get("terrain", {})
	var history: Dictionary = plan.get("history", {})
	var roads: Dictionary = plan.get("roads", {})
	var districts: Dictionary = plan.get("districts", {})
	var canonical := "v%d|seed=%d|river=%s|width=%.2f|core=%s|axes=%s|rail=%.2f/%d|stations=%d|roads=%d|districts=%s" % [
		int(plan.get("version", 0)),
		int(plan.get("seed", 0)),
		_points_signature((terrain.get("river", {}) as Dictionary).get("points", [])),
		float((terrain.get("river", {}) as Dictionary).get("width_m", 0.0)),
		_vector_signature(history.get("core", Vector2.ZERO)),
		_axes_signature(history.get("axes", [])),
		float((history.get("rail", {}) as Dictionary).get("radius_m", 0.0)),
		((history.get("rail", {}) as Dictionary).get("points", []) as Array).size(),
		(history.get("stations", []) as Array).size(),
		(roads.get("roads", []) as Array).size(),
		_dict_signature(districts),
	]
	return "%d" % canonical.hash()

static func _points_signature(points: Array) -> String:
	var parts: Array[String] = []
	for point_variant in points:
		var point: Vector3 = point_variant
		parts.append("%.1f,%.1f" % [point.x, point.z])
	return ";".join(parts)

static func _vector_signature(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]

static func _axes_signature(axes: Array) -> String:
	var parts: Array[String] = []
	for axis_variant in axes:
		var axis: Dictionary = axis_variant
		parts.append("%.3f:%.1f" % [float(axis.get("angle_rad", 0.0)), float(axis.get("length_m", 0.0))])
	return ";".join(parts)

static func _dict_signature(values: Dictionary) -> String:
	var keys := values.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%.2f" % [str(key), float(values[key])])
	return ";".join(parts)
