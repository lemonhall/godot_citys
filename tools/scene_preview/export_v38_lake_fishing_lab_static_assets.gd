extends SceneTree

const CityTerrainRegionFeatureRegistry := preload("res://city_game/world/features/CityTerrainRegionFeatureRegistry.gd")
const CityTerrainRegionFeatureRuntime := preload("res://city_game/world/features/CityTerrainRegionFeatureRuntime.gd")
const CityLakeBasinCarrierBuilder := preload("res://city_game/world/rendering/CityLakeBasinCarrierBuilder.gd")

const TERRAIN_REGION_REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"
const LAB_WORLD_ORIGIN := Vector3(2834.0, 0.0, 11546.0)
const OUTPUT_ROOT := "res://city_game/scenes/labs/generated"
const GROUND_MESH_PATH := OUTPUT_ROOT + "/lake_fishing_lab_ground_mesh.res"
const GROUND_SHAPE_PATH := OUTPUT_ROOT + "/lake_fishing_lab_ground_shape.res"
const WATER_MESH_PATH := OUTPUT_ROOT + "/lake_fishing_lab_water_surface_mesh.res"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var lake_contract := _load_lake_contract()
	if lake_contract.is_empty():
		_fail("missing_lake_contract")
		return

	var ground_body := CityLakeBasinCarrierBuilder.build_ground_body(lake_contract)
	if ground_body == null:
		_fail("ground_body_build_failed")
		return
	var ground_mesh_instance := ground_body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var ground_collision_shape := ground_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if ground_mesh_instance == null or ground_mesh_instance.mesh == null:
		_fail("ground_mesh_missing")
		return
	if ground_collision_shape == null or ground_collision_shape.shape == null:
		_fail("ground_shape_missing")
		return

	var water_surface_node := CityLakeBasinCarrierBuilder.build_water_surface_node({
		"region_id": str(lake_contract.get("region_id", "")),
		"water_level_y_m": float(lake_contract.get("water_level_y_m", 0.0)),
		"polygon_world_points": (lake_contract.get("polygon_world_points", []) as Array).duplicate(true),
	}, LAB_WORLD_ORIGIN)
	if water_surface_node == null or water_surface_node.mesh == null:
		_fail("water_mesh_missing")
		return

	var output_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	if output_dir_error != OK and output_dir_error != ERR_ALREADY_EXISTS:
		_fail("output_dir_create_failed:%d" % output_dir_error)
		return

	if not _save_resource(ground_mesh_instance.mesh, GROUND_MESH_PATH):
		return
	if not _save_resource(ground_collision_shape.shape, GROUND_SHAPE_PATH):
		return
	if not _save_resource(water_surface_node.mesh, WATER_MESH_PATH):
		return

	var ground_body_position := ground_body.position
	var ground_body_local_position := ground_body_position - LAB_WORLD_ORIGIN
	ground_body.free()
	water_surface_node.free()

	print("EXPORT_OK")
	print("ground_body_position=%s" % [str(ground_body_position)])
	print("lab_world_origin=%s" % [str(LAB_WORLD_ORIGIN)])
	print("ground_body_local_position=%s" % [str(ground_body_local_position)])
	print("ground_mesh_path=%s" % GROUND_MESH_PATH)
	print("ground_shape_path=%s" % GROUND_SHAPE_PATH)
	print("water_mesh_path=%s" % WATER_MESH_PATH)
	quit(0)

func _load_lake_contract() -> Dictionary:
	var registry := CityTerrainRegionFeatureRegistry.new()
	registry.configure(TERRAIN_REGION_REGISTRY_PATH, [TERRAIN_REGION_REGISTRY_PATH])
	var runtime := CityTerrainRegionFeatureRuntime.new()
	runtime.configure(registry.load_registry())
	if runtime == null or not runtime.has_method("get_lake_runtime"):
		return {}
	var lake_runtime = runtime.get_lake_runtime(REGION_ID)
	if lake_runtime == null or not lake_runtime.has_method("get_runtime_contract"):
		return {}
	return lake_runtime.get_runtime_contract()

func _save_resource(resource: Resource, path: String) -> bool:
	var save_error := ResourceSaver.save(resource, path)
	if save_error != OK:
		_fail("save_failed:%s:%d" % [path, save_error])
		return false
	return true

func _fail(reason: String) -> void:
	push_error(reason)
	print("EXPORT_FAIL:%s" % reason)
	quit(1)
