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
	var scene_a = chunk_scene_script.new()
	var scene_b = chunk_scene_script.new()
	var scene_c = chunk_scene_script.new()
	root.add_child(scene_a)
	root.add_child(scene_b)
	root.add_child(scene_c)
	await process_frame

	var chunk_key := Vector2i(136, 136)
	scene_a.setup(_make_chunk_payload(config, world_data, chunk_key))
	scene_b.setup(_make_chunk_payload(config, world_data, chunk_key + Vector2i.RIGHT))
	scene_c.setup(_make_chunk_payload(config, world_data, chunk_key + Vector2i.DOWN))

	if not T.require_true(self, scene_a.has_method("get_road_boundary_connectors"), "Chunk scene must expose get_road_boundary_connectors()"):
		return

	var connectors_a: Dictionary = scene_a.get_road_boundary_connectors()
	var connectors_b: Dictionary = scene_b.get_road_boundary_connectors()
	var connectors_c: Dictionary = scene_c.get_road_boundary_connectors()

	if not T.require_true(self, _match_connectors(connectors_a.get("east", []), connectors_b.get("west", [])), "Road connectors must match across east/west chunk boundaries"):
		return
	if not T.require_true(self, _match_connectors(connectors_a.get("south", []), connectors_c.get("north", [])), "Road connectors must match across north/south chunk boundaries"):
		return

	var stats: Dictionary = scene_a.get_renderer_stats()
	if not T.require_true(self, int(stats.get("road_segment_count", 0)) > 0, "Chunk scene must render non-zero road segments"):
		return
	if not T.require_true(self, int(stats.get("curved_road_segment_count", 0)) > 0, "Chunk scene roads must include curved segments, not only straight orthogonal strips"):
		return
	if not T.require_true(self, str(stats.get("road_mesh_mode", "")) == "ribbon", "Chunk roads must use continuous ribbon mesh rendering, not box-by-box strips"):
		return
	if not T.require_true(self, int(stats.get("non_axis_road_segment_count", 0)) > 0, "Chunk roads must include clearly non-orthogonal directions to reduce grid feel"):
		return

	var bridge_count := 0
	for sample_key in [
		Vector2i(135, 135),
		Vector2i(136, 136),
		Vector2i(137, 136),
	]:
		var sample_scene = chunk_scene_script.new()
		root.add_child(sample_scene)
		await process_frame
		sample_scene.setup(_make_chunk_payload(config, world_data, sample_key))
		bridge_count += int(sample_scene.get_renderer_stats().get("bridge_count", 0))
		sample_scene.queue_free()
	if not T.require_true(self, bridge_count > 0, "Road sampling near the city center must include at least some bridge/overpass placeholders"):
		return

	scene_a.queue_free()
	scene_b.queue_free()
	scene_c.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(config, chunk_key),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	}

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

func _match_connectors(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if absf(float(a[index]) - float(b[index])) > 0.05:
			return false
	return true
