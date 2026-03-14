extends RefCounted

const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityTerrainGridTemplate := preload("res://city_game/world/rendering/CityTerrainGridTemplate.gd")
const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"

var _template_catalog := CityTerrainGridTemplate.new()

func build_profiled_terrain_mesh(chunk_size_m: float, chunk_data: Dictionary, profile: Dictionary, grid_steps: int) -> Dictionary:
	var arrays_result := build_profiled_terrain_arrays(chunk_size_m, chunk_data, profile, grid_steps)
	var mesh := commit_terrain_mesh(arrays_result)
	arrays_result["mesh"] = mesh
	return arrays_result

func build_profiled_terrain_arrays(chunk_size_m: float, chunk_data: Dictionary, profile: Dictionary, grid_steps: int) -> Dictionary:
	var existing_mesh_result: Dictionary = chunk_data.get("terrain_mesh_result", {})
	if not existing_mesh_result.is_empty():
		return existing_mesh_result.duplicate(true)
	var sample_binding := _resolve_sample_binding(chunk_size_m, chunk_data, profile, grid_steps)
	return build_profiled_terrain_arrays_from_binding(chunk_size_m, grid_steps, sample_binding)

func build_profiled_terrain_lod_arrays(chunk_size_m: float, chunk_data: Dictionary, profile: Dictionary, source_grid_steps: int, lod_grid_steps_by_mode: Dictionary) -> Dictionary:
	var existing_lod_results: Dictionary = chunk_data.get("terrain_lod_mesh_results", {})
	if not existing_lod_results.is_empty():
		return existing_lod_results.duplicate(true)
	var sample_binding := _resolve_sample_binding(chunk_size_m, chunk_data, profile, source_grid_steps)
	return build_profiled_terrain_lod_arrays_from_binding(chunk_size_m, source_grid_steps, sample_binding, lod_grid_steps_by_mode)

func build_profiled_terrain_lod_arrays_from_binding(chunk_size_m: float, source_grid_steps: int, sample_binding: Dictionary, lod_grid_steps_by_mode: Dictionary) -> Dictionary:
	var results := {}
	for lod_mode in lod_grid_steps_by_mode.keys():
		var target_grid_steps := int(lod_grid_steps_by_mode[lod_mode])
		var target_binding := sample_binding if target_grid_steps == source_grid_steps else _downsample_sample_binding(sample_binding, source_grid_steps, target_grid_steps)
		var arrays_result := build_profiled_terrain_arrays_from_binding(chunk_size_m, target_grid_steps, target_binding)
		arrays_result["grid_steps"] = target_grid_steps
		results[str(lod_mode)] = arrays_result
	return results

func build_profiled_terrain_arrays_from_binding(chunk_size_m: float, grid_steps: int, sample_binding: Dictionary) -> Dictionary:
	var template: Dictionary = _template_catalog.get_template(chunk_size_m, grid_steps)
	var local_points: PackedVector2Array = template.get("local_points", PackedVector2Array())
	var uvs: PackedVector2Array = template.get("uvs", PackedVector2Array())
	var indices: PackedInt32Array = template.get("indices", PackedInt32Array())
	var heights: PackedFloat32Array = sample_binding.get("heights", PackedFloat32Array())
	var normals: PackedVector3Array = sample_binding.get("normals", PackedVector3Array())
	var vertices := PackedVector3Array()
	vertices.resize(local_points.size())
	for point_index in range(local_points.size()):
		var local_point := local_points[point_index]
		vertices[point_index] = Vector3(local_point.x, heights[point_index], local_point.y)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var collision_faces := _build_collision_faces(vertices, indices)
	var sample_stats: Dictionary = (sample_binding.get("sample_stats", {}) as Dictionary).duplicate(true)
	if sample_stats.is_empty():
		sample_stats = {
			"current_vertex_sample_count": heights.size(),
			"unique_vertex_sample_count": heights.size(),
			"duplicate_sample_count": 0,
			"raw_terrain_current_usec": 0,
			"shaped_current_usec": 0,
			"shaped_unique_usec": 0,
			"duplication_ratio": 1.0,
			"template_cache_key": str(sample_binding.get("runtime_key", "")),
		}

	return {
		"arrays": arrays,
		"collision_faces": collision_faces,
		"collision_face_count": int(collision_faces.size() / 3.0),
		"sample_stats": sample_stats,
		"page_contract": (sample_binding.get("page_contract", {}) as Dictionary).duplicate(true),
		"runtime_hit": bool(sample_binding.get("runtime_hit", false)),
		"grid_steps": grid_steps,
	}

