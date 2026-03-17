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
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

	var profile: Dictionary = CityChunkProfileBuilder.build_profile({
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	})

	if not T.require_true(self, profile.has("build_profile_stats"), "Chunk profile must expose build_profile_stats for prepare breakdown analysis"):
		return

	var stats: Dictionary = profile.get("build_profile_stats", {})
	print("CITY_CHUNK_PREPARE_PROFILE %s" % JSON.stringify(stats))

	if not T.require_true(self, int(stats.get("total_usec", 0)) > 0, "Chunk profile breakdown must expose total prepare cost"):
		return
	if not T.require_true(self, int(stats.get("road_layout_usec", 0)) > 0, "Chunk profile breakdown must expose road layout cost"):
		return
	if not T.require_true(self, int(stats.get("buildings_usec", 0)) > 0, "Chunk profile breakdown must expose building synthesis cost"):
		return
	if not T.require_true(self, int(stats.get("building_candidate_usec", 0)) > 0, "Chunk profile breakdown must expose building candidate generation cost"):
		return
	if not T.require_true(self, int(stats.get("building_streetfront_candidate_usec", 0)) > 0, "Chunk profile breakdown must expose streetfront candidate generation cost"):
		return
	if not T.require_true(self, int(stats.get("building_infill_candidate_usec", 0)) > 0, "Chunk profile breakdown must expose infill candidate generation cost"):
		return
	if not T.require_true(self, int(stats.get("building_selection_usec", 0)) > 0, "Chunk profile breakdown must expose building selection cost"):
		return
	if not T.require_true(self, int(stats.get("building_inspection_payload_usec", 0)) > 0, "Chunk profile breakdown must expose building inspection payload cost"):
		return
	if not T.require_true(self, int(stats.get("terrain_relief_usec", 0)) > 0, "Chunk profile breakdown must expose terrain relief sampling cost"):
		return
	if not T.require_true(self, int(stats.get("signature_usec", 0)) > 0, "Chunk profile breakdown must expose signature assembly cost"):
		return

	T.pass_and_quit(self)
