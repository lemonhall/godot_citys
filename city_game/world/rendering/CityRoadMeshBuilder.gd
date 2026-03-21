extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

static var _shared_unit_box_mesh: BoxMesh = null
static var _material_cache: Dictionary = {}

static func build_road_overlay(profile: Dictionary, chunk_data: Dictionary) -> Node3D:
	var road_root := Node3D.new()
	road_root.name = "RoadOverlay"

	var palette: Dictionary = profile.get("palette", {})
	var road_color: Color = palette.get("road", Color(0.16, 0.17, 0.19, 1.0))
	var stripe_color: Color = palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0))
	var support_color: Color = palette.get("mid", Color(0.32, 0.38, 0.44, 1.0))

	var road_segments: Array = profile.get("road_segments", [])
	var bridge_segments := _filter_bridge_segments(road_segments)
	var semantic_stats := _build_semantic_consumer_stats(bridge_segments)
	var road_surface := _build_road_surface_mesh(bridge_segments, road_color, false)
	if road_surface != null:
		road_root.add_child(road_surface)

	var stripe_surface := _build_road_surface_mesh(bridge_segments, stripe_color, true)
	if stripe_surface != null:
		road_root.add_child(stripe_surface)

	var collision_root := _build_collision_bodies(bridge_segments)
	road_root.add_child(collision_root)
	road_root.set_meta("road_collision_shape_count", int(collision_root.get_meta("road_collision_shape_count", 0)))
	road_root.set_meta("bridge_collision_shape_count", int(collision_root.get_meta("bridge_collision_shape_count", 0)))

	var supports := _build_bridge_supports(bridge_segments, chunk_data, support_color)
	if supports != null:
		road_root.add_child(supports)
	road_root.set_meta("road_semantic_stats", semantic_stats)

	return road_root

static func build_bridge_proxy(profile: Dictionary, _chunk_data: Dictionary) -> Node3D:
	var palette: Dictionary = profile.get("palette", {})
	var road_color: Color = palette.get("road", Color(0.16, 0.17, 0.19, 1.0))
	var bridge_segments := _filter_bridge_segments(profile.get("road_segments", []))
	if bridge_segments.is_empty():
		return null

	var proxy_root := Node3D.new()
	proxy_root.name = "BridgeProxy"
	var deck_proxy := _build_bridge_proxy_decks(bridge_segments, road_color)
	if deck_proxy != null:
		proxy_root.add_child(deck_proxy)
	return proxy_root if proxy_root.get_child_count() > 0 else null

static func _build_bridge_proxy_decks(road_segments: Array, color: Color) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	for segment_variant in road_segments:
		var segment_dict: Dictionary = segment_variant
		var points: Array = segment_dict.get("points", [])
		if points.size() < 2:
			continue
		var width := _resolve_surface_width_m(segment_dict)
		var thickness := maxf(float(segment_dict.get("deck_thickness_m", 0.4)) * 0.7, 0.35)
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var segment_length := a.distance_to(b)
			if segment_length <= 0.001:
				continue
			var transform := _build_segment_transform(a, b, thickness)
			transform.basis = transform.basis.scaled(Vector3(width, 1.0, maxf(segment_length + width * 0.2, width)))
			transforms.append(transform)
	if transforms.is_empty():
		return null

	var instance := MultiMeshInstance3D.new()
	instance.name = "BridgeDeckProxy"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _get_shared_unit_box_mesh()
	multimesh.instance_count = transforms.size()
	for transform_index in range(transforms.size()):
		multimesh.set_instance_transform(transform_index, transforms[transform_index])
	instance.multimesh = multimesh

	instance.material_override = _get_cached_material(color, false)
	return instance

static func _filter_bridge_segments(road_segments: Array) -> Array:
	var bridge_segments: Array = []
	for road_segment in road_segments:
		var segment_dict: Dictionary = road_segment
		if bool(segment_dict.get("bridge", false)):
			bridge_segments.append(segment_dict)
	return bridge_segments

