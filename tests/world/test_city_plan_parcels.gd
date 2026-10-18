extends SceneTree

# v63 M3: parcels follow district grammar, keep the street wall, and leave
# connected alleys.
# REQ-0034-004.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const PARCEL_PATH := "res://city_game/world/generation/plan/CityParcelPlan.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	if not T.require_true(self, generator_script != null, "CityPlanGenerator must exist"):
		return
	var parcel_script = load(PARCEL_PATH)
	if not T.require_true(self, parcel_script != null, "CityParcelPlan must exist"):
		return
	var plan: Dictionary = generator_script.new().generate(12345)
	var result: Dictionary = parcel_script.new().build(plan, 5000.0)
	var parcels: Array = result.get("parcels", [])
	var alleys: Array = result.get("alleys", [])
	if not T.require_true(self, parcels.size() >= 100, "parcel layer must produce at least 100 street-front parcels (got %d)" % parcels.size()):
		return
	var widths := {}
	var frontage_ok := 0
	var oldtown_courtyards := 0
	var oldtown_parcels := 0
	for parcel_variant in parcels:
		var parcel: Dictionary = parcel_variant
		var district := str(parcel.get("district", ""))
		widths[district] = float(widths.get(district, 0.0)) + float(parcel.get("width_m", 0.0))
		if float(parcel.get("frontage_m", 99.0)) <= 8.0:
			frontage_ok += 1
		if district == "oldtown":
			oldtown_parcels += 1
			if bool(parcel.get("has_courtyard", false)):
				oldtown_courtyards += 1
	var average := {}
	for district in widths.keys():
		var count := 0
		for parcel_variant in parcels:
			if str((parcel_variant as Dictionary).get("district", "")) == district:
				count += 1
		average[district] = float(widths[district]) / float(maxi(count, 1))
	if not T.require_true(self, average.has("oldtown") and average.has("downtown"), "parcels must exist in both old town and downtown"):
		return
	if not T.require_true(self, float(average["oldtown"]) <= 12.0, "old-town average parcel width must be <= 12m (got %.1f)" % float(average["oldtown"])):
		return
	if not T.require_true(self, float(average["downtown"]) >= 24.0, "downtown average parcel width must be >= 24m (got %.1f)" % float(average["downtown"])):
		return
	var frontage_ratio := float(frontage_ok) / float(parcels.size())
	if not T.require_true(self, frontage_ratio >= 0.70, "at least 70%% of parcels must keep an 8m street wall (got %.3f)" % frontage_ratio):
		return
	if not T.require_true(self, alleys.size() >= 20, "parcel layer must leave at least 20 alleys (got %d)" % alleys.size()):
		return
	for alley_variant in alleys:
		var alley: Dictionary = alley_variant
		if not T.require_true(self, float(alley.get("width_m", 0.0)) >= 4.0, "alleys must be at least 4m wide"):
			return
		if not T.require_true(self, bool(alley.get("connected_to_road", false)), "alleys must connect to the road"):
			return
	var courtyard_ratio := float(oldtown_courtyards) / float(maxi(oldtown_parcels, 1))
	if not T.require_true(self, courtyard_ratio >= 0.30, "old town must keep at least 30%% courtyard parcels (got %.3f)" % courtyard_ratio):
		return
	T.pass_and_quit(self)
