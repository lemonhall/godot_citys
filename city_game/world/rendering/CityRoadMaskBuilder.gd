extends RefCounted

const MASK_RESOLUTION := 256
const CityRoadSurfaceCache := preload("res://city_game/world/rendering/CityRoadSurfaceCache.gd")
const DETAIL_MODE_FULL := "full"
const DETAIL_MODE_COARSE := "coarse"

static func build_surface_textures(profile: Dictionary, chunk_size_m: float, detail_mode: String = DETAIL_MODE_FULL) -> Dictionary:
	var surface_request := _build_chunk_surface_request(profile, chunk_size_m, detail_mode)
	var surface_data := prepare_surface_data(surface_request)
	return commit_surface_textures(surface_data)

static func prepare_surface_data(surface_request: Dictionary) -> Dictionary:
	var total_started_usec := Time.get_ticks_usec()
	var detail_mode := str(surface_request.get("detail_mode", DETAIL_MODE_FULL))
	var mask_resolution := maxi(int(surface_request.get("mask_resolution", MASK_RESOLUTION)), 1)
	var surface_world_size_m := float(surface_request.get("surface_world_size_m", 256.0))
	var uv_rect: Rect2 = surface_request.get("uv_rect", Rect2(Vector2.ZERO, Vector2.ONE))
	var cache_signature := str(surface_request.get("cache_signature", ""))
	var cache_path := str(surface_request.get("cache_path", ""))
	var cache := CityRoadSurfaceCache.new()
	var cache_result := {
		"hit": false,
		"path": cache_path,
		"signature": cache_signature,
		"error": "",
		"road_bytes": PackedByteArray(),
		"stripe_bytes": PackedByteArray(),
	}
	var cache_load_usec := 0
	if cache_signature != "":
		var cache_started_usec := Time.get_ticks_usec()
		cache_result = cache.load_surface_masks_by_signature(cache_signature)
		cache_load_usec = Time.get_ticks_usec() - cache_started_usec
		if cache_path == "":
			cache_path = str(cache_result.get("path", ""))

	var road_bytes := PackedByteArray()
	var stripe_bytes := PackedByteArray()
	var surface_segments := _extract_surface_segments(surface_request.get("surface_segments", []))
	var clusters := _build_intersection_clusters(surface_segments)
	var paint_usec := 0
	var cache_write_usec := 0
	if bool(cache_result.get("hit", false)):
		road_bytes = cache_result.get("road_bytes", PackedByteArray())
		stripe_bytes = cache_result.get("stripe_bytes", PackedByteArray())
	else:
		road_bytes.resize(mask_resolution * mask_resolution)
		road_bytes.fill(0)
		stripe_bytes.resize(mask_resolution * mask_resolution)
		stripe_bytes.fill(0)
		var paint_started_usec := Time.get_ticks_usec()
		for road_segment in surface_segments:
			var segment_dict: Dictionary = road_segment
			_paint_segment_mask(road_bytes, segment_dict, surface_world_size_m, false, mask_resolution)
			if detail_mode == DETAIL_MODE_FULL:
				_paint_segment_mask(stripe_bytes, segment_dict, surface_world_size_m, true, mask_resolution)

		for cluster in clusters:
			var cluster_dict: Dictionary = cluster
			_paint_disc(
				road_bytes,
				_local_point_to_pixel(cluster_dict.get("center", Vector3.ZERO), surface_world_size_m, mask_resolution),
				_world_radius_to_pixels(float(cluster_dict.get("radius", 0.0)), surface_world_size_m, mask_resolution),
				1.4,
				mask_resolution
			)
		paint_usec = Time.get_ticks_usec() - paint_started_usec

		if cache_signature != "":
			var save_started_usec := Time.get_ticks_usec()
			var save_result := cache.save_surface_masks_by_signature(cache_signature, road_bytes, stripe_bytes)
			cache_write_usec = Time.get_ticks_usec() - save_started_usec
			if not bool(save_result.get("success", false)) and str(cache_result.get("error", "")) == "":
				cache_result["error"] = str(save_result.get("error", "save_failed"))
			cache_result["path"] = str(save_result.get("path", cache_path))
			cache_result["signature"] = str(save_result.get("signature", cache_signature))

	var prepare_total_usec := Time.get_ticks_usec() - total_started_usec
	return {
		"road_bytes": road_bytes,
		"stripe_bytes": stripe_bytes,
		"uv_rect": uv_rect,
		"page_key": surface_request.get("page_key", Vector2i.ZERO),
		"detail_mode": detail_mode,
		"surface_world_size_m": surface_world_size_m,
		"mask_resolution": mask_resolution,
		"mask_profile_stats": {
			"surface_scope": str(surface_request.get("surface_scope", "chunk")),
			"surface_segment_count": surface_segments.size(),
			"intersection_cluster_count": clusters.size(),
			"cache_hit": bool(cache_result.get("hit", false)),
			"cache_load_usec": cache_load_usec,
			"cache_write_usec": cache_write_usec,
			"cache_path": str(cache_result.get("path", cache_path)),
			"cache_signature": str(cache_result.get("signature", cache_signature)),
			"cache_error": str(cache_result.get("error", "")),
			"detail_mode": detail_mode,
			"stripe_paint_enabled": detail_mode == DETAIL_MODE_FULL,
			"paint_usec": paint_usec,
			"image_usec": 0,
			"texture_usec": 0,
			"prepare_total_usec": prepare_total_usec,
			"total_usec": prepare_total_usec,
		},
	}

