extends RefCounted

# Street-level dressing for the v62 city: sidewalks with curbs and street trees.
# One merged mesh per chunk for the paving, one MultiMesh for the trees.

const CityRoadMeshBuilder := preload("res://city_game/world/rendering/CityRoadMeshBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")
const CityBuildingMeshBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMeshBuilder.gd")

const SIDEWALK_WIDTH_M := 3.4
const SIDEWALK_HEIGHT_M := 0.16
const CURB_HEIGHT_M := 0.02
const TREE_SPACING_POINTS := 1
const TREE_OFFSET_M := 3.9

static var _sidewalk_material: StandardMaterial3D = null
static var _trunk_material: StandardMaterial3D = null
static var _canopy_material: StandardMaterial3D = null
static var _tree_mesh_cache: ArrayMesh = null

static func build(profile: Dictionary, chunk_data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "StreetDressing"
	var segments: Array = profile.get("road_segments", [])
	if segments.is_empty():
		return root
	var sidewalk_mesh := _build_sidewalk_mesh(segments)
	if sidewalk_mesh != null:
		var sidewalk_instance := MeshInstance3D.new()
		sidewalk_instance.name = "Sidewalks"
		sidewalk_instance.mesh = sidewalk_mesh
		sidewalk_instance.material_override = _shared_sidewalk_material()
		sidewalk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sidewalk_instance)
	var trees := _build_trees(segments, profile.get("buildings", []), int(chunk_data.get("chunk_seed", 0)))
	if trees != null:
		root.add_child(trees)
	var furniture := _build_street_furniture(segments, profile.get("buildings", []), int(chunk_data.get("chunk_seed", 0)))
	if furniture != null:
		root.add_child(furniture)
	return root

static func _build_sidewalk_mesh(segments: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad_count := 0
	for segment_index in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var points: Array = segment.get("points", [])
		if points.size() < 2:
			continue
		var width := float(CityRoadMeshBuilder._resolve_surface_width_m(segment))
		if width <= 0.0:
			continue
		var inner_strip: Dictionary = CityRoadMeshBuilder._build_strip(points, width)
		var outer_strip: Dictionary = CityRoadMeshBuilder._build_strip(points, width + SIDEWALK_WIDTH_M * 2.0)
		var inner_left: Array = inner_strip.get("left", [])
		var inner_right: Array = inner_strip.get("right", [])
		var outer_left: Array = outer_strip.get("left", [])
		var outer_right: Array = outer_strip.get("right", [])
		if inner_left.size() != points.size() or outer_left.size() != points.size():
			continue
		var y_offset := SIDEWALK_HEIGHT_M + float(segment_index % 7) * 0.002
		for point_index in range(points.size() - 1):
			var next_index := point_index + 1
			# Left paving strip.
			_add_quad(
				surface,
				_to_top(outer_left[point_index], y_offset),
				_to_top(outer_left[next_index], y_offset),
				_to_top(inner_left[next_index], y_offset),
				_to_top(inner_left[point_index], y_offset),
				Vector3.UP,
				Color(0.28, 0.28, 0.27)
			)
			# Right paving strip.
			_add_quad(
				surface,
				_to_top(inner_right[point_index], y_offset),
				_to_top(inner_right[next_index], y_offset),
				_to_top(outer_right[next_index], y_offset),
				_to_top(outer_right[point_index], y_offset),
				Vector3.UP,
				Color(0.28, 0.28, 0.27)
			)
			# Curbs facing the roadway.
			var left_center: Vector3 = points[point_index]
			var left_inward := (left_center - (inner_left[point_index] as Vector3))
			left_inward.y = 0.0
			left_inward = left_inward.normalized()
			_add_quad(
				surface,
				_to_top(inner_left[point_index], y_offset),
				_to_top(inner_left[next_index], y_offset),
				_to_top(inner_left[next_index], CURB_HEIGHT_M),
				_to_top(inner_left[point_index], CURB_HEIGHT_M),
				left_inward,
				Color(0.20, 0.20, 0.20)
			)
			var right_center: Vector3 = points[point_index]
			var right_inward := (right_center - (inner_right[point_index] as Vector3))
			right_inward.y = 0.0
			right_inward = right_inward.normalized()
			_add_quad(
				surface,
				_to_top(inner_right[next_index], y_offset),
				_to_top(inner_right[point_index], y_offset),
				_to_top(inner_right[point_index], CURB_HEIGHT_M),
				_to_top(inner_right[next_index], CURB_HEIGHT_M),
				right_inward,
				Color(0.20, 0.20, 0.20)
			)
			quad_count += 4
	if quad_count == 0:
		return null
	surface.generate_normals()
	return surface.commit()

static func _build_trees(segments: Array, buildings: Array, chunk_seed: int) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed ^ 0x51DE
	for segment in segments:
		var points: Array = segment.get("points", [])
		if points.size() < 3:
			continue
		var width := float(CityRoadMeshBuilder._resolve_surface_width_m(segment))
		var offset := width * 0.5 + TREE_OFFSET_M
		for point_index in range(1, points.size() - 1, TREE_SPACING_POINTS):
			var point: Vector3 = points[point_index]
			var miter := CityRoadMeshBuilder._sample_miter_offset(points, point_index, offset)
			for side in [-1.0, 1.0]:
				var position: Vector3 = point + miter * side
				if _is_blocked(position, buildings):
					continue
				var scale_value := rng.randf_range(0.85, 1.25)
				var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_value, scale_value, scale_value))
				transforms.append(Transform3D(basis, position))
	if transforms.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _tree_mesh()
	multimesh.instance_count = transforms.size()
	for instance_index in range(transforms.size()):
		multimesh.set_instance_transform(instance_index, transforms[instance_index])
		var tint := 0.88 + 0.16 * float((instance_index * 37) % 100) / 100.0
		multimesh.set_instance_color(instance_index, Color(tint, tint * 1.04, tint * 0.95))
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetTrees"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

