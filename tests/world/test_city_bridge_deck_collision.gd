extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	for chunk_x in range(134, 139):
		for chunk_y in range(134, 139):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			var chunk_scene = chunk_scene_script.new()
			root.add_child(chunk_scene)
			await process_frame
			chunk_scene.setup({
				"chunk_id": config.format_chunk_id(chunk_key),
				"chunk_key": chunk_key,
				"chunk_center": _chunk_center_from_key(config, chunk_key),
				"chunk_size_m": float(config.chunk_size_m),
				"chunk_seed": config.derive_seed("render_chunk", chunk_key),
				"road_graph": world_data.get("road_graph"),
				"world_seed": config.base_seed,
			})
			var stats: Dictionary = chunk_scene.get_renderer_stats()
			if not T.require_true(self, chunk_scene.has_method("get_road_collision_shape_count"), "Chunk scene must expose get_road_collision_shape_count()"):
				return
			if not T.require_true(self, chunk_scene.has_method("get_bridge_collision_shape_count"), "Chunk scene must expose get_bridge_collision_shape_count()"):
				return
			if not T.require_true(self, chunk_scene.has_method("get_bridge_min_clearance_m"), "Chunk scene must expose get_bridge_min_clearance_m()"):
				return
			if not T.require_true(self, chunk_scene.has_method("get_bridge_deck_thickness_m"), "Chunk scene must expose get_bridge_deck_thickness_m()"):
				return
			if not T.require_true(self, int(stats.get("bridge_count", 0)) == 0, "Flat-ground pivot must remove bridge chunks from renderer stats"):
				return
			if not T.require_true(self, int(chunk_scene.get_bridge_collision_shape_count()) == 0, "Flat-ground pivot must remove standalone bridge collision shapes"):
				return
			if not T.require_true(self, float(chunk_scene.get_bridge_min_clearance_m()) <= 0.001, "Flat-ground pivot must zero out bridge clearance stats"):
				return
			if not T.require_true(self, float(chunk_scene.get_bridge_deck_thickness_m()) <= 0.001, "Flat-ground pivot must zero out bridge deck thickness stats"):
				return
			chunk_scene.queue_free()

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
