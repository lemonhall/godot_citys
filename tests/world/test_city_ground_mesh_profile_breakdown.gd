extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

const TERRAIN_MESH_BUILDER_PATH := "res://city_game/world/rendering/CityTerrainMeshBuilder.gd"
const TERRAIN_GRID_STEPS := 12

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile: Dictionary = CityChunkProfileBuilder.build_profile(chunk_payload)
	var terrain_mesh_builder_script := load(TERRAIN_MESH_BUILDER_PATH)
	if not T.require_true(self, terrain_mesh_builder_script != null, "CityTerrainMeshBuilder.gd must exist for shared terrain mesh profiling"):
		return
	var terrain_mesh_builder = terrain_mesh_builder_script.new()
	var build_result: Dictionary = terrain_mesh_builder.build_profiled_terrain_mesh(
		float(chunk_payload.get("chunk_size_m", 256.0)),
		chunk_payload,
		profile,
		TERRAIN_GRID_STEPS
	)
	var report: Dictionary = build_result.get("sample_stats", {})
	print("CITY_GROUND_MESH_PROFILE %s" % JSON.stringify(report))

	if not T.require_true(self, int(report.get("current_vertex_sample_count", 0)) == 169, "Terrain mesh builder must sample each unique vertex only once for a 12-step grid"):
		return
	if not T.require_true(self, float(report.get("duplication_ratio", 999.0)) <= 1.2, "Terrain mesh builder duplication ratio must stay at or below 1.2 after shared template reuse"):
		return

	T.pass_and_quit(self)

func _build_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	}
