extends RefCounted

static var _street_lamp_mesh: BoxMesh = null
static var _street_lamp_material_cache: Dictionary = {}

static func build_street_lamps(profile: Dictionary = {}) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetLamps"

	if _street_lamp_mesh == null:
		_street_lamp_mesh = BoxMesh.new()
		_street_lamp_mesh.size = Vector3(0.28, 5.0, 0.28)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _street_lamp_mesh

	var placements := _collect_lamp_positions(profile.get("road_segments", []), profile.get("buildings", []))
	if placements.is_empty():
		placements = [
			Transform3D(Basis.IDENTITY, Vector3(-18.0, 2.5, -18.0)),
			Transform3D(Basis.IDENTITY, Vector3(18.0, 2.5, 18.0)),
		]

	multimesh.instance_count = placements.size()
	for placement_index in range(placements.size()):
		multimesh.set_instance_transform(placement_index, placements[placement_index])

	instance.multimesh = multimesh
	var palette: Dictionary = profile.get("palette", {})
	if palette.has("accent"):
		var material := _get_street_lamp_material(palette["accent"])
		instance.material_override = material
	instance.set_meta("min_road_clearance_m", _measure_min_road_clearance(placements, profile.get("road_segments", [])))
	return instance

static func _get_street_lamp_material(accent_color: Color) -> StandardMaterial3D:
	var key := "%.4f|%.4f|%.4f|%.4f" % [accent_color.r, accent_color.g, accent_color.b, accent_color.a]
	if _street_lamp_material_cache.has(key):
		return _street_lamp_material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = accent_color
	material.roughness = 0.92
	_street_lamp_material_cache[key] = material
	return material

static func _collect_lamp_positions(road_segments: Array, buildings: Array) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	for segment in road_segments:
		if placements.size() >= 16:
			break
		var segment_dict: Dictionary = segment
		var width := float(segment_dict.get("width", 10.0))
		var points: Array = segment_dict.get("points", [])
		placements.append_array(_sample_segment_lamps(points, width, 56.0 if width >= 12.0 else 68.0, road_segments, buildings))
	return placements

static func _sample_segment_lamps(points: Array, width: float, spacing: float, road_segments: Array, buildings: Array) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	if points.size() < 2:
		return placements

	var carry_distance := spacing * 0.5
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var planar_delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var segment_length := planar_delta.length()
		if segment_length <= 0.5:
			continue

		var tangent := planar_delta / segment_length
		var normal := Vector3(-tangent.z, 0.0, tangent.x)
		while carry_distance <= segment_length:
			var t := carry_distance / segment_length
			var sample := a.lerp(b, t)
			var side_offset := width * 0.5 + 4.8
			var positive := sample + normal * side_offset + Vector3(0.0, 2.5, 0.0)
			var negative := sample - normal * side_offset + Vector3(0.0, 2.5, 0.0)
			if _is_valid_prop_position(positive, road_segments, buildings):
				placements.append(Transform3D(Basis.IDENTITY, positive))
			if _is_valid_prop_position(negative, road_segments, buildings):
				placements.append(Transform3D(Basis.IDENTITY, negative))
			if placements.size() >= 16:
				return placements
			carry_distance += spacing
		carry_distance -= segment_length
	return placements

static func _is_valid_prop_position(position: Vector3, road_segments: Array, buildings: Array) -> bool:
	if _distance_to_roads(Vector2(position.x, position.z), road_segments) < 2.5:
		return false
	for building in buildings:
		var building_dict: Dictionary = building
		var center: Vector2 = building_dict.get("center_2d", Vector2.ZERO)
		var radius := float(building_dict.get("footprint_radius_m", 0.0))
		if Vector2(position.x, position.z).distance_to(center) < radius + 2.0:
			return false
	return true

static func _measure_min_road_clearance(placements: Array, road_segments: Array) -> float:
	if placements.is_empty():
		return 0.0
	var min_clearance := INF
	for placement in placements:
		var transform: Transform3D = placement
		min_clearance = minf(min_clearance, _distance_to_roads(Vector2(transform.origin.x, transform.origin.z), road_segments))
	return min_clearance if min_clearance != INF else 0.0

static func _distance_to_roads(point: Vector2, road_segments: Array) -> float:
	var min_distance := INF
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			min_distance = minf(min_distance, _distance_to_segment(point, Vector2(a.x, a.z), Vector2(b.x, b.z)) - width * 0.5)
	if min_distance == INF:
		return 9999.0
	return min_distance

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)