static func _build_road_surface_mesh(road_segments: Array, color: Color, stripe_only: bool) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_geometry := false

	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var points: Array = segment_dict.get("points", [])
		if points.size() < 2:
			continue
		var width := _resolve_marking_width_m(segment_dict) if stripe_only else _resolve_surface_width_m(segment_dict)
		if width <= 0.0:
			continue
		if stripe_only and _resolve_marking_half_width_m(segment_dict) <= 0.0:
			continue
		var thickness := 0.05 if stripe_only else float(segment_dict.get("deck_thickness_m", 0.4))
		if _append_roadbed(surface_tool, points, width, thickness, stripe_only):
			has_geometry = true

	var intersections := _build_intersection_clusters(road_segments)
	for cluster in intersections:
		var cluster_dict: Dictionary = cluster
		var radius := 1.4 if stripe_only else float(cluster_dict.get("radius", 0.0))
		if radius <= 0.0:
			continue
		_append_intersection_cap(
			surface_tool,
			cluster_dict.get("center", Vector3.ZERO),
			radius if not stripe_only else minf(radius * 0.28, 1.6),
			0.02 if stripe_only else float(cluster_dict.get("thickness", 0.4)),
			stripe_only
		)
		has_geometry = true

	if not has_geometry:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RoadStripe" if stripe_only else "RoadSurface"
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.material_override = _get_cached_material(color, true)
	return mesh_instance

static func _append_roadbed(surface_tool: SurfaceTool, points: Array, width: float, thickness: float, top_only: bool) -> bool:
	if points.size() < 2:
		return false
	var strip := _build_strip(points, width)
	var left_points: Array = strip.get("left", [])
	var right_points: Array = strip.get("right", [])
	if left_points.size() != points.size() or right_points.size() != points.size():
		return false

	var bottom_left: Array[Vector3] = []
	var bottom_right: Array[Vector3] = []
	for point_index in range(left_points.size()):
		var left_point: Vector3 = left_points[point_index]
		var right_point: Vector3 = right_points[point_index]
		bottom_left.append(left_point - Vector3.UP * thickness)
		bottom_right.append(right_point - Vector3.UP * thickness)

	var total_length := 0.0
	for point_index in range(points.size() - 1):
		var segment_length := (points[point_index] as Vector3).distance_to(points[point_index + 1] as Vector3)
		var next_length := total_length + segment_length
		_add_quad(surface_tool, left_points[point_index], right_points[point_index], left_points[point_index + 1], right_points[point_index + 1], total_length, next_length)
		if not top_only:
			_add_quad(surface_tool, bottom_right[point_index], bottom_left[point_index], bottom_right[point_index + 1], bottom_left[point_index + 1], total_length, next_length)
			_add_quad(surface_tool, left_points[point_index], bottom_left[point_index], left_points[point_index + 1], bottom_left[point_index + 1], total_length, next_length)
			_add_quad(surface_tool, bottom_right[point_index], right_points[point_index], bottom_right[point_index + 1], right_points[point_index + 1], total_length, next_length)
		total_length = next_length

	if not top_only:
		_add_end_cap(surface_tool, left_points[0], right_points[0], bottom_left[0], bottom_right[0])
		_add_end_cap(surface_tool, right_points[-1], left_points[-1], bottom_right[-1], bottom_left[-1])
	return true

static func _build_strip(points: Array, width: float) -> Dictionary:
	var left_points: Array[Vector3] = []
	var right_points: Array[Vector3] = []
	var half_width := width * 0.5
	for point_index in range(points.size()):
		var offset := _sample_miter_offset(points, point_index, half_width)
		var point: Vector3 = points[point_index]
		left_points.append(point + offset)
		right_points.append(point - offset)
	return {
		"left": left_points,
		"right": right_points,
	}

