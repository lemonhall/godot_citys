extends RefCounted

static func build_mid_proxy(profile: Dictionary) -> Node3D:
	return _build_proxy_group("MidProxy", profile, "mid")

static func build_far_proxy(profile: Dictionary) -> Node3D:
	return _build_proxy_group("FarProxy", profile, "far")

static func _build_proxy_group(name: String, profile: Dictionary, palette_key: String) -> Node3D:
	var proxy := Node3D.new()
	proxy.name = "MidProxy"
	proxy.name = name

	var mesh_instance := MultiMeshInstance3D.new()
	mesh_instance.name = "Massing"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box_mesh

	var buildings: Array = profile.get("buildings", [])
	multimesh.instance_count = buildings.size()
	for building_index in range(buildings.size()):
		var building: Dictionary = buildings[building_index]
		multimesh.set_instance_transform(
			building_index,
			_build_scaled_transform(
				building.get("center", Vector3.ZERO),
				building.get("size", Vector3.ONE),
				float(building.get("yaw_rad", 0.0))
			)
		)
	mesh_instance.multimesh = multimesh
	mesh_instance.material_override = _build_material(profile, palette_key)
	proxy.add_child(mesh_instance)
	return proxy

static func _build_scaled_transform(center: Vector3, size: Vector3, yaw_rad: float = 0.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw_rad).scaled(size)
	return Transform3D(basis, center)

static func _build_material(profile: Dictionary, palette_key: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var palette: Dictionary = profile.get("palette", {})
	material.albedo_color = palette.get(palette_key, Color(0.35, 0.46, 0.58, 1.0))
	material.roughness = 1.0
	return material
