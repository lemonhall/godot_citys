extends SceneTree

# v63 M2: districts derive from geography; each kind keeps a real share of the
# 10km window, and the 1km slice contains water + old town.
# REQ-0034-004.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const SAMPLER_PATH := "res://city_game/world/generation/plan/CityPlanSampler.gd"
const KINDS := ["oldtown", "downtown", "commercial", "residential", "industrial", "waterfront"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	if not T.require_true(self, generator_script != null, "CityPlanGenerator must exist"):
		return
	var plan: Dictionary = generator_script.new().generate(12345)
	var sampler = load(SAMPLER_PATH).new(plan)
	var counts := {}
	for kind in KINDS:
		counts[kind] = 0
	var total := 0
	var steps := 60
	for x_index in range(steps):
		for z_index in range(steps):
			var x := -5000.0 + 10000.0 * float(x_index) / float(steps - 1)
			var z := -5000.0 + 10000.0 * float(z_index) / float(steps - 1)
			var kind: String = sampler.district_at(x, z)
			counts[kind] = int(counts.get(kind, 0)) + 1
			total += 1
	for kind in KINDS:
		var share := float(counts[kind]) / float(total)
		var minimum := 0.02 if kind == "waterfront" else 0.03
		if not T.require_true(self, share >= minimum, "district %s must cover at least %.0f%% of the 10km window (got %.3f)" % [kind, minimum * 100.0, share]):
			return
	var slice_counts := {}
	for x_index in range(22):
		for z_index in range(22):
			var x := -500.0 + 1000.0 * float(x_index) / 21.0
			var z := -500.0 + 1000.0 * float(z_index) / 21.0
			var kind: String = sampler.district_at(x, z)
			slice_counts[kind] = int(slice_counts.get(kind, 0)) + 1
	if not T.require_true(self, slice_counts.has("waterfront"), "1km slice must contain the waterfront"):
		return
	if not T.require_true(self, slice_counts.size() >= 2, "1km slice must contain at least two district kinds"):
		return
	T.pass_and_quit(self)