static func _is_blocked(position: Vector3, buildings: Array) -> bool:
	for building_variant in buildings:
		var building: Dictionary = building_variant
		var center: Vector2 = building.get("center_2d", Vector2.ZERO)
		var radius := float(building.get("visual_footprint_radius_m", building.get("footprint_radius_m", 0.0)))
		if Vector2(position.x, position.z).distance_to(center) < radius * 0.55 + 0.8:
			return true
	return false

static func _tree_mesh() -> ArrayMesh:
	if _tree_mesh_cache != null:
		return _tree_mesh_cache
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.27
	trunk.height = 4.2
	trunk.radial_segments = 6
	trunk.rings = 1
	var trunk_tool := SurfaceTool.new()
	trunk_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	trunk_tool.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)))
	trunk_tool.generate_normals()
	trunk_tool.commit(mesh)
	mesh.surface_set_material(0, _shared_trunk_material())
	var canopy_tool := SurfaceTool.new()
	canopy_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var canopy_low := SphereMesh.new()
	canopy_low.radius = 3.0
	canopy_low.height = 4.2
	canopy_low.radial_segments = 7
	canopy_low.rings = 4
	canopy_tool.append_from(canopy_low, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.2, 0.0)))
	var canopy_high := SphereMesh.new()
	canopy_high.radius = 2.1
	canopy_high.height = 2.8
	canopy_high.radial_segments = 6
	canopy_high.rings = 3
	canopy_tool.append_from(canopy_high, 0, Transform3D(Basis.IDENTITY, Vector3(0.6, 6.8, -0.5)))
	canopy_tool.generate_normals()
	canopy_tool.commit(mesh)
	mesh.surface_set_material(1, _shared_canopy_material())
	_tree_mesh_cache = mesh
	return mesh

static func _shared_sidewalk_material() -> StandardMaterial3D:
	if _sidewalk_material == null:
		_sidewalk_material = StandardMaterial3D.new()
		_sidewalk_material.vertex_color_use_as_albedo = true
		_sidewalk_material.roughness = 0.92
		_sidewalk_material.metallic_specular = 0.2
	return _sidewalk_material

static func _shared_trunk_material() -> StandardMaterial3D:
	if _trunk_material == null:
		_trunk_material = StandardMaterial3D.new()
		_trunk_material.albedo_color = Color(0.26, 0.20, 0.15, 1.0)
		_trunk_material.roughness = 0.95
		_trunk_material.vertex_color_use_as_albedo = true
	return _trunk_material

static func _shared_canopy_material() -> StandardMaterial3D:
	if _canopy_material == null:
		_canopy_material = StandardMaterial3D.new()
		_canopy_material.albedo_color = Color(0.20, 0.38, 0.17, 1.0)
		_canopy_material.roughness = 0.9
		_canopy_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_canopy_material.vertex_color_use_as_albedo = true
	return _canopy_material

static func _to_top(point: Vector3, y_offset: float) -> Vector3:
	return Vector3(point.x, CityTerrainSampler.GROUND_HEIGHT_Y + y_offset, point.z)

# ---------------------------------------------------------------------------
# Street furniture: benches and bins along the sidewalks.
# ---------------------------------------------------------------------------

static var _furniture_material: StandardMaterial3D = null
static var _bench_mesh_cache: ArrayMesh = null
static var _bin_mesh_cache: ArrayMesh = null

