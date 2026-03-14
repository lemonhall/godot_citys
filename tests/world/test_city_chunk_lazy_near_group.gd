extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var scene := CityChunkScene.new()
	root.add_child(scene)
	await process_frame
	scene.setup(_make_chunk_payload(config, world_data, chunk_key, CityChunkScene.LOD_FAR))

	if not T.require_true(self, scene.get_node_or_null("NearGroup") == null, "Far-initial chunk setup must defer NearGroup construction until the chunk is promoted to near LOD"):
		return
	if not T.require_true(self, scene.get_building_collision_shape_count() == 0, "Far-initial chunk setup must not prebuild nearfield building collisions"):
		return

	scene.set_lod_mode(CityChunkScene.LOD_NEAR)
	if not T.require_true(self, scene.get_node_or_null("NearGroup") != null, "Promoting a chunk to near LOD must lazily build NearGroup on demand"):
		return
	if not T.require_true(self, scene.get_building_collision_shape_count() > 0, "Near LOD must restore building collision shapes after lazy construction"):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i, initial_lod_mode: String) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3(
			bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
			0.0,
			bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
		),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
		"initial_lod_mode": initial_lod_mode,
	}
