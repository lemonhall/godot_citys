extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAKE_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeRegionRuntime.gd"
const BASIN_CARRIER_BUILDER_PATH := "res://city_game/world/rendering/CityLakeBasinCarrierBuilder.gd"
const MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"
const MID_SAMPLE := Vector3(2838.0, 0.0, 11510.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime_script := load(LAKE_RUNTIME_PATH)
	var builder_script := load(BASIN_CARRIER_BUILDER_PATH)
	if not T.require_true(self, runtime_script != null, "Lake basin carrier contract requires CityLakeRegionRuntime.gd"):
		return
	if not T.require_true(self, builder_script != null, "Lake basin carrier contract requires CityLakeBasinCarrierBuilder.gd"):
		return

	var lake_runtime = runtime_script.new()
	if not T.require_true(self, lake_runtime != null and lake_runtime.has_method("load_from_manifest"), "Lake basin carrier contract requires load_from_manifest()"):
		return
	if not T.require_true(self, lake_runtime.has_method("get_runtime_contract"), "Lake basin carrier contract requires get_runtime_contract()"):
		return
	if not T.require_true(self, lake_runtime.has_method("sample_depth_at_world_position"), "Lake basin carrier contract requires sample_depth_at_world_position()"):
		return
	if not T.require_true(self, bool(lake_runtime.load_from_manifest(MANIFEST_PATH)), "Lake basin carrier contract must load the canonical lake manifest"):
		return

	var builder = builder_script.new()
	if not T.require_true(self, builder != null and builder.has_method("build_ground_body"), "Lake basin carrier contract requires build_ground_body()"):
		return

	var scene_root := Node3D.new()
	scene_root.name = "LakeCarrierProbe"
	root.add_child(scene_root)
	var ground_body: Variant = builder.build_ground_body(lake_runtime.get_runtime_contract())
	if not T.require_true(self, ground_body != null, "Lake basin carrier contract must build a standalone ground carrier from the shared lake contract"):
		return
	scene_root.add_child(ground_body)
	await process_frame
	await physics_frame

	var expected_sample: Dictionary = lake_runtime.sample_depth_at_world_position(MID_SAMPLE)
	if not T.require_true(self, bool(expected_sample.get("inside_region", false)), "Lake basin carrier contract requires the lake midpoint sample to stay inside the authored region"):
		return
	var space_state: PhysicsDirectSpaceState3D = scene_root.get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(
		MID_SAMPLE + Vector3.UP * 12.0,
		MID_SAMPLE + Vector3.DOWN * 24.0
	)
	ray_query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(ray_query)
	if not T.require_true(self, not hit.is_empty(), "Lake basin carrier contract must expose collision at the carved lake floor instead of leaving the basin as an empty visual shell"):
		return

	var hit_position: Vector3 = hit.get("position", MID_SAMPLE)
	var expected_floor_y := float(expected_sample.get("floor_y_m", 999.0))
	if not T.require_true(
		self,
		absf(hit_position.y - expected_floor_y) <= 0.85,
		"Lake basin carrier contract must align standalone collision with the shared bathymetry floor instead of keeping a flat y=0 carrier"
	):
		return
	if not T.require_true(
		self,
		hit_position.y <= float(expected_sample.get("water_level_y_m", 0.0)) - 6.0,
		"Lake basin carrier contract must actually carve the basin well below the waterline instead of letting the midpoint keep shoreline height"
	):
		return

	T.pass_and_quit(self)
