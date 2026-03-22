extends RefCounted

const CityLakeRegionDefinition := preload("res://city_game/world/features/lake/CityLakeRegionDefinition.gd")
const CityTerrainGridTemplate := preload("res://city_game/world/rendering/CityTerrainGridTemplate.gd")
const CityTerrainMeshBuilder := preload("res://city_game/world/rendering/CityTerrainMeshBuilder.gd")

const DEFAULT_GRID_STEPS := 48
const MIN_PATCH_MARGIN_M := 40.0
const EXTRA_PATCH_MARGIN_M := 18.0
const WATER_SURFACE_OFFSET_M := 0.03

static var _shared_ground_material_template: StandardMaterial3D = null
static var _shared_water_surface_material_template: StandardMaterial3D = null

static func build_ground_body(lake_contract: Dictionary, grid_steps: int = DEFAULT_GRID_STEPS) -> StaticBody3D:
	if lake_contract.is_empty():
		return null
	var patch_contract := _build_patch_contract(lake_contract)
	if patch_contract.is_empty():
		return null
	var sample_binding := _build_sample_binding(lake_contract, patch_contract, grid_steps)
	var terrain_mesh_builder := CityTerrainMeshBuilder.new()
	var arrays_result := terrain_mesh_builder.build_profiled_terrain_arrays_from_binding(
		float(patch_contract.get("size_m", 0.0)),
		grid_steps,
		sample_binding
	)
	var terrain_mesh := terrain_mesh_builder.commit_terrain_mesh(arrays_result)
	if terrain_mesh == null:
		return null

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	ground_body.position = patch_contract.get("center_world_position", Vector3.ZERO)
	ground_body.set_meta("city_lake_region_id", str(lake_contract.get("region_id", "")))

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	var collision_faces: PackedVector3Array = arrays_result.get("collision_faces", PackedVector3Array())
	if collision_faces.is_empty():
		collision_faces = terrain_mesh.get_faces()
	if collision_faces.is_empty():
		return null
	shape.set_faces(collision_faces)
	collision_shape.shape = shape
	ground_body.add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = terrain_mesh
	mesh_instance.material_override = _get_ground_material()
	ground_body.add_child(mesh_instance)
	return ground_body

static func build_water_surface_node(entry: Dictionary, local_origin_world_position: Vector3 = Vector3.ZERO, vertical_offset_m: float = WATER_SURFACE_OFFSET_M) -> MeshInstance3D:
	var polygon_world_points: Array = entry.get("polygon_world_points", [])
	if polygon_world_points.size() < 3:
		return null
	var water_level_y_m := float(entry.get("water_level_y_m", 0.0)) + vertical_offset_m
	var polygon_local_points := PackedVector2Array()
	var polygon_vertices: Array[Vector3] = []
	for point_variant in polygon_world_points:
		if not (point_variant is Vector3):
			continue
		var world_point := point_variant as Vector3
		polygon_local_points.append(Vector2(
			world_point.x - local_origin_world_position.x,
			world_point.z - local_origin_world_position.z
		))
		polygon_vertices.append(Vector3(
			world_point.x - local_origin_world_position.x,
			water_level_y_m,
			world_point.z - local_origin_world_position.z
		))
	if polygon_local_points.size() < 3 or polygon_vertices.size() < 3:
		return null
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_local_points)
	if indices.size() < 3:
		return null
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_variant in indices:
		var vertex_index := int(index_variant)
		if vertex_index < 0 or vertex_index >= polygon_vertices.size():
			continue
		var vertex := polygon_vertices[vertex_index]
		surface_tool.set_normal(Vector3.UP)
		surface_tool.set_uv(Vector2(vertex.x, vertex.z))
		surface_tool.add_vertex(vertex)
	var mesh: ArrayMesh = surface_tool.commit()
	if mesh == null:
		return null
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaterSurface"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _get_water_surface_material()
	mesh_instance.set_meta("city_water_surface", true)
	mesh_instance.set_meta("city_water_surface_region_id", str(entry.get("region_id", "")))
	return mesh_instance

