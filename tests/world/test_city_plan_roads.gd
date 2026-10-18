extends SceneTree

# v63 M2: radial + ring roads must stay out of the water.
# REQ-0034-003.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const SAMPLER_PATH := "res://city_game/world/generation/plan/CityPlanSampler.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	if not T.require_true(self, generator_script != null, "CityPlanGenerator must exist"):
		return
	var plan: Dictionary = generator_script.new().generate(12345)
	var roads: Array = (plan.get("roads", {}) as Dictionary).get("roads", [])
	if not T.require_true(self, roads.size() >= 3, "plan must generate at least three major roads"):
		return
	var sampler = load(SAMPLER_PATH).new(plan)
	for road_variant in roads:
		var road: Dictionary = road_variant
		var points: Array = road.get("points", [])
		if not T.require_true(self, points.size() >= 4, "every major road must have at least four points"):
			return
		for point_variant in points:
			var point: Vector3 = point_variant
			if not T.require_true(self, not sampler.water_mask_at(point.x, point.z), "major roads must not cross water"):
				return
	T.pass_and_quit(self)
