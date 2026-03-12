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
		T.fail_and_quit(self, "Missing CityChunkScene.gd for terrain-road continuity")
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

	if not T.require_true(self, scene.has_method("get_terrain_lod_contract"), "Chunk scene must expose terrain LOD contract for continuity checks"):
		return

	var near_contract: Dictionary = scene.get_terrain_lod_contract()
	var near_stats: Dictionary = scene.get_renderer_stats()
	var near_aabb := _ground_mesh_aabb(scene)
	scene.set_lod_mode("far")
	var far_contract: Dictionary = scene.get_terrain_lod_contract()
	var far_stats: Dictionary = scene.get_renderer_stats()
	var far_aabb := _ground_mesh_aabb(scene)

	if not T.require_true(self, int(near_contract.get("current_vertex_count", 0)) > int(far_contract.get("current_vertex_count", 0)), "Terrain continuity test requires a real lower-detail far mesh, not a cosmetic-only LOD flag"):
		return
	if not T.require_true(self, near_stats.get("surface_page_key", Vector2i.ZERO) == far_stats.get("surface_page_key", Vector2i.ZERO), "Road surface page key must stay stable across terrain LOD switches"):
		return
	if not T.require_true(self, near_stats.get("terrain_page_key", Vector2i.ZERO) == far_stats.get("terrain_page_key", Vector2i.ZERO), "Terrain page key must stay stable across terrain LOD switches"):
		return
	if not T.require_true(self, int(far_stats.get("road_segment_count", 0)) > 0, "Road overlay continuity requires actual road coverage to remain present in far mode"):
		return
	if not T.require_true(self, absf(near_aabb.size.x - far_aabb.size.x) <= 0.1, "Terrain LOD switches must preserve chunk X coverage and not shrink the ground footprint"):
		return
	if not T.require_true(self, absf(near_aabb.size.z - far_aabb.size.z) <= 0.1, "Terrain LOD switches must preserve chunk Z coverage and not shrink the ground footprint"):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _ground_mesh_aabb(scene: Node) -> AABB:
	var mesh_instance := scene.get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return AABB()
	return mesh_instance.mesh.get_aabb()

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
