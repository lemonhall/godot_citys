extends RefCounted

static var _template_cache: Dictionary = {}

func get_template(chunk_size_m: float, grid_steps: int) -> Dictionary:
	var cache_key := _build_cache_key(chunk_size_m, grid_steps)
	if _template_cache.has(cache_key):
		return _template_cache[cache_key]

	var row_stride := grid_steps + 1
	var half_size := chunk_size_m * 0.5
	var local_points := PackedVector2Array()
	local_points.resize(row_stride * row_stride)
	var uvs := PackedVector2Array()
	uvs.resize(row_stride * row_stride)
	var write_index := 0
	for x_index in range(row_stride):
		for z_index in range(row_stride):
			var x_ratio := float(x_index) / float(grid_steps)
			var z_ratio := float(z_index) / float(grid_steps)
			local_points[write_index] = Vector2(
				lerpf(-half_size, half_size, x_ratio),
				lerpf(-half_size, half_size, z_ratio)
			)
			uvs[write_index] = Vector2(x_ratio, z_ratio)
			write_index += 1

	var indices := PackedInt32Array()
	indices.resize(grid_steps * grid_steps * 6)
	write_index = 0
	for x_index in range(grid_steps):
		for z_index in range(grid_steps):
			var top_left := x_index * row_stride + z_index
			var top_right := top_left + 1
			var bottom_left := (x_index + 1) * row_stride + z_index
			var bottom_right := bottom_left + 1
			indices[write_index] = top_left
			indices[write_index + 1] = bottom_left
			indices[write_index + 2] = bottom_right
			indices[write_index + 3] = top_left
			indices[write_index + 4] = bottom_right
			indices[write_index + 5] = top_right
			write_index += 6

	var template := {
		"cache_key": cache_key,
		"chunk_size_m": chunk_size_m,
		"grid_steps": grid_steps,
		"row_stride": row_stride,
		"vertex_count": local_points.size(),
		"index_count": indices.size(),
		"local_points": local_points,
		"uvs": uvs,
		"indices": indices,
	}
	_template_cache[cache_key] = template
	return template

func _build_cache_key(chunk_size_m: float, grid_steps: int) -> String:
	return "%0.3f:%d" % [chunk_size_m, grid_steps]
