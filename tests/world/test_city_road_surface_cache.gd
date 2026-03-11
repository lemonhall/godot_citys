extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var cache_script := load("res://city_game/world/rendering/CityRoadSurfaceCache.gd")
	if not T.require_true(self, cache_script != null, "Road surface cache script must exist for v4 M1"):
		return

	var cache = cache_script.new()
	if not T.require_true(self, cache.has_method("clear_cache_for_profile"), "Road surface cache must expose clear_cache_for_profile() for deterministic tests"):
		return

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
	var chunk_size_m := float(config.chunk_size_m)
	cache.clear_cache_for_profile(profile, chunk_size_m)

	var first_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, chunk_size_m)
	var first_stats: Dictionary = first_result.get("mask_profile_stats", {})
	if not T.require_true(self, first_stats.has("cache_hit"), "Road mask profile must expose cache_hit"):
		return
	if not T.require_true(self, not bool(first_stats.get("cache_hit", true)), "First road surface build after cache clear must be a cache miss"):
		return
	if not T.require_true(self, int(first_stats.get("paint_usec", 0)) > 0, "Cache miss path must perform CPU paint work"):
		return

	var second_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, chunk_size_m)
	var second_stats: Dictionary = second_result.get("mask_profile_stats", {})
	if not T.require_true(self, bool(second_stats.get("cache_hit", false)), "Second road surface build for same static chunk must hit cache"):
		return
	if not T.require_true(self, int(second_stats.get("paint_usec", -1)) == 0, "Cache hit path must skip CPU paint work"):
		return
	if not T.require_true(self, int(second_stats.get("cache_load_usec", 0)) > 0, "Cache hit path must expose cache load timing"):
		return
	if not T.require_true(self, str(second_stats.get("cache_path", "")) != "", "Road surface cache stats must expose cache path"):
		return

	T.pass_and_quit(self)
