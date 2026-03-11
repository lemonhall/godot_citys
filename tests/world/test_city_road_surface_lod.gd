extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityRoadSurfaceCache := preload("res://city_game/world/rendering/CityRoadSurfaceCache.gd")

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
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	})
	var cache := CityRoadSurfaceCache.new()
	cache.clear_cache_for_profile(profile, float(config.chunk_size_m), "full")
	cache.clear_cache_for_profile(profile, float(config.chunk_size_m), "coarse")

	var coarse_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, float(config.chunk_size_m), "coarse")
	var full_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, float(config.chunk_size_m), "full")
	var coarse_stats: Dictionary = coarse_result.get("mask_profile_stats", {})
	var full_stats: Dictionary = full_result.get("mask_profile_stats", {})

	if not T.require_true(self, str(coarse_stats.get("detail_mode", "")) == "coarse", "Coarse road surface build must expose coarse detail mode"):
		return
	if not T.require_true(self, not bool(coarse_stats.get("stripe_paint_enabled", true)), "Coarse road surface build must skip stripe paint"):
		return
	if not T.require_true(self, str(full_stats.get("detail_mode", "")) == "full", "Full road surface build must expose full detail mode"):
		return
	if not T.require_true(self, bool(full_stats.get("stripe_paint_enabled", false)), "Full road surface build must keep stripe paint enabled"):
		return
	if not T.require_true(self, str(coarse_stats.get("cache_signature", "")) != str(full_stats.get("cache_signature", "")), "Coarse and full road surface caches must use different signatures"):
		return
	T.pass_and_quit(self)