static func commit_surface_textures(surface_data: Dictionary) -> Dictionary:
	var total_started_usec := Time.get_ticks_usec()
	var mask_resolution := maxi(int(surface_data.get("mask_resolution", MASK_RESOLUTION)), 1)
	var road_bytes: PackedByteArray = surface_data.get("road_bytes", PackedByteArray())
	var stripe_bytes: PackedByteArray = surface_data.get("stripe_bytes", PackedByteArray())
	if road_bytes.size() != mask_resolution * mask_resolution:
		road_bytes.resize(mask_resolution * mask_resolution)
		road_bytes.fill(0)
	if stripe_bytes.size() != mask_resolution * mask_resolution:
		stripe_bytes.resize(mask_resolution * mask_resolution)
		stripe_bytes.fill(0)
	var image_started_usec := Time.get_ticks_usec()
	var road_image := Image.create_from_data(mask_resolution, mask_resolution, false, Image.FORMAT_L8, road_bytes)
	var stripe_image := Image.create_from_data(mask_resolution, mask_resolution, false, Image.FORMAT_L8, stripe_bytes)
	var image_usec := Time.get_ticks_usec() - image_started_usec
	var texture_started_usec := Time.get_ticks_usec()
	var road_texture := ImageTexture.create_from_image(road_image)
	var stripe_texture := ImageTexture.create_from_image(stripe_image)
	var texture_usec := Time.get_ticks_usec() - texture_started_usec
	var stats: Dictionary = (surface_data.get("mask_profile_stats", {}) as Dictionary).duplicate(true)
	var prepare_total_usec := int(stats.get("prepare_total_usec", stats.get("total_usec", 0)))
	stats["image_usec"] = image_usec
	stats["texture_usec"] = texture_usec
	stats["prepare_total_usec"] = prepare_total_usec
	stats["commit_total_usec"] = Time.get_ticks_usec() - total_started_usec
	stats["total_usec"] = prepare_total_usec + int(stats.get("commit_total_usec", 0))
	return {
		"road_mask_texture": road_texture,
		"stripe_mask_texture": stripe_texture,
		"surface_segment_count": int(stats.get("surface_segment_count", 0)),
		"uv_rect": surface_data.get("uv_rect", Rect2(Vector2.ZERO, Vector2.ONE)),
		"page_key": surface_data.get("page_key", Vector2i.ZERO),
		"detail_mode": surface_data.get("detail_mode", DETAIL_MODE_FULL),
		"mask_resolution": mask_resolution,
		"mask_profile_stats": stats,
	}

