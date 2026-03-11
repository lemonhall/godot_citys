extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")

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

	var texture_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, float(config.chunk_size_m))
	if not T.require_true(self, texture_result.has("mask_profile_stats"), "Road mask build must expose mask_profile_stats for runtime hotspot analysis"):
		return

	var stats: Dictionary = texture_result.get("mask_profile_stats", {})
	print("CITY_ROAD_MASK_PROFILE %s" % JSON.stringify(stats))

	if not T.require_true(self, int(stats.get("surface_segment_count", 0)) > 0, "Road mask profile must include painted surface segment counts"):
		return
	if not T.require_true(self, int(stats.get("paint_usec", 0)) > 0, "Road mask profile must include CPU paint cost"):
		return
	if not T.require_true(self, int(stats.get("image_usec", 0)) >= 0, "Road mask profile must include Image assembly cost"):
		return
	if not T.require_true(self, int(stats.get("texture_usec", 0)) > 0, "Road mask profile must include texture upload cost"):
		return
	if not T.require_true(self, int(stats.get("total_usec", 0)) >= int(stats.get("paint_usec", 0)), "Road mask total cost must cover paint cost"):
		return

	T.pass_and_quit(self)
