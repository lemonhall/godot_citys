extends RefCounted

static func build_chunk_nav(config, chunk_key: Vector2i) -> Dictionary:
	var center := _chunk_center_from_key(config, chunk_key)
	var half_size := float(config.chunk_size_m) * 0.5
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"center": center,
		"portals": {
			"west": Vector3(center.x - half_size, 0.0, center.z),
			"east": Vector3(center.x + half_size, 0.0, center.z),
			"north": Vector3(center.x, 0.0, center.z - half_size),
			"south": Vector3(center.x, 0.0, center.z + half_size),
		}
	}

static func _chunk_center_from_key(config, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	var center_x := bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m)
	var center_z := bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	return Vector3(center_x, 0.0, center_z)