static func _sample_miter_offset(points: Array, point_index: int, half_width: float) -> Vector3:
	var prev_dir := Vector2.ZERO
	var next_dir := Vector2.ZERO
	if point_index > 0:
		var prev_point: Vector3 = points[point_index - 1]
		var point: Vector3 = points[point_index]
		prev_dir = Vector2(point.x - prev_point.x, point.z - prev_point.z).normalized()
	if point_index + 1 < points.size():
		var point_current: Vector3 = points[point_index]
		var point_next: Vector3 = points[point_index + 1]
		next_dir = Vector2(point_next.x - point_current.x, point_next.z - point_current.z).normalized()

	if prev_dir == Vector2.ZERO:
		prev_dir = next_dir
	if next_dir == Vector2.ZERO:
		next_dir = prev_dir

	var prev_normal := Vector2(-prev_dir.y, prev_dir.x)
	var next_normal := Vector2(-next_dir.y, next_dir.x)
	var miter := prev_normal + next_normal
	if miter.length() <= 0.001:
		miter = next_normal
	else:
		miter = miter.normalized()
	var denominator := maxf(miter.dot(next_normal), 0.35)
	var scale := minf(half_width / denominator, half_width * 1.9)
	return Vector3(miter.x * scale, 0.0, miter.y * scale)

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

static func _add_end_cap(surface_tool: SurfaceTool, top_a: Vector3, top_b: Vector3, bottom_a: Vector3, bottom_b: Vector3) -> void:
	surface_tool.set_uv(Vector2.ZERO)
	surface_tool.add_vertex(top_a)
	surface_tool.set_uv(Vector2.RIGHT)
	surface_tool.add_vertex(top_b)
	surface_tool.set_uv(Vector2.UP)
	surface_tool.add_vertex(bottom_a)

	surface_tool.set_uv(Vector2.UP)
	surface_tool.add_vertex(bottom_a)
	surface_tool.set_uv(Vector2.RIGHT)
	surface_tool.add_vertex(top_b)
	surface_tool.set_uv(Vector2.ONE)
	surface_tool.add_vertex(bottom_b)

static func _build_intersection_clusters(road_segments: Array) -> Array[Dictionary]:
	var clusters: Dictionary = {}
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var points: Array = segment_dict.get("points", [])
		if points.is_empty():
			continue
		var edge_profile := _resolve_edge_profile(segment_dict)
		var width := _resolve_surface_width_m(segment_dict)
		var surface_half_width_m := width * 0.5
		var median_width_m := float(edge_profile.get("median_width_m", segment_dict.get("median_width_m", 0.0)))
		var thickness := float(segment_dict.get("deck_thickness_m", 0.4))
		var cluster_radius_m := surface_half_width_m * 1.12 + maxf(median_width_m, 0.0) * 0.15
		for endpoint_index in [0, points.size() - 1]:
			var point: Vector3 = points[endpoint_index]
			var key := "%d|%d|%d" % [int(round(point.x * 2.0)), int(round(point.y * 2.0)), int(round(point.z * 2.0))]
			if not clusters.has(key):
				clusters[key] = {
					"center": point,
					"radius": cluster_radius_m,
					"thickness": thickness,
					"count": 0,
					"bridge": bool(segment_dict.get("bridge", false)),
				}
			var cluster: Dictionary = clusters[key]
			cluster["radius"] = maxf(float(cluster.get("radius", 0.0)), cluster_radius_m)
			cluster["thickness"] = maxf(float(cluster.get("thickness", 0.0)), thickness)
			cluster["count"] = int(cluster.get("count", 0)) + 1
			cluster["bridge"] = bool(cluster.get("bridge", false)) or bool(segment_dict.get("bridge", false))
			clusters[key] = cluster
	var results: Array[Dictionary] = []
	for cluster in clusters.values():
		var cluster_dict: Dictionary = cluster
		if int(cluster_dict.get("count", 0)) >= 2:
			results.append(cluster_dict)
	return results

static func _append_intersection_cap(surface_tool: SurfaceTool, center: Vector3, radius: float, thickness: float, top_only: bool) -> void:
	var segments := 10
	var top_center := center + Vector3.UP * 0.015
	var bottom_center := center - Vector3.UP * thickness
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var top_a := top_center + Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius)
		var top_b := top_center + Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius)
		surface_tool.set_uv(Vector2(0.5, 0.5))
		surface_tool.add_vertex(top_center)
		surface_tool.set_uv(Vector2(0.0, 0.0))
		surface_tool.add_vertex(top_a)
		surface_tool.set_uv(Vector2(1.0, 0.0))
		surface_tool.add_vertex(top_b)
		if top_only:
			continue
		var bottom_a := bottom_center + Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius)
		var bottom_b := bottom_center + Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius)
		_add_quad(surface_tool, top_a, bottom_a, top_b, bottom_b, 0.0, 1.0)

