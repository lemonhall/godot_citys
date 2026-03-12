extends Node3D

var _body: MeshInstance3D = null

func apply_state(state: Dictionary, chunk_center: Vector3) -> void:
	_ensure_body()
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var local_position := world_position - chunk_center
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var height_m := float(state.get("height_m", 1.75))
	var radius_m := float(state.get("radius_m", 0.28))
	position = Vector3(local_position.x, local_position.y + height_m * 0.5, local_position.z)
	rotation.y = atan2(heading.x, heading.z)
	if _body != null:
		_body.scale = Vector3(radius_m * 2.15, height_m, radius_m * 1.95)
		var material := _body.material_override as StandardMaterial3D
		if material != null:
			match str(state.get("reaction_state", "none")):
				"yield":
					material.albedo_color = Color(0.945098, 0.807843, 0.482353, 1.0)
					material.emission = Color(0.670588, 0.52549, 0.180392, 1.0)
				"sidestep":
					material.albedo_color = Color(0.439216, 0.780392, 0.996078, 1.0)
					material.emission = Color(0.192157, 0.552941, 0.835294, 1.0)
				"panic", "flee":
					material.albedo_color = Color(0.984314, 0.462745, 0.384314, 1.0)
					material.emission = Color(0.784314, 0.192157, 0.117647, 1.0)
				_:
					material.albedo_color = Color(0.756863, 0.760784, 0.737255, 1.0)
					material.emission = Color(0.0, 0.0, 0.0, 1.0)

func _ensure_body() -> void:
	if _body != null and is_instance_valid(_body):
		return
	_body = get_node_or_null("Body") as MeshInstance3D
	if _body != null:
		return
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 1.0, 0.34)
	_body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.756863, 0.760784, 0.737255, 1.0)
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(0.0, 0.0, 0.0, 1.0)
	material.emission_energy_multiplier = 0.35
	_body.material_override = material
	add_child(_body)
