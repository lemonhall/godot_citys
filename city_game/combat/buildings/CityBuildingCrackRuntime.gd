extends Node3D

const MAX_MARKERS := 3

var _marker_root: Node3D = null
var _markers: Array[Node3D] = []
var _last_hit_local_position := Vector3.ZERO

func _ready() -> void:
	_ensure_marker_root()

func configure(source_transform: Transform3D) -> void:
	transform = source_transform

func clear_cracks() -> void:
	for marker in _markers:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
	_last_hit_local_position = Vector3.ZERO

func show_crack(hit_local_position: Vector3, half_extents: Vector3) -> void:
	_ensure_marker_root()
	_last_hit_local_position = hit_local_position
	var marker := _build_crack_marker(hit_local_position, half_extents)
	_marker_root.add_child(marker)
	_markers.append(marker)
	while _markers.size() > MAX_MARKERS:
		var retired: Node3D = _markers.pop_front()
		if retired != null and is_instance_valid(retired):
			retired.queue_free()

func get_debug_state() -> Dictionary:
	return {
		"visual_active": _markers.size() > 0,
		"crack_count": _markers.size(),
		"last_hit_local_position": _last_hit_local_position,
	}

func _ensure_marker_root() -> void:
	if _marker_root != null and is_instance_valid(_marker_root):
		return
	_marker_root = get_node_or_null("CrackMarkers") as Node3D
	if _marker_root == null:
		_marker_root = Node3D.new()
		_marker_root.name = "CrackMarkers"
		add_child(_marker_root)

func _build_crack_marker(hit_local_position: Vector3, half_extents: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = "CrackMarker"
	var face_normal := _resolve_face_normal(hit_local_position, half_extents)
	var tangent_a := _resolve_tangent_a(face_normal)
	var tangent_b := face_normal.cross(tangent_a).normalized()
	if tangent_b.length_squared() <= 0.0001:
		tangent_b = Vector3.UP
	marker.basis = Basis(tangent_a, tangent_b, face_normal)
	marker.position = hit_local_position + face_normal * 0.08

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.06, 0.04, 0.94)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.11, 0.06, 1.0)
	material.emission_energy_multiplier = 0.45
	material.roughness = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	marker.add_child(_build_crack_line("Primary", Vector3(0.78, 0.06, 0.035), material, 0.0))
	marker.add_child(_build_crack_line("Secondary", Vector3(0.52, 0.05, 0.03), material, deg_to_rad(34.0)))
	marker.add_child(_build_crack_line("Tertiary", Vector3(0.44, 0.045, 0.028), material, deg_to_rad(-41.0)))
	return marker

func _build_crack_line(node_name: String, size: Vector3, material: StandardMaterial3D, rotation_z: float) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.material_override = material
	line.rotation.z = rotation_z
	return line

func _resolve_face_normal(hit_local_position: Vector3, half_extents: Vector3) -> Vector3:
	var safe_half := Vector3(maxf(absf(half_extents.x), 0.001), maxf(absf(half_extents.y), 0.001), maxf(absf(half_extents.z), 0.001))
	var normalized := Vector3(
		absf(hit_local_position.x) / safe_half.x,
		absf(hit_local_position.y) / safe_half.y,
		absf(hit_local_position.z) / safe_half.z
	)
	if normalized.x >= normalized.y and normalized.x >= normalized.z:
		return Vector3.RIGHT if hit_local_position.x >= 0.0 else Vector3.LEFT
	if normalized.z >= normalized.x and normalized.z >= normalized.y:
		return Vector3.FORWARD if hit_local_position.z >= 0.0 else Vector3.BACK
	return Vector3.UP if hit_local_position.y >= 0.0 else Vector3.DOWN

func _resolve_tangent_a(face_normal: Vector3) -> Vector3:
	if absf(face_normal.dot(Vector3.UP)) > 0.94:
		return Vector3.RIGHT
	return Vector3.UP
