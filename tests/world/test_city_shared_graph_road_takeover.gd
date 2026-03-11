extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var total_shared_segments := 0
	var total_local_fallback_segments := 0

	for chunk_x in range(134, 139):
		for chunk_y in range(134, 139):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			var layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_id": config.format_chunk_id(chunk_key),
				"chunk_key": chunk_key,
				"chunk_center": _chunk_center_from_key(config, chunk_key),
				"chunk_size_m": float(config.chunk_size_m),
				"chunk_seed": config.derive_seed("render_chunk", chunk_key),
				"road_graph": world_data.get("road_graph"),
				"world_seed": config.base_seed,
			})

			if not T.require_true(self, layout.has("shared_graph_segment_count"), "Road layout must expose how many segments came from the shared road_graph"):
				return
			if not T.require_true(self, layout.has("local_fallback_segment_count"), "Road layout must expose whether any per-chunk fallback roads were added"):
				return

			var shared_count := int(layout.get("shared_graph_segment_count", -1))
			var fallback_count := int(layout.get("local_fallback_segment_count", -1))
			total_shared_segments += maxi(shared_count, 0)
			total_local_fallback_segments += maxi(fallback_count, 0)

			if shared_count > 0:
				if not T.require_true(self, shared_count == (layout.get("segments", []) as Array).size(), "Chunk road segments must come entirely from the shared road graph once v3 takeover is done"):
					return

	if not T.require_true(self, total_shared_segments > 0, "Center-city sample window must still render roads from the shared road graph"):
		return
	if not T.require_true(self, total_local_fallback_segments == 0, "V3 chunk roads must not append per-chunk local cell fallback segments anymore"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
