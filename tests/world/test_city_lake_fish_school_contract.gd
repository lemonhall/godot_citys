extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAKE_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeRegionRuntime.gd"
const FISH_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeFishSchoolRuntime.gd"
const MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var lake_runtime_script := load(LAKE_RUNTIME_PATH)
	var fish_runtime_script := load(FISH_RUNTIME_PATH)
	if not T.require_true(self, lake_runtime_script != null, "Lake fish school contract requires CityLakeRegionRuntime.gd"):
		return
	if not T.require_true(self, fish_runtime_script != null, "Lake fish school contract requires CityLakeFishSchoolRuntime.gd"):
		return

	var lake_runtime = lake_runtime_script.new()
	if not T.require_true(self, bool(lake_runtime.load_from_manifest(MANIFEST_PATH)), "Lake fish school contract must load the canonical manifest"):
		return
	var fish_runtime = fish_runtime_script.new()
	if not T.require_true(self, fish_runtime != null and fish_runtime.has_method("configure"), "Lake fish school contract requires configure()"):
		return
	if not T.require_true(self, fish_runtime.has_method("get_school_summaries_for_region"), "Lake fish school contract requires get_school_summaries_for_region()"):
		return
	fish_runtime.configure([lake_runtime])

	var schools: Array = fish_runtime.get_school_summaries_for_region(REGION_ID)
	if not T.require_true(self, schools.size() >= 2, "Lake fish school contract must expose a non-empty deterministic school summary set"):
		return
	for school_variant in schools:
		if not (school_variant is Dictionary):
			continue
		var school: Dictionary = school_variant
		var school_world_position: Vector3 = school.get("world_position", Vector3.ZERO)
		var depth_sample: Dictionary = lake_runtime.sample_depth_at_world_position(school_world_position)
		if not T.require_true(self, bool(depth_sample.get("inside_region", false)), "Lake fish schools must stay inside the authored lake polygon"):
			return
		var water_level_y_m := float(depth_sample.get("water_level_y_m", 0.0))
		var floor_y_m := float(depth_sample.get("floor_y_m", 0.0))
		if not T.require_true(self, school_world_position.y <= water_level_y_m - 0.2, "Lake fish schools must sit below the stable waterline instead of floating above the surface"):
			return
		if not T.require_true(self, school_world_position.y >= floor_y_m + 0.35, "Lake fish schools must stay above the carved lake floor instead of spawning underground"):
			return

	T.pass_and_quit(self)
