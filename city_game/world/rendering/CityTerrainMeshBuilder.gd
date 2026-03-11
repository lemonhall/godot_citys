extends RefCounted

const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityTerrainGridTemplate := preload("res://city_game/world/rendering/CityTerrainGridTemplate.gd")

var _template_catalog := CityTerrainGridTemplate.new()

func build_profiled_terrain_mesh(chunk_size_m: float, chunk_data: Dictionary, profile: Dictionary, grid_steps: int) -> Dictionary:
	var template: Dictionary = _template_catalog.get_template(chunk_size_m, grid_steps)
	var local_points: PackedVector2Array = template.get("local_points", PackedVector2Array())
	var uvs: PackedVector2Array = template.get("uvs", PackedVector2Array())
	var indices: PackedInt32Array = template.get("indices", PackedInt32Array())
	var row_stride := int(template.get("row_stride", grid_steps + 1))

	var sample_started_usec := Time.get_ticks_usec()
	var heights := PackedFloat32Array()
	heights.resize(local_points.size())
	var vertices := PackedVector3Array()
	vertices.resize(local_points.size())
	for point_index in range(local_points.size()):
		var local_point := local_points[point_index]
		var shaped_height := CityChunkGroundSampler.sample_height(local_point, chunk_data, profile)
		heights[point_index] = shaped_height
		vertices[point_index] = Vector3(local_point.x, shaped_height, local_point.y)
	var shaped_usec := Time.get_ticks_usec() - sample_started_usec

	var normals := _build_normals(heights, row_stride, chunk_size_m)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var sample_stats := {
		"current_vertex_sample_count": local_points.size(),
		"unique_vertex_sample_count": local_points.size(),
		"duplicate_sample_count": 0,
		"raw_terrain_current_usec": 0,
		"shaped_current_usec": shaped_usec,
		"shaped_unique_usec": shaped_usec,
		"duplication_ratio": 1.0,
		"template_cache_key": str(template.get("cache_key", "")),
	}
	return {
		"mesh": mesh,
		"sample_stats": sample_stats,
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
