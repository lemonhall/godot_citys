extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

static func sample_height(local_point: Vector2, chunk_data: Dictionary, profile: Dictionary) -> float:
	return CityTerrainSampler.GROUND_HEIGHT_Y

static func sample_drive_height(local_point: Vector2, chunk_data: Dictionary, profile: Dictionary, road_id: String = "") -> float:
	var base_height := CityTerrainSampler.GROUND_HEIGHT_Y
	var matched_surface := _find_best_surface_sample(local_point, profile, road_id, true)
	if matched_surface.is_empty():
		matched_surface = _find_best_surface_sample(local_point, profile, "", true)
	if matched_surface.is_empty():
		return base_height
	return float(matched_surface.get("surface_y", base_height))

static func _blend_ground_to_roadbed(local_point: Vector2, base_height: float, profile: Dictionary) -> float:
	var shaped_height := base_height
	var best_distance := INF
	for road_segment in profile.get("road_segments", []):
		var sample := _sample_segment_surface(local_point, road_segment, false)
		if sample.is_empty():
			continue
		var distance := float(sample.get("distance_m", INF))
		var influence_radius := float(sample.get("influence_radius_m", 0.0))
		if distance >= influence_radius:
			continue
		var road_height := float(sample.get("surface_y", base_height))
		var weight := pow(1.0 - distance / influence_radius, 1.35)
		var blended_height := lerpf(base_height, road_height, clampf(weight * 0.96, 0.0, 1.0))
		if distance < best_distance:
			best_distance = distance
			shaped_height = blended_height
	return shaped_height

static func _find_best_surface_sample(local_point: Vector2, profile: Dictionary, road_id: String, include_bridges: bool) -> Dictionary:
	var preferred_match := {}
	var preferred_distance := INF
	var fallback_match := {}
	var fallback_distance := INF
	for road_segment in profile.get("road_segments", []):
		var sample := _sample_segment_surface(local_point, road_segment, include_bridges)
		if sample.is_empty():
			continue
		var distance := float(sample.get("distance_m", INF))
		var influence_radius := float(sample.get("influence_radius_m", 0.0))
		if distance > influence_radius:
			continue
		var segment_dict: Dictionary = road_segment
		if road_id != "" and str(segment_dict.get("road_id", "")) == road_id:
			if distance < preferred_distance:
				preferred_distance = distance
				preferred_match = sample
		elif distance < fallback_distance:
			fallback_distance = distance
			fallback_match = sample
	if not preferred_match.is_empty():
		return preferred_match
	return fallback_match

static func _sample_segment_surface(local_point: Vector2, road_segment, include_bridges: bool) -> Dictionary:
	if not road_segment is Dictionary:
		return {}
	var segment_dict: Dictionary = road_segment
	if not include_bridges and bool(segment_dict.get("bridge", false)):
		return {}
	var points: Array = segment_dict.get("points", [])
	if points.size() < 2:
		return {}
	var width := _resolve_surface_width_m(segment_dict)
	var influence_radius := maxf(width * 0.95 + 6.0, 16.0)
	var best_distance := INF
	var best_height := 0.0
	var best_tangent := Vector3.FORWARD
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var a_2d := Vector2(a.x, a.z)
		var b_2d := Vector2(b.x, b.z)
		var nearest := Geometry2D.get_closest_point_to_segment(local_point, a_2d, b_2d)
		var distance := local_point.distance_to(nearest)
		if distance >= best_distance:
			continue
		var segment_2d := b_2d - a_2d
		var segment_length_sq := segment_2d.length_squared()
		var t := 0.0 if segment_length_sq <= 0.001 else clampf((nearest - a_2d).dot(segment_2d) / segment_length_sq, 0.0, 1.0)
		best_distance = distance
		best_height = lerpf(a.y, b.y, t)
		best_tangent = (b - a).normalized() if (b - a).length_squared() > 0.0001 else Vector3.FORWARD
	if best_distance == INF:
		return {}
	return {
		"road_id": str(segment_dict.get("road_id", "")),
		"bridge": bool(segment_dict.get("bridge", false)),
		"surface_y": best_height,
		"distance_m": best_distance,
		"influence_radius_m": influence_radius,
		"tangent": best_tangent,
	}

static func _resolve_surface_width_m(segment_dict: Dictionary) -> float:
	var section_semantics: Dictionary = (segment_dict.get("section_semantics", {}) as Dictionary)
	var edge_profile: Dictionary = (section_semantics.get("edge_profile", {}) as Dictionary)
	var semantic_half_width_m := float(edge_profile.get("surface_half_width_m", 0.0))
	if semantic_half_width_m > 0.0:
		return semantic_half_width_m * 2.0
	var semantic_width_m := float(section_semantics.get("width_m", 0.0))
	if semantic_width_m > 0.0:
		return semantic_width_m
	return float(segment_dict.get("width", 11.0))
