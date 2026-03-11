extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

static func build_road_overlay(profile: Dictionary, chunk_data: Dictionary) -> Node3D:
	var road_root := Node3D.new()
	road_root.name = "RoadOverlay"

	var palette: Dictionary = profile.get("palette", {})
	var road_color: Color = palette.get("road", Color(0.16, 0.17, 0.19, 1.0))
	var stripe_color: Color = palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0))
	var support_color: Color = palette.get("mid", Color(0.32, 0.38, 0.44, 1.0))

	var road_surface := _build_ribbon_instance("RoadSurface", profile.get("road_segments", []), road_color, 0.08, 0.0, false)
	if road_surface != null:
		road_root.add_child(road_surface)

	var stripe_surface := _build_ribbon_instance("RoadStripe", profile.get("road_segments", []), stripe_color, 0.02, 0.11, true)
	if stripe_surface != null:
		road_root.add_child(stripe_surface)

	var supports := _build_bridge_supports(profile.get("road_segments", []), chunk_data, support_color)
	if supports != null:
		road_root.add_child(supports)

	return road_root

static func _build_ribbon_instance(name: String, road_segments: Array, color: Color, height: float, y_offset: float, stripe_only: bool) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_geometry := false
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var road_class := str(segment_dict.get("class", "local"))
		if stripe_only and road_class != "arterial" and road_class != "collector":
			continue
		var width := 0.8 if stripe_only else float(segment_dict.get("width", 8.0))
		var points: Array = segment_dict.get("points", [])
		if _append_ribbon(surface_tool, points, width, y_offset):
			has_geometry = true
	if not has_geometry:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	mesh_instance.material_override = material
	return mesh_instance

static func _append_ribbon(surface_tool: SurfaceTool, points: Array, width: float, y_offset: float) -> bool:
	if points.size() < 2:
		return false
	var left_points: Array[Vector3] = []
	var right_points: Array[Vector3] = []
	for point_index in range(points.size()):
		var point: Vector3 = points[point_index]
		var tangent := _sample_tangent(points, point_index)
		if tangent.length() <= 0.001:
			return false
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var offset := Vector3(normal.x * width * 0.5, y_offset, normal.y * width * 0.5)
		left_points.append(point + offset)
		right_points.append(point - offset)

	var total_length := 0.0
	for point_index in range(points.size() - 1):
		var a_left: Vector3 = left_points[point_index]
		var a_right: Vector3 = right_points[point_index]
		var b_left: Vector3 = left_points[point_index + 1]
		var b_right: Vector3 = right_points[point_index + 1]
		var segment_length: float = (points[point_index] as Vector3).distance_to(points[point_index + 1] as Vector3)
		var next_length: float = total_length + segment_length
		_add_quad(surface_tool, a_left, a_right, b_left, b_right, total_length, next_length)
		total_length = next_length
	return true

static func _sample_tangent(points: Array, point_index: int) -> Vector2:
	var tangent := Vector2.ZERO
	if point_index > 0:
		var prev: Vector3 = points[point_index - 1]
		var point: Vector3 = points[point_index]
		tangent += Vector2(point.x - prev.x, point.z - prev.z).normalized()
	if point_index + 1 < points.size():
		var point_next: Vector3 = points[point_index + 1]
		var point_current: Vector3 = points[point_index]
		tangent += Vector2(point_next.x - point_current.x, point_next.z - point_current.z).normalized()
	if tangent.length() <= 0.001 and point_index + 1 < points.size():
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		tangent = Vector2(b.x - a.x, b.z - a.z)
	return tangent.normalized()

static func _add_quad(surface_tool: SurfaceTool, a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3, u_start: float, u_end: float) -> void:
	surface_tool.set_uv(Vector2(u_start, 0.0))
	surface_tool.add_vertex(a_left)
	surface_tool.set_uv(Vector2(u_start, 1.0))
	surface_tool.add_vertex(a_right)
	surface_tool.set_uv(Vector2(u_end, 0.0))
	surface_tool.add_vertex(b_left)

	surface_tool.set_uv(Vector2(u_end, 0.0))
	surface_tool.add_vertex(b_left)
	surface_tool.set_uv(Vector2(u_start, 1.0))
	surface_tool.add_vertex(a_right)
	surface_tool.set_uv(Vector2(u_end, 1.0))
	surface_tool.add_vertex(b_right)

static func _build_bridge_supports(road_segments: Array, chunk_data: Dictionary, color: Color) -> MultiMeshInstance3D:
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var world_seed := int(chunk_data.get("world_seed", 0))
	var transforms: Array[Transform3D] = []
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		if not bool(segment_dict.get("bridge", false)):
			continue
		var points: Array = segment_dict.get("points", [])
		for sample in _sample_bridge_support_positions(points):
			var support_position: Vector3 = sample
			var world_x := chunk_center.x + support_position.x
			var world_z := chunk_center.z + support_position.z
			var ground_y := CityTerrainSampler.sample_height(world_x, world_z, world_seed)
			var support_height := maxf(support_position.y - ground_y, 0.0)
			if support_height < 2.0:
				continue
			var scale := Vector3(0.9, support_height * 0.5, 0.9)
			var basis := Basis.IDENTITY.scaled(scale)
			var origin := Vector3(support_position.x, ground_y + support_height * 0.5, support_position.z)
			transforms.append(Transform3D(basis, origin))
	if transforms.is_empty():
		return null

	var instance := MultiMeshInstance3D.new()
	instance.name = "BridgeSupports"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for transform_index in range(transforms.size()):
		multimesh.set_instance_transform(transform_index, transforms[transform_index])
	instance.multimesh = multimesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	instance.material_override = material
	return instance

static func _sample_bridge_support_positions(points: Array) -> Array[Vector3]:
	var supports: Array[Vector3] = []
	if points.size() < 3:
		return supports
	for ratio in [0.22, 0.5, 0.78]:
		supports.append(_sample_polyline(points, float(ratio)))
	return supports

static func _sample_polyline(points: Array, ratio: float) -> Vector3:
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index] as Vector3).distance_to(points[point_index + 1] as Vector3)
	if total_length <= 0.001:
		return points[0]
	var target := total_length * clampf(ratio, 0.0, 1.0)
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target and segment_length > 0.001:
			return a.lerp(b, (target - traversed) / segment_length)
		traversed += segment_length
	return points[-1]