static func _build_street_furniture(segments: Array, buildings: Array, chunk_seed: int) -> Node3D:
	var benches: Array[Transform3D] = []
	var bins: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed ^ 0x7A11
	for segment in segments:
		var points: Array = segment.get("points", [])
		if points.size() < 3:
			continue
		var width := float(CityRoadMeshBuilder._resolve_surface_width_m(segment))
		var offset := width * 0.5 + 1.15
		for point_index in range(1, points.size() - 1, 2):
			var point: Vector3 = points[point_index]
			var next_point: Vector3 = points[point_index + 1]
			var tangent := (next_point - point)
			tangent.y = 0.0
			if tangent.length_squared() < 0.0001:
				continue
			tangent = tangent.normalized()
			var miter := CityRoadMeshBuilder._sample_miter_offset(points, point_index, offset)
			for side in [-1.0, 1.0]:
				var position: Vector3 = point + miter * side
				if _is_blocked(position, buildings):
					continue
				var yaw := atan2(-tangent.z, tangent.x)
				var basis := Basis(Vector3.UP, yaw)
				if side < 0.0:
					benches.append(Transform3D(basis, position))
				else:
					bins.append(Transform3D(basis, position))
	# Guarantee furniture at every segment midpoint too: point-only placement can
	# leave long straight roads completely bare between vertices.
	for segment in segments:
		var mid_points: Array = segment.get("points", [])
		if mid_points.size() < 2:
			continue
		var mid_width := float(CityRoadMeshBuilder._resolve_surface_width_m(segment))
		var mid_offset := mid_width * 0.5 + 1.25
		for pair_index in range(mid_points.size() - 1):
			var a: Vector3 = mid_points[pair_index]
			var b: Vector3 = mid_points[pair_index + 1]
			var mid := (a + b) * 0.5
			var tangent := b - a
			tangent.y = 0.0
			if tangent.length_squared() < 0.0001:
				continue
			tangent = tangent.normalized()
			var normal := Vector3(-tangent.z, 0.0, tangent.x)
			var mid_basis := Basis(Vector3.UP, atan2(-tangent.z, tangent.x))
			benches.append(Transform3D(mid_basis, mid + normal * mid_offset))
			bins.append(Transform3D(mid_basis, mid - normal * mid_offset))
	var root := Node3D.new()
	root.name = "StreetFurniture"
	var bench_node := _build_furniture_batch("Benches", benches, _bench_mesh())
	if bench_node != null:
		root.add_child(bench_node)
	var bin_node := _build_furniture_batch("Bins", bins, _bin_mesh())
	if bin_node != null:
		root.add_child(bin_node)
	return root if root.get_child_count() > 0 else null

static func _build_furniture_batch(node_name: String, transforms: Array[Transform3D], mesh: ArrayMesh) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for instance_index in range(transforms.size()):
		multimesh.set_instance_transform(instance_index, transforms[instance_index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

static func _bench_mesh() -> ArrayMesh:
	if _bench_mesh_cache != null:
		return _bench_mesh_cache
	var builder := CityBuildingMeshBuilder.new()
	var wood := Color(0.36, 0.25, 0.16).srgb_to_linear()
	var metal := Color(0.12, 0.13, 0.14).srgb_to_linear()
	builder.add_box(Vector3(0.0, 0.66, 0.0), Vector3(2.2, 0.12, 0.55), wood)
	builder.add_box(Vector3(0.0, 0.98, 0.24), Vector3(2.2, 0.50, 0.10), wood)
	builder.add_box(Vector3(-0.90, 0.33, 0.0), Vector3(0.12, 0.66, 0.50), metal)
	builder.add_box(Vector3(0.90, 0.33, 0.0), Vector3(0.12, 0.66, 0.50), metal)
	var mesh := builder.commit(_shared_furniture_material())
	_bench_mesh_cache = mesh
	return mesh

static func _bin_mesh() -> ArrayMesh:
	if _bin_mesh_cache != null:
		return _bin_mesh_cache
	var builder := CityBuildingMeshBuilder.new()
	var body := Color(0.16, 0.24, 0.18).srgb_to_linear()
	var lid := Color(0.10, 0.11, 0.11).srgb_to_linear()
	builder.add_box(Vector3(0.0, 0.55, 0.0), Vector3(0.62, 1.10, 0.62), body)
	builder.add_box(Vector3(0.0, 1.13, 0.0), Vector3(0.68, 0.10, 0.68), lid)
	var mesh := builder.commit(_shared_furniture_material())
	_bin_mesh_cache = mesh
	return mesh

static func _shared_furniture_material() -> StandardMaterial3D:
	if _furniture_material == null:
		_furniture_material = StandardMaterial3D.new()
		_furniture_material.vertex_color_use_as_albedo = true
		_furniture_material.roughness = 0.82
	return _furniture_material

static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var cross := (b - a).cross(c - a)
	surface.set_color(color)
	if cross.dot(normal) > 0.0:
		# Counter-clockwise as seen from the normal side: reverse for Godot's
		# clockwise front-face convention.
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(b)
		surface.add_vertex(a)
		surface.add_vertex(d)
		surface.add_vertex(c)
	else:
		surface.add_vertex(a)
		surface.add_vertex(b)
		surface.add_vertex(c)
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(d)
