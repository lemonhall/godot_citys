extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadSurfacePageProvider := preload("res://city_game/world/rendering/CityRoadSurfacePageProvider.gd")
const CityTerrainPageProvider := preload("res://city_game/world/rendering/CityTerrainPageProvider.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd for terrain LOD noop test")
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

	if not T.require_true(self, scene.has_method("get_terrain_lod_debug_stats"), "Chunk scene must expose terrain LOD debug stats for noop regression checks"):
		return

	var before_stats: Dictionary = scene.get_terrain_lod_debug_stats()
	scene.set_lod_mode(scene.get_current_lod_mode())
	var after_stats: Dictionary = scene.get_terrain_lod_debug_stats()

	if not T.require_true(self, int(after_stats.get("mesh_apply_count", 0)) == int(before_stats.get("mesh_apply_count", 0)), "Reapplying the same terrain LOD mode must not remount the same mesh every frame"):
		return
	if not T.require_true(self, int(after_stats.get("collision_apply_count", 0)) == int(before_stats.get("collision_apply_count", 0)), "Reapplying the same terrain LOD mode must not rebuild collision every frame"):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i, surface_provider: CityRoadSurfacePageProvider, terrain_provider: CityTerrainPageProvider) -> Dictionary:
	return {
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

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
