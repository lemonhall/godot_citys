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
	var found_surface_road_chunk := false

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
			if int(stats.get("road_segment_count", 0)) <= int(stats.get("bridge_count", 0)):
				chunk_scene.queue_free()
				continue

			found_surface_road_chunk = true
			var ground_mesh := chunk_scene.get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
			if not T.require_true(self, ground_mesh != null, "Ground body must expose MeshInstance3D for road overlay shading"):
				return
			if not T.require_true(self, ground_mesh.material_override is ShaderMaterial, "Surface roads must be rendered by a terrain ShaderMaterial overlay"):
				return

			var material := ground_mesh.material_override as ShaderMaterial
			if not T.require_true(self, material.get_shader_parameter("road_mask_texture") != null, "Terrain road overlay must bind a road mask texture"):
				return
			if not T.require_true(self, material.get_shader_parameter("stripe_mask_texture") != null, "Terrain road overlay must bind a stripe mask texture"):
				return
			chunk_scene.queue_free()
			break
		if found_surface_road_chunk:
			break

	if not T.require_true(self, found_surface_road_chunk, "Center-city sample window must include at least one chunk with non-bridge surface roads"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