static func _build_patch_contract(lake_contract: Dictionary) -> Dictionary:
	var bounds_min: Vector2 = lake_contract.get("polygon_bounds_min", Vector2.ZERO)
	var bounds_max: Vector2 = lake_contract.get("polygon_bounds_max", Vector2.ZERO)
	var span_x := maxf(bounds_max.x - bounds_min.x, 1.0)
	var span_z := maxf(bounds_max.y - bounds_min.y, 1.0)
	var patch_margin_m := maxf(float(lake_contract.get("shore_blend_distance_m", 0.0)) + EXTRA_PATCH_MARGIN_M, MIN_PATCH_MARGIN_M)
	var patch_size_m := maxf(span_x, span_z) + patch_margin_m * 2.0
	var center_world_position := Vector3(
		(bounds_min.x + bounds_max.x) * 0.5,
		float(lake_contract.get("water_level_y_m", 0.0)),
		(bounds_min.y + bounds_max.y) * 0.5
	)
	return {
		"center_world_position": center_world_position,
		"size_m": patch_size_m,
		"margin_m": patch_margin_m,
	}

static func _build_sample_binding(lake_contract: Dictionary, patch_contract: Dictionary, grid_steps: int) -> Dictionary:
	var patch_size_m := float(patch_contract.get("size_m", 0.0))
	var patch_center: Vector3 = patch_contract.get("center_world_position", Vector3.ZERO)
	var template_catalog := CityTerrainGridTemplate.new()
	var template: Dictionary = template_catalog.get_template(patch_size_m, grid_steps)
	var local_points: PackedVector2Array = template.get("local_points", PackedVector2Array())
	var heights := PackedFloat32Array()
	heights.resize(local_points.size())
	for point_index in range(local_points.size()):
		var local_point := local_points[point_index]
		var world_position := Vector3(
			patch_center.x + local_point.x,
			float(lake_contract.get("water_level_y_m", 0.0)),
			patch_center.z + local_point.y
		)
		heights[point_index] = _sample_ground_height(lake_contract, world_position)
	return {
		"heights": heights,
		"normals": _build_normals(heights, grid_steps + 1, patch_size_m),
		"runtime_hit": false,
		"page_contract": {},
		"runtime_key": "lake_basin_%s" % str(lake_contract.get("region_id", "")),
		"chunk_size_m": patch_size_m,
		"sample_stats": {
			"current_vertex_sample_count": heights.size(),
			"unique_vertex_sample_count": heights.size(),
			"duplicate_sample_count": 0,
			"raw_terrain_current_usec": 0,
			"shaped_current_usec": 0,
			"shaped_unique_usec": 0,
			"duplication_ratio": 1.0,
			"template_cache_key": "lake_basin_%s_grid%d" % [str(lake_contract.get("region_id", "")), grid_steps],
		},
	}

static func _sample_ground_height(lake_contract: Dictionary, world_position: Vector3) -> float:
	var water_level_y_m := float(lake_contract.get("water_level_y_m", 0.0))
	var sample: Dictionary = CityLakeRegionDefinition.sample_depth_from_contract(lake_contract, world_position)
	if not bool(sample.get("inside_region", false)):
		return water_level_y_m
	return float(sample.get("floor_y_m", water_level_y_m))

static func _build_normals(heights: PackedFloat32Array, row_stride: int, world_size_m: float) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(heights.size())
	var grid_steps := row_stride - 1
	var cell_size_m := world_size_m / float(maxi(grid_steps, 1))
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

static func _get_ground_material() -> StandardMaterial3D:
	if _shared_ground_material_template == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.36862746, 0.45490196, 0.28235295, 1.0)
		material.roughness = 1.0
		_shared_ground_material_template = material
	return _shared_ground_material_template

static func _get_water_surface_material() -> StandardMaterial3D:
	if _shared_water_surface_material_template == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.16, 0.44, 0.68, 0.72)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.08
		material.metallic = 0.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_shared_water_surface_material_template = material
	return _shared_water_surface_material_template
