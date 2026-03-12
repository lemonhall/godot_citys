extends MultiMeshInstance3D

func _init() -> void:
	name = "PedestrianBatch"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 1.0, 0.28)
	var crowd_multimesh := MultiMesh.new()
	crowd_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	crowd_multimesh.mesh = mesh
	multimesh = crowd_multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.670588, 0.713725, 0.752941, 1.0)
	material.roughness = 1.0
	material_override = material

func configure_from_states(states: Array, chunk_center: Vector3) -> void:
	if multimesh == null:
		return
	multimesh.instance_count = states.size()
	for state_index in range(states.size()):
		var state: Dictionary = states[state_index]
		multimesh.set_instance_transform(state_index, _build_instance_transform(state, chunk_center))
	set_meta("pedestrian_tier1_count", states.size())

func _build_instance_transform(state: Dictionary, chunk_center: Vector3) -> Transform3D:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var local_position := world_position - chunk_center
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var yaw := atan2(heading.x, heading.z)
	var radius_m := float(state.get("radius_m", 0.28))
	var height_m := float(state.get("height_m", 1.75))
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(radius_m * 2.0, height_m, radius_m * 1.8))
	return Transform3D(
		basis,
		Vector3(local_position.x, local_position.y + height_m * 0.5, local_position.z)
	)