static func _build_collision_bodies(road_segments: Array) -> Node3D:
	var collision_root := Node3D.new()
	collision_root.name = "RoadCollisions"
	var road_collision_shape_count := 0
	var bridge_collision_shape_count := 0
	var body_index := 0

	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var points: Array = segment_dict.get("points", [])
		if points.size() < 2:
			continue
		var width := _resolve_surface_width_m(segment_dict)
		var thickness := maxf(float(segment_dict.get("deck_thickness_m", 0.4)), 0.3)
		var is_bridge := bool(segment_dict.get("bridge", false))
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var body := StaticBody3D.new()
			body.name = "%s_%d" % ["BridgeBody" if is_bridge else "RoadBody", body_index]
			var collision_shape := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			var segment_length := a.distance_to(b)
			shape.size = Vector3(width, thickness, maxf(segment_length + width * 0.35, width))
			collision_shape.shape = shape
			body.transform = _build_segment_transform(a, b, thickness)
			body.add_child(collision_shape)
			collision_root.add_child(body)
			road_collision_shape_count += 1
			if is_bridge:
				bridge_collision_shape_count += 1
			body_index += 1
	var intersection_index := 0
	for cluster in _build_intersection_clusters(road_segments):
		var cluster_dict: Dictionary = cluster
		var body := StaticBody3D.new()
		body.name = "IntersectionBody_%d" % intersection_index
		var collision_shape := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = maxf(float(cluster_dict.get("thickness", 0.4)), 0.3)
		shape.radius = float(cluster_dict.get("radius", 1.0))
		collision_shape.shape = shape
		body.position = cluster_dict.get("center", Vector3.ZERO) - Vector3.UP * shape.height * 0.5
		body.add_child(collision_shape)
		collision_root.add_child(body)
		road_collision_shape_count += 1
		if bool(cluster_dict.get("bridge", false)):
			bridge_collision_shape_count += 1
		intersection_index += 1
	collision_root.set_meta("road_collision_shape_count", road_collision_shape_count)
	collision_root.set_meta("bridge_collision_shape_count", bridge_collision_shape_count)
	return collision_root

static func _build_semantic_consumer_stats(road_segments: Array) -> Dictionary:
	var semantic_surface_width_segment_count := 0
	var semantic_marking_segment_count := 0
	var semantic_median_segment_count := 0
	var semantic_marking_profile_counts: Dictionary = {}
	for road_segment in road_segments:
		var segment_dict: Dictionary = road_segment
		var edge_profile := _resolve_edge_profile(segment_dict)
		if float(edge_profile.get("surface_half_width_m", 0.0)) > 0.0:
			semantic_surface_width_segment_count += 1
		if edge_profile.has("median_width_m"):
			semantic_median_segment_count += 1
		var marking_profile_id := _resolve_marking_profile_id(segment_dict)
		if marking_profile_id != "":
			semantic_marking_segment_count += 1
			semantic_marking_profile_counts[marking_profile_id] = int(semantic_marking_profile_counts.get(marking_profile_id, 0)) + 1
	return {
		"semantic_surface_width_segment_count": semantic_surface_width_segment_count,
		"semantic_marking_segment_count": semantic_marking_segment_count,
		"semantic_median_segment_count": semantic_median_segment_count,
		"semantic_marking_profile_counts": semantic_marking_profile_counts,
	}

static func _resolve_section_semantics(segment_dict: Dictionary) -> Dictionary:
	return (segment_dict.get("section_semantics", {}) as Dictionary)

static func _resolve_edge_profile(segment_dict: Dictionary) -> Dictionary:
	var section_semantics := _resolve_section_semantics(segment_dict)
	return (section_semantics.get("edge_profile", {}) as Dictionary)

static func _resolve_surface_width_m(segment_dict: Dictionary) -> float:
	var edge_profile := _resolve_edge_profile(segment_dict)
	var semantic_half_width_m := float(edge_profile.get("surface_half_width_m", 0.0))
	if semantic_half_width_m > 0.0:
		return semantic_half_width_m * 2.0
	var semantic_width_m := float(_resolve_section_semantics(segment_dict).get("width_m", 0.0))
	if semantic_width_m > 0.0:
		return semantic_width_m
	return float(segment_dict.get("width", 11.0))

