extends SceneTree

# v63 M1: terrain + water contract.
# REQ-0034-002: river length/width, water coverage in the 1km slice, and
# height continuity outside the banks.

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
	var terrain: Dictionary = plan.get("terrain", {})
	var river: Dictionary = terrain.get("river", {})
	var points: Array = river.get("points", [])
	if not T.require_true(self, points.size() >= 2, "river must have at least two points"):
		return
	var length := 0.0
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		length += (b - a).length()
	if not T.require_true(self, length >= 3000.0, "river must be at least 3000m long"):
		return
	var width := float(river.get("width_m", 0.0))
	if not T.require_true(self, width >= 40.0 and width <= 120.0, "river width must stay within 40..120m"):
		return

	var sampler_script = load(SAMPLER_PATH)
	if not T.require_true(self, sampler_script != null, "CityPlanSampler must exist"):
		return
	var sampler = sampler_script.new(plan)
	var wet := 0
	var total := 0
	for x_index in range(-10, 11):
		for z_index in range(-10, 11):
			total += 1
			if sampler.water_mask_at(float(x_index) * 50.0, float(z_index) * 50.0):
				wet += 1
	var coverage := float(wet) / float(maxi(total, 1))
	if not T.require_true(self, coverage >= 0.02, "water must cover at least 2%% of the 1km slice (got %.3f)" % coverage):
		return

	for x_index in range(-20, 20):
		var x := float(x_index) * 20.0
		var h0: float = sampler.height_at(x, 0.0)
		var h1: float = sampler.height_at(x + 1.0, 0.0)
		if not T.require_true(self, absf(h1 - h0) <= 2.0, "height must be continuous outside the bank"):
			return
	T.pass_and_quit(self)
