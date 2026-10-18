extends SceneTree

# v63 M4: parcel era must follow the district grammar.
# REQ-0034-005.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const PARCEL_PATH := "res://city_game/world/generation/plan/CityParcelPlan.gd"
const GRAMMAR_PATH := "res://city_game/world/generation/plan/CityParcelGrammar.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	var parcel_script = load(PARCEL_PATH)
	var grammar_script = load(GRAMMAR_PATH)
	if not T.require_true(self, generator_script != null and parcel_script != null and grammar_script != null, "plan modules must exist"):
		return
	var plan: Dictionary = generator_script.new().generate(12345)
	var parcels: Array = (parcel_script.new().build(plan, 5000.0) as Dictionary).get("parcels", [])
	if not T.require_true(self, parcels.size() >= 100, "need at least 100 parcels to check eras"):
		return
	var matched := 0
	var eras := {}
	for parcel_variant in parcels:
		var parcel: Dictionary = parcel_variant
		var district := str(parcel.get("district", ""))
		var expected := str(grammar_script.era_for_district(district))
		var era := str(parcel.get("era", ""))
		eras[era] = true
		if era == expected:
			matched += 1
	var ratio := float(matched) / float(parcels.size())
	if not T.require_true(self, ratio >= 0.95, "at least 95%% of parcels must match the district era (got %.3f)" % ratio):
		return
	if not T.require_true(self, eras.size() >= 4, "the plan must exercise at least four building eras (got %d)" % eras.size()):
		return
	T.pass_and_quit(self)
