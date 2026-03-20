extends RefCounted

static func build_recipe(request: Dictionary) -> Dictionary:
	var body_size: Vector3 = request.get("body_size", Vector3(14.0, 48.0, 14.0))
	var hit_local_position: Vector3 = request.get("hit_local_position", Vector3.ZERO)
	var half_extents := body_size * 0.5
	var base_height_m := clampf(maxf(body_size.y * 0.16, 3.0), 3.0, body_size.y * 0.34)
	var dynamic_height_m := maxf(body_size.y - base_height_m, 4.0)
	var level_count := maxi(3, mini(4, int(round(dynamic_height_m / 18.0))))
	var level_height_m := dynamic_height_m / float(level_count)
	var shell_thickness_m := clampf(minf(body_size.x, body_size.z) * 0.22, 1.25, 3.2)
	var core_width_x := maxf(body_size.x - shell_thickness_m * 2.0, shell_thickness_m * 0.9)
	var impact_side := _resolve_impact_side(hit_local_position, half_extents)
	var impact_direction := _resolve_impact_direction(impact_side)
	var chunks: Array[Dictionary] = []
	var dynamic_bottom_y := -half_extents.y + base_height_m

	for level_index in range(level_count):
		var level_alpha := float(level_index) / maxf(float(level_count - 1), 1.0)
		var center_y := dynamic_bottom_y + level_height_m * (float(level_index) + 0.5)
		chunks.append(_build_chunk(Vector3(-half_extents.x + shell_thickness_m * 0.5, center_y, 0.0), Vector3(shell_thickness_m, level_height_m, body_size.z), Vector3.LEFT, impact_direction, impact_side, "west", level_alpha))
		chunks.append(_build_chunk(Vector3(half_extents.x - shell_thickness_m * 0.5, center_y, 0.0), Vector3(shell_thickness_m, level_height_m, body_size.z), Vector3.RIGHT, impact_direction, impact_side, "east", level_alpha))
		chunks.append(_build_chunk(Vector3(0.0, center_y, -half_extents.z + shell_thickness_m * 0.5), Vector3(core_width_x, level_height_m, shell_thickness_m), Vector3.BACK, impact_direction, impact_side, "north", level_alpha))
		chunks.append(_build_chunk(Vector3(0.0, center_y, half_extents.z - shell_thickness_m * 0.5), Vector3(core_width_x, level_height_m, shell_thickness_m), Vector3.FORWARD, impact_direction, impact_side, "south", level_alpha))

	var roof_height_m := maxf(level_height_m * 0.55, 2.0)
	chunks.append(_build_chunk(
		Vector3(0.0, half_extents.y - roof_height_m * 0.5, 0.0),
		Vector3(maxf(body_size.x * 0.68, shell_thickness_m * 1.4), roof_height_m, maxf(body_size.z * 0.68, shell_thickness_m * 1.4)),
		Vector3.UP,
		impact_direction,
		impact_side,
		"roof",
		1.0
	))

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
