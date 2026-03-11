extends RefCounted

static func build_street_lamps(chunk_size_m: float, profile: Dictionary = {}) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetLamps"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 5.0, 0.35)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var avenue: Dictionary = profile.get("avenue", {})
	var axis := str(avenue.get("axis", "z"))
	var road_width := float(avenue.get("width", 28.0))
	var offset := float(avenue.get("offset", 0.0))
	var lamp_pairs := 4 + int(profile.get("towers", []).size() > 3)
	multimesh.instance_count = lamp_pairs * 2

	var half_span := chunk_size_m * 0.32
	for i in range(multimesh.instance_count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var lane_index := int(i / 2)
		var along := -half_span + float(lane_index) * (half_span * 2.0 / maxf(float(lamp_pairs - 1), 1.0))
		var edge_offset := road_width * 0.5 + 4.5
		var position := Vector3(side * half_span, 2.5, along)
		if axis == "x":
			position = Vector3(along, 2.5, offset + side * edge_offset)
		else:
			position = Vector3(offset + side * edge_offset, 2.5, along)
		var transform := Transform3D(Basis.IDENTITY, position)
		multimesh.set_instance_transform(i, transform)

	instance.multimesh = multimesh
	var palette: Dictionary = profile.get("palette", {})
	if palette.has("accent"):
		var material := StandardMaterial3D.new()
		material.albedo_color = palette["accent"]
		material.roughness = 0.92
		instance.material_override = material
	return instance
