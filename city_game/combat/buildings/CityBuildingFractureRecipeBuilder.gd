extends RefCounted

static func build_recipe(request: Dictionary) -> Dictionary:
	var body_size: Vector3 = request.get("body_size", Vector3(14.0, 48.0, 14.0))
	var hit_local_position: Vector3 = request.get("hit_local_position", Vector3.ZERO)
	var half_extents := body_size * 0.5
	var hit_height_alpha := clampf((hit_local_position.y + half_extents.y) / maxf(body_size.y, 0.001), 0.0, 1.0)
	var impact_side := _resolve_impact_side(hit_local_position, half_extents)
	var impact_direction := _resolve_impact_direction(impact_side)
	var base_height_ratio := lerpf(0.18, 0.34, pow(hit_height_alpha, 1.1))
	if impact_side == "base":
		base_height_ratio = 0.14
	var base_height_m := clampf(maxf(body_size.y * base_height_ratio, 3.0), 3.0, body_size.y * 0.42)
	var dynamic_height_m := maxf(body_size.y - base_height_m, 4.0)
	var level_count := maxi(4, mini(6, int(round(dynamic_height_m / 10.0))))
	var level_height_m := dynamic_height_m / float(level_count)
	var shell_base_thickness_m := clampf(minf(body_size.x, body_size.z) * 0.18, 1.05, 2.6)
	var chunks: Array[Dictionary] = []
	var size_keys: Dictionary = {}
	var dynamic_bottom_y := -half_extents.y + base_height_m

	for level_index in range(level_count):
		var level_alpha := float(level_index) / maxf(float(level_count - 1), 1.0)
		var shell_thickness_m := shell_base_thickness_m * lerpf(0.86, 1.22, _normalized_wave(level_index, 7))
		var center_y := dynamic_bottom_y + level_height_m * (float(level_index) + 0.5)
		_append_side_chunks(chunks, size_keys, half_extents, level_height_m, center_y, shell_thickness_m, impact_direction, impact_side, "west", level_alpha, level_index, body_size.z)
		_append_side_chunks(chunks, size_keys, half_extents, level_height_m, center_y, shell_thickness_m, impact_direction, impact_side, "east", level_alpha, level_index, body_size.z)
		_append_side_chunks(chunks, size_keys, half_extents, level_height_m, center_y, shell_thickness_m, impact_direction, impact_side, "north", level_alpha, level_index, body_size.x)
		_append_side_chunks(chunks, size_keys, half_extents, level_height_m, center_y, shell_thickness_m, impact_direction, impact_side, "south", level_alpha, level_index, body_size.x)

	_append_roof_chunks(chunks, size_keys, body_size, half_extents, level_height_m, impact_direction, impact_side, shell_base_thickness_m)

	return {
		"success": true,
		"body_size": body_size,
		"hit_local_position": hit_local_position,
		"impact_side": impact_side,
		"impact_direction": impact_direction,
		"base_center": Vector3(0.0, -half_extents.y + base_height_m * 0.5, 0.0),
		"base_size": Vector3(body_size.x * 1.04, base_height_m, body_size.z * 1.04),
		"chunks": chunks,
		"dynamic_chunk_count": chunks.size(),
		"unique_size_count": size_keys.size(),
		"base_height_m": base_height_m,
	}

static func _build_chunk(center: Vector3, size: Vector3, face_direction: Vector3, impact_direction: Vector3, impact_side: String, side_id: String, level_alpha: float) -> Dictionary:
	var impact_alignment := maxf(face_direction.dot(impact_direction), 0.0)
	var impulse_direction := (face_direction * (1.0 + impact_alignment * 1.6) + impact_direction * 0.55 + Vector3.UP * lerpf(0.55, 1.08, level_alpha)).normalized()
	if impulse_direction.length_squared() <= 0.0001:
		impulse_direction = (face_direction + Vector3.UP * 0.72).normalized()
	return {
		"center": center,
		"size": size,
		"side_id": side_id,
		"impact_favored": side_id == impact_side,
		"impulse_direction": impulse_direction,
		"impulse_speed": lerpf(5.4, 9.2, level_alpha) + impact_alignment * 2.8,
		"angular_axis": Vector3(face_direction.z, 0.62 + level_alpha * 0.48, -face_direction.x).normalized(),
		"angular_speed": 1.05 + level_alpha * 1.25 + impact_alignment * 0.8,
	}

static func _resolve_impact_side(hit_local_position: Vector3, half_extents: Vector3) -> String:
	var safe_half := Vector3(maxf(absf(half_extents.x), 0.001), maxf(absf(half_extents.y), 0.001), maxf(absf(half_extents.z), 0.001))
	var normalized := Vector3(
		absf(hit_local_position.x) / safe_half.x,
		absf(hit_local_position.y) / safe_half.y,
		absf(hit_local_position.z) / safe_half.z
	)
	if normalized.x >= normalized.y and normalized.x >= normalized.z:
		return "east" if hit_local_position.x >= 0.0 else "west"
	if normalized.z >= normalized.x and normalized.z >= normalized.y:
		return "south" if hit_local_position.z >= 0.0 else "north"
	return "roof" if hit_local_position.y >= 0.0 else "base"

