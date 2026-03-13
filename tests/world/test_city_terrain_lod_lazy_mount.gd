extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadSurfacePageProvider := preload("res://city_game/world/rendering/CityRoadSurfacePageProvider.gd")
const CityTerrainPageProvider := preload("res://city_game/world/rendering/CityTerrainPageProvider.gd")
const CityTerrainMeshBuilder := preload("res://city_game/world/rendering/CityTerrainMeshBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd for terrain LOD lazy-mount test")
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var surface_provider := CityRoadSurfacePageProvider.new()
	surface_provider.setup(config, world_data)
	var terrain_provider := CityTerrainPageProvider.new()
	terrain_provider.setup(config, world_data)

	var scene = chunk_scene_script.new()
	root.add_child(scene)
	await process_frame
	scene.setup(_make_chunk_payload(config, world_data, Vector2i(136, 136), surface_provider, terrain_provider))

	if not T.require_true(self, scene.has_method("get_terrain_lod_debug_stats"), "Chunk scene must expose terrain LOD debug stats for lazy-mount regression checks"):
		return

	var initial_stats: Dictionary = scene.get_terrain_lod_debug_stats()
	var initial_built_modes := _sorted_modes(initial_stats.get("built_mesh_modes", []))
	if not T.require_true(self, initial_built_modes.size() == 1, "Chunk mount must only materialize the current terrain LOD mesh during setup instead of eagerly building all modes"):
		return
	if not T.require_true(self, initial_built_modes[0] == "near", "Near-initial chunk setup must materialize the near terrain mesh first"):
		return

	scene.set_lod_mode("far")
	var far_stats: Dictionary = scene.get_terrain_lod_debug_stats()
	var far_built_modes := _sorted_modes(far_stats.get("built_mesh_modes", []))
	if not T.require_true(self, far_built_modes.size() == 2, "Switching chunk LOD after setup must materialize the requested terrain mesh on demand"):
		return
	if not T.require_true(self, far_built_modes[0] == "far" and far_built_modes[1] == "near", "Lazy terrain LOD mount must keep near mesh resident and add far mesh on demand"):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i, surface_provider: CityRoadSurfacePageProvider, terrain_provider: CityTerrainPageProvider) -> Dictionary:
	var payload := {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(config, chunk_key),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
		"surface_page_provider": surface_provider,
		"terrain_page_provider": terrain_provider,
		"initial_lod_mode": "near",
	}
	var surface_page_binding := surface_provider.resolve_chunk_surface_binding(payload, "full")
	var terrain_page_binding := terrain_provider.resolve_chunk_sample_binding(payload, 12)
	payload["surface_page_binding"] = surface_page_binding
	payload["terrain_page_binding"] = terrain_page_binding
	payload["terrain_lod_mesh_results"] = {
		"near": CityTerrainMeshBuilder.new().build_profiled_terrain_arrays_from_binding(
			float(payload.get("chunk_size_m", 256.0)),
			12,
			terrain_page_binding
		),
	}
	return payload

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

func _sorted_modes(modes_variant) -> Array[String]:
	var modes: Array[String] = []
	for mode_variant in modes_variant:
		modes.append(str(mode_variant))
	modes.sort()
	return modes
