extends RefCounted

static func build_street_lamps(profile: Dictionary = {}) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetLamps"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.28, 5.0, 0.28)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh

	var placements := _collect_lamp_positions(profile.get("road_segments", []))
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
		var material := StandardMaterial3D.new()
		material.albedo_color = palette["accent"]
		material.roughness = 0.92
		instance.material_override = material
	return instance

static func _collect_lamp_positions(road_segments: Array) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	for segment in road_segments:
		if placements.size() >= 16:
			break
		var segment_dict: Dictionary = segment
		var width := float(segment_dict.get("width", 10.0))
		var points: Array = segment_dict.get("points", [])
		placements.append_array(_sample_segment_lamps(points, width, 56.0 if width >= 12.0 else 68.0))
	return placements

static func _sample_segment_lamps(points: Array, width: float, spacing: float) -> Array[Transform3D]:
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
			var side_offset := width * 0.5 + 3.2
			placements.append(Transform3D(Basis.IDENTITY, sample + normal * side_offset + Vector3(0.0, 2.5, 0.0)))
			placements.append(Transform3D(Basis.IDENTITY, sample - normal * side_offset + Vector3(0.0, 2.5, 0.0)))
			if placements.size() >= 16:
				return placements
			carry_distance += spacing
		carry_distance -= segment_length
	return placements
