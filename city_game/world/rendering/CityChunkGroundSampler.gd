extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

static func sample_height(local_point: Vector2, chunk_data: Dictionary, profile: Dictionary) -> float:
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var world_seed := int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0)))
	var world_x := chunk_center.x + local_point.x
	var world_z := chunk_center.z + local_point.y
	var base_height := CityTerrainSampler.sample_height(world_x, world_z, world_seed)
	return _blend_ground_to_roadbed(local_point, base_height, profile)

static func _blend_ground_to_roadbed(local_point: Vector2, base_height: float, profile: Dictionary) -> float:
	var shaped_height := base_height
	var best_distance := INF
	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		if bool(segment_dict.get("bridge", false)):
			continue
		var width := float(segment_dict.get("width", 0.0))
		var influence_radius := maxf(width * 0.95 + 6.0, 16.0)
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var nearest := Geometry2D.get_closest_point_to_segment(local_point, Vector2(a.x, a.z), Vector2(b.x, b.z))
			var distance := local_point.distance_to(nearest)
			if distance >= influence_radius:
				continue
			var segment_2d := Vector2(b.x - a.x, b.z - a.z)
			var segment_length_sq := segment_2d.length_squared()
			var t := 0.0 if segment_length_sq <= 0.001 else clampf((nearest - Vector2(a.x, a.z)).dot(segment_2d) / segment_length_sq, 0.0, 1.0)
			var road_height := lerpf(a.y, b.y, t) - 0.02
			var weight := pow(1.0 - distance / influence_radius, 1.35)
			var blended_height := lerpf(base_height, road_height, clampf(weight * 0.96, 0.0, 1.0))
			if distance < best_distance:
				best_distance = distance
				shaped_height = blended_height
	return shaped_height