static func _resolve_marking_profile_id(segment_dict: Dictionary) -> String:
	var section_semantics := _resolve_section_semantics(segment_dict)
	var marking_profile_id := str(section_semantics.get("marking_profile_id", ""))
	if marking_profile_id != "":
		return marking_profile_id
	match str(segment_dict.get("template_id", "local")):
		"expressway_elevated":
			return "expressway_divided"
		"arterial":
			return "arterial_divided"
		"service":
			return "service_single_edge"
		_:
			return "local_centerline"

static func _resolve_marking_half_width_m(segment_dict: Dictionary) -> float:
	match _resolve_marking_profile_id(segment_dict):
		"expressway_divided":
			return 0.34
		"arterial_divided":
			return 0.28
		"local_centerline":
			return 0.22
		_:
			return 0.0

static func _resolve_marking_width_m(segment_dict: Dictionary) -> float:
	return _resolve_marking_half_width_m(segment_dict) * 2.0

static func _build_segment_transform(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var direction := b - a
	var length := direction.length()
	if length <= 0.001:
		return Transform3D(Basis.IDENTITY, a)
	var forward := direction / length
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var right := up.cross(forward).normalized()
	var corrected_up := forward.cross(right).normalized()
	var basis := Basis(right, corrected_up, forward)
	var origin := a.lerp(b, 0.5) - corrected_up * thickness * 0.5
	return Transform3D(basis, origin)

static func _build_bridge_supports(road_segments: Array, chunk_data: Dictionary, color: Color) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		if not bool(segment_dict.get("bridge", false)):
			continue
		var points: Array = segment_dict.get("points", [])
		var bridge_range: Vector2 = segment_dict.get("bridge_range", Vector2(0.2, 0.8))
		for sample in _sample_bridge_support_positions(points, bridge_range):
			var support_position: Vector3 = sample
			var ground_y := CityTerrainSampler.GROUND_HEIGHT_Y
			var support_height := maxf(support_position.y - float(segment_dict.get("deck_thickness_m", 0.8)) - ground_y, 0.0)
			if support_height < 3.0:
				continue
			var scale := Vector3(1.2, support_height * 0.5, 1.2)
			var basis := Basis.IDENTITY.scaled(scale)
			var origin := Vector3(support_position.x, ground_y + support_height * 0.5, support_position.z)
			transforms.append(Transform3D(basis, origin))
	if transforms.is_empty():
		return null

	var instance := MultiMeshInstance3D.new()
	instance.name = "BridgeSupports"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _get_shared_unit_box_mesh()
	multimesh.instance_count = transforms.size()
	for transform_index in range(transforms.size()):
		multimesh.set_instance_transform(transform_index, transforms[transform_index])
	instance.multimesh = multimesh

	instance.material_override = _get_cached_material(color, false)
	return instance

static func _sample_bridge_support_positions(points: Array, bridge_range: Vector2) -> Array[Vector3]:
	var supports: Array[Vector3] = []
	if points.size() < 3:
		return supports
	var ratios := [bridge_range.x + (bridge_range.y - bridge_range.x) * 0.18, bridge_range.x + (bridge_range.y - bridge_range.x) * 0.5, bridge_range.x + (bridge_range.y - bridge_range.x) * 0.82]
	for ratio in ratios:
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

static func _get_shared_unit_box_mesh() -> BoxMesh:
	if _shared_unit_box_mesh == null:
		_shared_unit_box_mesh = BoxMesh.new()
		_shared_unit_box_mesh.size = Vector3.ONE
	return _shared_unit_box_mesh

static func _get_cached_material(color: Color, cull_disabled: bool) -> StandardMaterial3D:
	var cache_key := "%s|%s" % [_color_cache_key(color), "cull_off" if cull_disabled else "cull_on"]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	if cull_disabled:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[cache_key] = material
	return material

static func _color_cache_key(color: Color) -> String:
	return "%.4f|%.4f|%.4f|%.4f" % [color.r, color.g, color.b, color.a]
