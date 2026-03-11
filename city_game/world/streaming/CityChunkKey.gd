extends RefCounted

static func world_to_chunk_key(config, world_position: Vector3) -> Vector2i:
	var bounds: Rect2 = config.get_world_bounds()
	var grid: Vector2i = config.get_chunk_grid_size()
	var raw_x := int(floor((world_position.x - bounds.position.x) / float(config.chunk_size_m)))
	var raw_y := int(floor((world_position.z - bounds.position.y) / float(config.chunk_size_m)))
	return Vector2i(
		clampi(raw_x, 0, grid.x - 1),
		clampi(raw_y, 0, grid.y - 1)
	)

static func get_window_keys(config, center_chunk_key: Vector2i, radius: int = 2) -> Array[Vector2i]:
	var grid: Vector2i = config.get_chunk_grid_size()
	var keys: Array[Vector2i] = []
	for x in range(maxi(center_chunk_key.x - radius, 0), mini(center_chunk_key.x + radius, grid.x - 1) + 1):
		for y in range(maxi(center_chunk_key.y - radius, 0), mini(center_chunk_key.y + radius, grid.y - 1) + 1):
			keys.append(Vector2i(x, y))
	return keys

