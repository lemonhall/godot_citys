extends RefCounted

static func build_street_lamps(chunk_size_m: float) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetLamps"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 5.0, 0.35)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 8

	var half_span := chunk_size_m * 0.32
	for i in range(multimesh.instance_count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var lane_index := float(i / 2)
		var offset := -half_span + lane_index * (half_span * 2.0 / 3.0)
		var transform := Transform3D(Basis.IDENTITY, Vector3(side * half_span, 2.5, offset))
		multimesh.set_instance_transform(i, transform)

	instance.multimesh = multimesh
	return instance

