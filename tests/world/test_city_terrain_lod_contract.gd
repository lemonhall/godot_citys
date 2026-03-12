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
		T.fail_and_quit(self, "Missing CityChunkScene.gd for terrain LOD contract")
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

	if not T.require_true(self, scene.has_method("get_terrain_lod_contract"), "Chunk scene must expose get_terrain_lod_contract() for v5 M4"):
		return

	var contract: Dictionary = scene.get_terrain_lod_contract()
	var modes: Dictionary = contract.get("modes", {})
	if not T.require_true(self, modes.has("near") and modes.has("mid") and modes.has("far"), "Terrain LOD contract must expose near/mid/far modes"):
		return
	if not T.require_true(self, int((modes.get("near", {}) as Dictionary).get("grid_steps", 0)) > int((modes.get("mid", {}) as Dictionary).get("grid_steps", 0)), "Near terrain must keep a finer grid than mid terrain"):
		return
	if not T.require_true(self, int((modes.get("mid", {}) as Dictionary).get("grid_steps", 0)) > int((modes.get("far", {}) as Dictionary).get("grid_steps", 0)), "Mid terrain must keep a finer grid than far terrain"):
		return
	if not T.require_true(self, int((modes.get("near", {}) as Dictionary).get("vertex_count", 0)) > int((modes.get("far", {}) as Dictionary).get("vertex_count", 0)), "Terrain LOD contract must expose a lower vertex count in far mode"):
		return

	scene.set_lod_mode("far")
	contract = scene.get_terrain_lod_contract()
	if not T.require_true(self, str(contract.get("current_mode", "")) == "far", "Terrain LOD contract must track the currently active mode"):
		return
	if not T.require_true(self, int(contract.get("current_grid_steps", 0)) == int((contract.get("modes", {}) as Dictionary).get("far", {}).get("grid_steps", 0)), "Switching chunk LOD to far must switch terrain grid resolution as well"):
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
