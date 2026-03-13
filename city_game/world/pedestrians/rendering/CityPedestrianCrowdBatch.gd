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
		var state = states[state_index]
		multimesh.set_instance_transform(state_index, _build_instance_transform(state, chunk_center))
	set_meta("pedestrian_tier1_count", states.size())

func _build_instance_transform(state, chunk_center: Vector3) -> Transform3D:
	var world_position := _state_world_position(state)
	var local_position := world_position - chunk_center
	var heading := _state_heading(state)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var yaw := atan2(heading.x, heading.z)
	var radius_m := _state_radius_m(state)
	var height_m := _state_height_m(state)
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(radius_m * 2.0, height_m, radius_m * 1.8))
	return Transform3D(
		basis,
		Vector3(local_position.x, local_position.y + height_m * 0.5, local_position.z)
	)

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _state_radius_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("radius_m", 0.28))
	return float(state.radius_m) if state != null else 0.28

func _state_height_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("height_m", 1.75))
	return float(state.height_m) if state != null else 1.75