static func _build_chunk_surface_request(profile: Dictionary, chunk_size_m: float, detail_mode: String) -> Dictionary:
	var cache := CityRoadSurfaceCache.new()
	return {
		"surface_scope": "chunk",
		"cache_signature": cache.build_cache_signature(profile, chunk_size_m, detail_mode, MASK_RESOLUTION),
		"cache_path": cache.build_cache_path(profile, chunk_size_m, detail_mode, MASK_RESOLUTION),
		"surface_segments": profile.get("road_segments", []),
		"surface_world_size_m": chunk_size_m,
		"mask_resolution": MASK_RESOLUTION,
		"detail_mode": detail_mode,
		"uv_rect": Rect2(Vector2.ZERO, Vector2.ONE),
		"page_key": profile.get("chunk_key", Vector2i.ZERO),
	}

static func _extract_surface_segments(raw_segments: Array) -> Array:
	var surface_segments: Array = []
	for road_segment in raw_segments:
		var segment_dict: Dictionary = (road_segment as Dictionary).duplicate(true)
		if bool(segment_dict.get("bridge", false)):
			continue
		surface_segments.append(segment_dict)
	return surface_segments

static func _paint_segment_mask(mask_bytes: PackedByteArray, segment_dict: Dictionary, surface_world_size_m: float, stripe_only: bool, mask_resolution: int) -> void:
	var points: Array = segment_dict.get("points", [])
	if points.size() < 2:
		return
	var template_id := str(segment_dict.get("template_id", "local"))
	if stripe_only and template_id == "service":
		return

	var width_m := float(segment_dict.get("width", 11.0))
	var radius_px := _world_radius_to_pixels(_resolve_mask_radius_m(segment_dict, stripe_only), surface_world_size_m, mask_resolution)
	var feather_px := 1.0 if stripe_only else 1.5
	for point_index in range(points.size() - 1):
		var start_point: Vector3 = points[point_index]
		var end_point: Vector3 = points[point_index + 1]
		_paint_capsule_segment(
			mask_bytes,
			_local_point_to_pixel(start_point, surface_world_size_m, mask_resolution),
			_local_point_to_pixel(end_point, surface_world_size_m, mask_resolution),
			radius_px,
			feather_px,
			mask_resolution
		)

static func _resolve_mask_radius_m(segment_dict: Dictionary, stripe_only: bool) -> float:
	if stripe_only:
		var lane_count_total := int(segment_dict.get("lane_count_total", 2))
		if lane_count_total >= 6:
			return 0.34
		if lane_count_total >= 4:
			return 0.28
		return 0.22
	return float(segment_dict.get("width", 11.0)) * 0.5 + 0.4

static func _paint_disc(mask_bytes: PackedByteArray, center_px: Vector2, radius_px: float, feather_px: float, mask_resolution: int) -> void:
	if radius_px <= 0.0:
		return
	var min_x := maxi(0, int(floor(center_px.x - radius_px - feather_px)))
	var max_x := mini(mask_resolution - 1, int(ceil(center_px.x + radius_px + feather_px)))
	var min_y := maxi(0, int(floor(center_px.y - radius_px - feather_px)))
	var max_y := mini(mask_resolution - 1, int(ceil(center_px.y + radius_px + feather_px)))
	var falloff := maxf(feather_px, 0.001)
	for pixel_y in range(min_y, max_y + 1):
		for pixel_x in range(min_x, max_x + 1):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var distance_to_center := pixel_center.distance_to(center_px)
			var strength := clampf((radius_px + falloff - distance_to_center) / falloff, 0.0, 1.0)
			if strength <= 0.0:
				continue
			var byte_index := pixel_y * mask_resolution + pixel_x
			var current_value := int(mask_bytes[byte_index])
			var next_value := maxi(current_value, int(round(strength * 255.0)))
			mask_bytes[byte_index] = next_value