func commit_terrain_mesh(arrays_result: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_result.get("arrays", []))
	return mesh

func _build_collision_faces(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if vertices.is_empty():
		return faces
	if indices.is_empty():
		faces = vertices
		return faces
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	return faces

func _downsample_sample_binding(source_binding: Dictionary, source_grid_steps: int, target_grid_steps: int) -> Dictionary:
	var source_heights: PackedFloat32Array = source_binding.get("heights", PackedFloat32Array())
	if target_grid_steps <= 0 or source_grid_steps <= 0 or target_grid_steps >= source_grid_steps:
		return source_binding.duplicate(true)
	var factor := int(float(source_grid_steps) / float(target_grid_steps))
	if factor <= 0 or factor * target_grid_steps != source_grid_steps:
		return source_binding.duplicate(true)
	var source_row_stride := source_grid_steps + 1
	var target_row_stride := target_grid_steps + 1
	var target_heights := PackedFloat32Array()
	target_heights.resize(target_row_stride * target_row_stride)
	var write_index := 0
	for x_index in range(target_row_stride):
		for z_index in range(target_row_stride):
			var source_index := (x_index * factor) * source_row_stride + (z_index * factor)
			target_heights[write_index] = source_heights[source_index]
			write_index += 1
	var target_normals := _build_normals(target_heights, target_row_stride, float(source_binding.get("chunk_size_m", 256.0)))
	return {
		"heights": target_heights,
		"normals": target_normals,
		"runtime_hit": bool(source_binding.get("runtime_hit", false)),
		"page_contract": (source_binding.get("page_contract", {}) as Dictionary).duplicate(true),
		"runtime_key": str(source_binding.get("runtime_key", "")),
		"chunk_size_m": float(source_binding.get("chunk_size_m", 256.0)),
		"sample_stats": {
			"current_vertex_sample_count": target_heights.size(),
			"unique_vertex_sample_count": target_heights.size(),
			"duplicate_sample_count": 0,
			"raw_terrain_current_usec": 0,
			"shaped_current_usec": 0,
			"shaped_unique_usec": 0,
			"duplication_ratio": 1.0,
			"template_cache_key": "%s_lod%d" % [str(source_binding.get("runtime_key", "")), target_grid_steps],
		},
	}

func _resolve_sample_binding(chunk_size_m: float, chunk_data: Dictionary, profile: Dictionary, grid_steps: int) -> Dictionary:
	var existing_binding: Dictionary = chunk_data.get("terrain_page_binding", {})
	if not existing_binding.is_empty() and int(existing_binding.get("grid_steps", 0)) == grid_steps:
		var existing_heights: PackedFloat32Array = existing_binding.get("heights", PackedFloat32Array())
		return {
			"heights": existing_heights,
			"normals": existing_binding.get("normals", PackedVector3Array()),
			"runtime_hit": bool(existing_binding.get("runtime_hit", false)),
			"page_contract": (existing_binding.get("page_contract", {}) as Dictionary).duplicate(true),
			"chunk_size_m": chunk_size_m,
			"sample_stats": {
				"current_vertex_sample_count": existing_heights.size(),
				"unique_vertex_sample_count": existing_heights.size(),
				"duplicate_sample_count": 0,
				"raw_terrain_current_usec": 0,
				"shaped_current_usec": 0,
				"shaped_unique_usec": 0,
				"duplication_ratio": 1.0,
				"template_cache_key": str(existing_binding.get("runtime_key", "")),
			},
		}

	var terrain_page_provider = chunk_data.get("terrain_page_provider")
	if terrain_page_provider != null and terrain_page_provider.has_method("resolve_chunk_sample_binding"):
		var page_binding: Dictionary = terrain_page_provider.resolve_chunk_sample_binding(chunk_data, grid_steps)
		var page_heights: PackedFloat32Array = page_binding.get("heights", PackedFloat32Array())
		return {
			"heights": page_heights,
			"normals": page_binding.get("normals", PackedVector3Array()),
			"runtime_hit": bool(page_binding.get("runtime_hit", false)),
			"page_contract": (page_binding.get("page_contract", {}) as Dictionary).duplicate(true),
			"runtime_key": str(page_binding.get("runtime_key", "")),
			"chunk_size_m": chunk_size_m,
			"sample_stats": {
				"current_vertex_sample_count": page_heights.size(),
				"unique_vertex_sample_count": page_heights.size(),
				"duplicate_sample_count": 0,
				"raw_terrain_current_usec": 0,
				"shaped_current_usec": 0,
				"shaped_unique_usec": 0,
				"duplication_ratio": 1.0,
				"template_cache_key": str(page_binding.get("runtime_key", "")),
			},
		}

	var row_stride := int(grid_steps + 1)
	var sample_started_usec := Time.get_ticks_usec()
	var template: Dictionary = _template_catalog.get_template(chunk_size_m, grid_steps)
	var local_points: PackedVector2Array = template.get("local_points", PackedVector2Array())
	var sampled_heights := PackedFloat32Array()
	sampled_heights.resize(local_points.size())
	for point_index in range(local_points.size()):
		var local_point := local_points[point_index]
		sampled_heights[point_index] = CityChunkGroundSampler.sample_height(local_point, chunk_data, profile)
	var shaped_usec := Time.get_ticks_usec() - sample_started_usec
	return {
		"heights": sampled_heights,
		"normals": _build_normals(sampled_heights, row_stride, chunk_size_m),
		"runtime_hit": false,
		"page_contract": {},
		"chunk_size_m": chunk_size_m,
		"sample_stats": {
			"current_vertex_sample_count": local_points.size(),
			"unique_vertex_sample_count": local_points.size(),
			"duplicate_sample_count": 0,
			"raw_terrain_current_usec": 0,
			"shaped_current_usec": shaped_usec,
			"shaped_unique_usec": shaped_usec,
			"duplication_ratio": 1.0,
			"template_cache_key": str(template.get("cache_key", "")),
		},
	}

func _build_normals(heights: PackedFloat32Array, row_stride: int, chunk_size_m: float) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(heights.size())
	var grid_steps := row_stride - 1
	var cell_size_m := chunk_size_m / float(maxi(grid_steps, 1))

	for x_index in range(row_stride):
		for z_index in range(row_stride):
			var left_x := maxi(x_index - 1, 0)
			var right_x := mini(x_index + 1, grid_steps)
			var down_z := maxi(z_index - 1, 0)
			var up_z := mini(z_index + 1, grid_steps)
			var center_index := x_index * row_stride + z_index
			var left_height := heights[left_x * row_stride + z_index]
			var right_height := heights[right_x * row_stride + z_index]
			var down_height := heights[x_index * row_stride + down_z]
			var up_height := heights[x_index * row_stride + up_z]
			var span_x := maxf(float(right_x - left_x) * cell_size_m, 0.001)
			var span_z := maxf(float(up_z - down_z) * cell_size_m, 0.001)
			var tangent_x := Vector3(span_x, right_height - left_height, 0.0)
			var tangent_z := Vector3(0.0, up_height - down_height, span_z)
			normals[center_index] = tangent_z.cross(tangent_x).normalized()

	return normals