static func _resolve_impact_direction(impact_side: String) -> Vector3:
	match impact_side:
		"west":
			return Vector3.LEFT
		"east":
			return Vector3.RIGHT
		"north":
			return Vector3.BACK
		"south":
			return Vector3.FORWARD
		"base":
			return Vector3.DOWN
		_:
			return Vector3.UP

static func _append_side_chunks(chunks: Array[Dictionary], size_keys: Dictionary, half_extents: Vector3, level_height_m: float, center_y: float, shell_thickness_m: float, impact_direction: Vector3, impact_side: String, side_id: String, level_alpha: float, level_index: int, span_total_m: float) -> void:
	var segment_count := 3 if side_id == impact_side else (2 + (level_index % 2))
	var span_segments := _build_span_segments(span_total_m, segment_count, level_index * 17 + side_id.length() * 11)
	var cursor := -span_total_m * 0.5
	var face_direction := _resolve_impact_direction(side_id)
	for segment_index in range(span_segments.size()):
		var segment_length := span_segments[segment_index]
		var center_along_span := cursor + segment_length * 0.5
		cursor += segment_length
		var center := Vector3.ZERO
		var size := Vector3.ONE
		match side_id:
			"west":
				center = Vector3(-half_extents.x + shell_thickness_m * 0.5, center_y, center_along_span)
				size = Vector3(shell_thickness_m, level_height_m, maxf(segment_length * 0.96, 0.8))
			"east":
				center = Vector3(half_extents.x - shell_thickness_m * 0.5, center_y, center_along_span)
				size = Vector3(shell_thickness_m, level_height_m, maxf(segment_length * 0.96, 0.8))
			"north":
				center = Vector3(center_along_span, center_y, -half_extents.z + shell_thickness_m * 0.5)
				size = Vector3(maxf(segment_length * 0.96, 0.8), level_height_m, shell_thickness_m)
			_:
				center = Vector3(center_along_span, center_y, half_extents.z - shell_thickness_m * 0.5)
				size = Vector3(maxf(segment_length * 0.96, 0.8), level_height_m, shell_thickness_m)
		_track_size_key(size_keys, size)
		chunks.append(_build_chunk(center, size, face_direction, impact_direction, impact_side, side_id, level_alpha))

static func _append_roof_chunks(chunks: Array[Dictionary], size_keys: Dictionary, body_size: Vector3, half_extents: Vector3, level_height_m: float, impact_direction: Vector3, impact_side: String, shell_base_thickness_m: float) -> void:
	var roof_height_m := maxf(level_height_m * 0.48, 1.8)
	var roof_width_m := maxf(body_size.x * 0.72, shell_base_thickness_m * 2.2)
	var roof_depth_m := maxf(body_size.z * 0.72, shell_base_thickness_m * 2.2)
	var roof_segments_x := _build_span_segments(roof_width_m, 2, 97)
	var roof_segments_z := _build_span_segments(roof_depth_m, 2, 131)
	var start_x := -roof_width_m * 0.5
	for x_index in range(roof_segments_x.size()):
		var width_m := roof_segments_x[x_index]
		var center_x := start_x + width_m * 0.5
		start_x += width_m
		var start_z := -roof_depth_m * 0.5
		for z_index in range(roof_segments_z.size()):
			var depth_m := roof_segments_z[z_index]
			var center_z := start_z + depth_m * 0.5
			start_z += depth_m
			var roof_size := Vector3(maxf(width_m * 0.94, 0.8), roof_height_m, maxf(depth_m * 0.94, 0.8))
			_track_size_key(size_keys, roof_size)
			chunks.append(_build_chunk(
				Vector3(center_x, half_extents.y - roof_height_m * 0.5, center_z),
				roof_size,
				Vector3.UP,
				impact_direction,
				impact_side,
				"roof",
				1.0
			))

static func _build_span_segments(total_span_m: float, segment_count: int, seed_value: int) -> Array[float]:
	var clamped_count := maxi(segment_count, 1)
	var weights: Array[float] = []
	var weight_sum := 0.0
	for segment_index in range(clamped_count):
		var weight := 0.78 + absf(sin(float(seed_value) * 0.73 + float(segment_index) * 1.19)) * 0.92 + float((seed_value + segment_index) % 3) * 0.11
		weights.append(weight)
		weight_sum += weight
	var resolved_segments: Array[float] = []
	for weight_variant in weights:
		var weight := float(weight_variant)
		resolved_segments.append(total_span_m * weight / maxf(weight_sum, 0.001))
	return resolved_segments

static func _normalized_wave(index_value: int, seed_value: int) -> float:
	return clampf(0.5 + 0.5 * sin(float(index_value * 13 + seed_value) * 0.41), 0.0, 1.0)

static func _track_size_key(size_keys: Dictionary, size: Vector3) -> void:
	var size_key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	size_keys[size_key] = true
