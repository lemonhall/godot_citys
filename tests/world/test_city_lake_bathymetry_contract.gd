extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAKE_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeRegionRuntime.gd"
const MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"

const SHORE_SAMPLE := Vector3(2792.0, 0.0, 11478.0)
const MID_SAMPLE := Vector3(2838.0, 0.0, 11510.0)
const DEEP_SAMPLE := Vector3(2868.0, 0.0, 11536.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime_script := load(LAKE_RUNTIME_PATH)
	if not T.require_true(self, runtime_script != null, "Lake bathymetry contract requires CityLakeRegionRuntime.gd"):
		return
	var lake_runtime = runtime_script.new()
	if not T.require_true(self, lake_runtime != null and lake_runtime.has_method("load_from_manifest"), "Lake bathymetry contract requires load_from_manifest()"):
		return
	if not T.require_true(self, lake_runtime.has_method("sample_depth_at_world_position"), "Lake bathymetry contract requires sample_depth_at_world_position()"):
		return
	if not T.require_true(self, bool(lake_runtime.load_from_manifest(MANIFEST_PATH)), "Lake bathymetry contract must load the canonical manifest"):
		return

	var shore_depth: Dictionary = lake_runtime.sample_depth_at_world_position(SHORE_SAMPLE)
	var mid_depth: Dictionary = lake_runtime.sample_depth_at_world_position(MID_SAMPLE)
	var deep_depth: Dictionary = lake_runtime.sample_depth_at_world_position(DEEP_SAMPLE)

	if not T.require_true(self, bool(shore_depth.get("inside_region", false)), "Lake bathymetry contract requires the shoreline sample to be inside the authored lake polygon"):
		return
	if not T.require_true(self, bool(mid_depth.get("inside_region", false)), "Lake bathymetry contract requires the mid-depth sample to be inside the authored lake polygon"):
		return
	if not T.require_true(self, bool(deep_depth.get("inside_region", false)), "Lake bathymetry contract requires the deep-pocket sample to be inside the authored lake polygon"):
		return

	var shore_depth_m := float(shore_depth.get("depth_m", -1.0))
	var mid_depth_m := float(mid_depth.get("depth_m", -1.0))
	var deep_depth_m := float(deep_depth.get("depth_m", -1.0))
	if not T.require_true(self, shore_depth_m >= 0.0 and shore_depth_m <= 3.2, "Lake bathymetry contract must keep the shoreline shelf in the 0m..3m depth band"):
		return
	if not T.require_true(self, mid_depth_m >= 8.5 and mid_depth_m <= 11.5, "Lake bathymetry contract must expose a mean-depth band near 10m instead of a flat shallow puddle"):
		return
	if not T.require_true(self, deep_depth_m >= 14.5 and deep_depth_m <= 15.1, "Lake bathymetry contract must expose a deepest pocket near 15m instead of capping every point at the mean depth"):
		return
	if not T.require_true(self, shore_depth_m < mid_depth_m and mid_depth_m < deep_depth_m, "Lake bathymetry contract must distinguish shoreline, mean lake body and deep pocket depths"):
		return

	T.pass_and_quit(self)