static func _paint_capsule_segment(mask_bytes: PackedByteArray, start_px: Vector2, end_px: Vector2, radius_px: float, feather_px: float, mask_resolution: int) -> void:
	if radius_px <= 0.0:
		return
	if start_px.distance_squared_to(end_px) <= 0.0001:
		_paint_disc(mask_bytes, start_px, radius_px, feather_px, mask_resolution)
		return
	var extent_px := radius_px + feather_px
	var min_x := maxi(0, int(floor(minf(start_px.x, end_px.x) - extent_px)))
	var max_x := mini(mask_resolution - 1, int(ceil(maxf(start_px.x, end_px.x) + extent_px)))
	var min_y := maxi(0, int(floor(minf(start_px.y, end_px.y) - extent_px)))
	var max_y := mini(mask_resolution - 1, int(ceil(maxf(start_px.y, end_px.y) + extent_px)))
	var segment := end_px - start_px
	var segment_length_squared := maxf(segment.length_squared(), 0.0001)
	var falloff := maxf(feather_px, 0.001)
	for pixel_y in range(min_y, max_y + 1):
		for pixel_x in range(min_x, max_x + 1):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var projection := clampf((pixel_center - start_px).dot(segment) / segment_length_squared, 0.0, 1.0)
			var closest_point := start_px + segment * projection
			var distance_to_segment := pixel_center.distance_to(closest_point)
			var strength := clampf((radius_px + falloff - distance_to_segment) / falloff, 0.0, 1.0)
			if strength <= 0.0:
				continue
			var byte_index := pixel_y * mask_resolution + pixel_x
			var current_value := int(mask_bytes[byte_index])
			var next_value := maxi(current_value, int(round(strength * 255.0)))
			mask_bytes[byte_index] = next_value

static func _local_point_to_pixel(point: Vector3, surface_world_size_m: float, mask_resolution: int) -> Vector2:
	var normalized_x := clampf(point.x / maxf(surface_world_size_m, 1.0) + 0.5, 0.0, 1.0)
	var normalized_z := clampf(point.z / maxf(surface_world_size_m, 1.0) + 0.5, 0.0, 1.0)
	return Vector2(
		normalized_x * float(mask_resolution - 1),
		normalized_z * float(mask_resolution - 1)
	)

static func _world_radius_to_pixels(radius_m: float, surface_world_size_m: float, mask_resolution: int) -> float:
	return maxf(radius_m / maxf(surface_world_size_m, 1.0) * float(mask_resolution), 0.0)

static func resolve_sample_spacing_m(width_m: float, chunk_size_m: float, stripe_only: bool, mask_resolution: int = MASK_RESOLUTION) -> float:
	var pixel_size_m := chunk_size_m / float(mask_resolution)
	if stripe_only:
		return clampf(maxf(width_m * 0.25, pixel_size_m * 2.0), 2.0, 5.0)
	return clampf(maxf(width_m * 0.5, pixel_size_m * 4.0), 4.0, 10.0)

static func _build_intersection_clusters(road_segments: Array) -> Array:
	var clusters: Dictionary = {}
	for road_segment in road_segments:
		var segment_dict: Dictionary = road_segment
		var points: Array = segment_dict.get("points", [])
		if points.is_empty():
			continue
		var width := float(segment_dict.get("width", 11.0))
		for endpoint_index in [0, points.size() - 1]:
			var point: Vector3 = points[endpoint_index]
			var key := "%d|%d|%d" % [int(round(point.x * 2.0)), int(round(point.y * 2.0)), int(round(point.z * 2.0))]
			if not clusters.has(key):
				clusters[key] = {
					"center": point,
					"radius": width * 0.56,
					"count": 0,
				}
			var cluster: Dictionary = clusters[key]
			cluster["radius"] = maxf(float(cluster.get("radius", 0.0)), width * 0.56)
			cluster["count"] = int(cluster.get("count", 0)) + 1
			clusters[key] = cluster
	var results: Array = []
	for cluster in clusters.values():
		var cluster_dict: Dictionary = cluster
		if int(cluster_dict.get("count", 0)) >= 2:
			results.append(cluster_dict)
	return results
