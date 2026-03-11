extends RefCounted

const MASK_RESOLUTION := 256

static func build_surface_textures(profile: Dictionary, chunk_size_m: float) -> Dictionary:
	var road_image := Image.create(MASK_RESOLUTION, MASK_RESOLUTION, false, Image.FORMAT_RGBA8)
	var stripe_image := Image.create(MASK_RESOLUTION, MASK_RESOLUTION, false, Image.FORMAT_RGBA8)
	road_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	stripe_image.fill(Color(0.0, 0.0, 0.0, 1.0))

	var surface_segments: Array = []
	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		if bool(segment_dict.get("bridge", false)):
			continue
		surface_segments.append(segment_dict)
		_paint_segment_mask(road_image, segment_dict, chunk_size_m, false)
		_paint_segment_mask(stripe_image, segment_dict, chunk_size_m, true)

	for cluster in _build_intersection_clusters(surface_segments):
		var cluster_dict: Dictionary = cluster
		_paint_disc(
			road_image,
			_local_point_to_pixel(cluster_dict.get("center", Vector3.ZERO), chunk_size_m),
			_world_radius_to_pixels(float(cluster_dict.get("radius", 0.0)), chunk_size_m),
			1.4
		)

	road_image.generate_mipmaps()
	stripe_image.generate_mipmaps()
	return {
		"road_mask_texture": ImageTexture.create_from_image(road_image),
		"stripe_mask_texture": ImageTexture.create_from_image(stripe_image),
		"surface_segment_count": surface_segments.size(),
	}

static func _paint_segment_mask(image: Image, segment_dict: Dictionary, chunk_size_m: float, stripe_only: bool) -> void:
	var points: Array = segment_dict.get("points", [])
	if points.size() < 2:
		return
	var template_id := str(segment_dict.get("template_id", "local"))
	if stripe_only and template_id == "service":
		return

	var width_m := float(segment_dict.get("width", 11.0))
	var radius_px := _world_radius_to_pixels(_resolve_mask_radius_m(segment_dict, stripe_only), chunk_size_m)
	var feather_px := 1.0 if stripe_only else 1.5
	for point_index in range(points.size() - 1):
		var start_point: Vector3 = points[point_index]
		var end_point: Vector3 = points[point_index + 1]
		var length_m := Vector2(start_point.x, start_point.z).distance_to(Vector2(end_point.x, end_point.z))
		var spacing_m := clampf(width_m * (0.08 if stripe_only else 0.16), 0.7, 2.0)
		var sample_count := maxi(1, int(ceil(length_m / spacing_m)))
		for sample_index in range(sample_count + 1):
			var ratio := float(sample_index) / float(sample_count)
			var sample_point := start_point.lerp(end_point, ratio)
			_paint_disc(
				image,
				_local_point_to_pixel(sample_point, chunk_size_m),
				radius_px,
				feather_px
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

static func _paint_disc(image: Image, center_px: Vector2, radius_px: float, feather_px: float) -> void:
	if radius_px <= 0.0:
		return
	var min_x := maxi(0, int(floor(center_px.x - radius_px - feather_px)))
	var max_x := mini(MASK_RESOLUTION - 1, int(ceil(center_px.x + radius_px + feather_px)))
	var min_y := maxi(0, int(floor(center_px.y - radius_px - feather_px)))
	var max_y := mini(MASK_RESOLUTION - 1, int(ceil(center_px.y + radius_px + feather_px)))
	var falloff := maxf(feather_px, 0.001)
	for pixel_y in range(min_y, max_y + 1):
		for pixel_x in range(min_x, max_x + 1):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var distance_to_center := pixel_center.distance_to(center_px)
			var strength := clampf((radius_px + falloff - distance_to_center) / falloff, 0.0, 1.0)
			if strength <= 0.0:
				continue
			var current_value := image.get_pixel(pixel_x, pixel_y).r
			var next_value := maxf(current_value, strength)
			image.set_pixel(pixel_x, pixel_y, Color(next_value, next_value, next_value, 1.0))

static func _local_point_to_pixel(point: Vector3, chunk_size_m: float) -> Vector2:
	var normalized_x := clampf(point.x / maxf(chunk_size_m, 1.0) + 0.5, 0.0, 1.0)
	var normalized_z := clampf(point.z / maxf(chunk_size_m, 1.0) + 0.5, 0.0, 1.0)
	return Vector2(
		normalized_x * float(MASK_RESOLUTION - 1),
		normalized_z * float(MASK_RESOLUTION - 1)
	)

static func _world_radius_to_pixels(radius_m: float, chunk_size_m: float) -> float:
	return maxf(radius_m / maxf(chunk_size_m, 1.0) * float(MASK_RESOLUTION), 0.0)

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
