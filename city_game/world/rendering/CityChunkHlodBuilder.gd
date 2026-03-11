extends RefCounted

static func build_mid_proxy(chunk_size_m: float) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.name = "MidProxy"
	proxy.mesh = _build_box_mesh(Vector3(chunk_size_m * 0.72, 22.0, chunk_size_m * 0.72))
	proxy.position = Vector3(0.0, 11.0, 0.0)
	proxy.material_override = _build_material(Color(0.35, 0.46, 0.58, 1.0))
	return proxy

static func build_far_proxy(chunk_size_m: float) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.name = "FarProxy"
	proxy.mesh = _build_box_mesh(Vector3(chunk_size_m * 0.82, 12.0, chunk_size_m * 0.82))
	proxy.position = Vector3(0.0, 6.0, 0.0)
	proxy.material_override = _build_material(Color(0.24, 0.32, 0.42, 1.0))
	return proxy

static func _build_box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _build_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

