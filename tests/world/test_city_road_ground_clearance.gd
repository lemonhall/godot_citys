extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")

const MIN_ROAD_MASK_STRENGTH := 0.55

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var chunk_data := _make_chunk_payload(config, world_data, chunk_key)
	var profile: Dictionary = CityChunkProfileBuilder.build_profile(chunk_data)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var overlay_textures: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, chunk_size_m)
	var road_texture := overlay_textures.get("road_mask_texture") as Texture2D
	var road_image := road_texture.get_image()
	var weakest_mask_strength := 1.0
	var sampled_point_count := 0

	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		if bool(segment_dict.get("bridge", false)):
			continue
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			for ratio in [0.15, 0.35, 0.5, 0.65, 0.85]:
				var road_point := a.lerp(b, float(ratio))
				var mask_strength := _sample_mask_strength(road_image, road_point, chunk_size_m)
				weakest_mask_strength = minf(weakest_mask_strength, mask_strength)
				sampled_point_count += 1

	if not T.require_true(self, sampled_point_count > 0, "Road-ground clearance test must sample at least one non-bridge road point"):
		return
	if not T.require_true(self, weakest_mask_strength >= MIN_ROAD_MASK_STRENGTH, "Terrain road overlay must cover sampled non-bridge road centerlines"):
		return

	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
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
		"world_seed": config.base_seed,
		"road_graph": world_data.get("road_graph"),
	}

func _sample_mask_strength(road_image: Image, local_point: Vector3, chunk_size_m: float) -> float:
	var normalized_x := clampf(local_point.x / chunk_size_m + 0.5, 0.0, 1.0)
	var normalized_z := clampf(local_point.z / chunk_size_m + 0.5, 0.0, 1.0)
	var pixel_x := mini(int(round(normalized_x * float(road_image.get_width() - 1))), road_image.get_width() - 1)
	var pixel_y := mini(int(round(normalized_z * float(road_image.get_height() - 1))), road_image.get_height() - 1)
	return road_image.get_pixel(pixel_x, pixel_y).r
