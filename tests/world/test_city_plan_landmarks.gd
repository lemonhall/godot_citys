extends SceneTree

# v63 M4: three unique landmarks, the tallest >= 120m, every one roof-accessible.
# REQ-0034-005.

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
	var sampler = load(SAMPLER_PATH).new(plan)
	var landmarks: Array = sampler.landmarks()
	if not T.require_true(self, landmarks.size() >= 3, "city plan must expose at least three landmarks"):
		return
	var ids := {}
	var tallest := 0.0
	var skybridge_count := 0
	var core: Vector2 = (plan.get("history", {}) as Dictionary).get("core", Vector2.ZERO)
	for landmark_variant in landmarks:
		var landmark: Dictionary = landmark_variant
		var id := str(landmark.get("id", ""))
		if not T.require_true(self, id != "", "every landmark needs an id"):
			return
		if not T.require_true(self, not ids.has(id), "landmark ids must be unique (duplicate %s)" % id):
			return
		ids[id] = true
		tallest = maxf(tallest, float(landmark.get("height_m", 0.0)))
		if bool(landmark.get("skybridge", false)):
			skybridge_count += 1
		if not T.require_true(self, bool(landmark.get("roof_access", false)), "every landmark must expose roof access"):
			return
		var position: Vector2 = landmark.get("position", Vector2.ZERO)
		if not T.require_true(self, position.distance_to(core) <= 1500.0, "landmarks must stay within 1.5km of the core"):
			return
	if not T.require_true(self, tallest >= 120.0, "the tallest landmark must be at least 120m"):
		return
	if not T.require_true(self, skybridge_count >= 2, "the twin landmark pair must carry a skybridge"):
		return
	T.pass_and_quit(self)
