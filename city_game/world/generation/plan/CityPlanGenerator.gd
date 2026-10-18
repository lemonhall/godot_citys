extends RefCounted

# v63 city plan generator. Deterministic: every random value derives from
# world_seed, so the same seed yields the same plan_hash across runs.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")

const VERSION := 1

static func generate(world_seed: int) -> Dictionary:
	var terrain: Dictionary = CityTerrainPlan.build(world_seed)
	var plan := {
		"version": VERSION,
		"seed": world_seed,
		"terrain": terrain,
	}
	plan["plan_hash"] = _hash_plan(plan)
	return plan

static func _hash_plan(plan: Dictionary) -> String:
	var canonical := "v%d|seed=%d|river=%s|width=%.2f" % [
		int(plan.get("version", 0)),
		int(plan.get("seed", 0)),
		_points_signature((plan.get("terrain", {}) as Dictionary).get("river", {}).get("points", [])),
		float((plan.get("terrain", {}) as Dictionary).get("river", {}).get("width_m", 0.0)),
	]
	return "%d" % canonical.hash()

static func _points_signature(points: Array) -> String:
	var parts: Array[String] = []
	for point_variant in points:
		var point: Vector3 = point_variant
		parts.append("%.1f,%.1f" % [point.x, point.z])
	return ";".join(parts)
