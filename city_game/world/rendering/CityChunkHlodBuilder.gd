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

	var towers: Array = profile.get("towers", [])
	multimesh.instance_count = towers.size() + 1
	for tower_index in range(towers.size()):
		var tower: Dictionary = towers[tower_index]
		multimesh.set_instance_transform(tower_index, _build_scaled_transform(tower.get("center", Vector3.ZERO), tower.get("size", Vector3.ONE)))

	var podium: Dictionary = profile.get("podium", {})
	multimesh.set_instance_transform(towers.size(), _build_scaled_transform(podium.get("center", Vector3.ZERO), podium.get("size", Vector3.ONE)))
	mesh_instance.multimesh = multimesh
	mesh_instance.material_override = _build_material(profile, palette_key)
	proxy.add_child(mesh_instance)
	return proxy

static func _build_scaled_transform(center: Vector3, size: Vector3) -> Transform3D:
	var basis := Basis.IDENTITY.scaled(size)
	return Transform3D(basis, center)

static func _build_material(profile: Dictionary, palette_key: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var palette: Dictionary = profile.get("palette", {})
	material.albedo_color = palette.get(palette_key, Color(0.35, 0.46, 0.58, 1.0))
	material.roughness = 1.0
	return material
