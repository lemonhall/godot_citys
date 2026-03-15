extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var payload := {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(config, chunk_key),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": config.base_seed,
		"road_graph": world_data.get("road_graph"),
	}
	var profile: Dictionary = CityChunkProfileBuilder.build_profile(payload)
	if not T.require_true(self, profile.has("building_layout_stats"), "Chunk profile must expose building_layout_stats for v13 frontage validation"):
		return
	var layout_stats: Dictionary = profile.get("building_layout_stats", {})
	if not T.require_true(self, int(layout_stats.get("streetfront_candidate_count", 0)) > 0, "v13 building layout must generate streetfront candidates from road geometry"):
		return
	if not T.require_true(self, float(layout_stats.get("streetfront_building_ratio", -1.0)) >= 0.7, "v13 building layout must place most buildings from streetfront candidates"):
		return
	if not T.require_true(self, float(layout_stats.get("road_aligned_building_ratio", -1.0)) >= 0.7, "v13 building layout must keep most buildings aligned to nearby street directions"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
