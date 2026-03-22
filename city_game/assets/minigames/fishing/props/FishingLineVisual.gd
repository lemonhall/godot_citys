extends Node3D

var _mesh_instance: MeshInstance3D = null
var _mesh: ImmediateMesh = null
var _material: StandardMaterial3D = null
var _debug_state: Dictionary = {
	"visible": false,
	"start_world_position": Vector3.ZERO,
	"end_world_position": Vector3.ZERO,
}

func _ready() -> void:
	_ensure_mesh_instance()
	_hide_line()

func set_line_state(should_show: bool, start_world_position: Vector3, end_world_position: Vector3, sag_m: float = 0.18) -> void:
	_ensure_mesh_instance()
	_debug_state = {
		"visible": should_show,
		"start_world_position": start_world_position,
		"end_world_position": end_world_position,
	}
	if not should_show or _mesh_instance == null or _mesh == null:
		_hide_line()
		return
	var local_start := to_local(start_world_position)
	var local_end := to_local(end_world_position)
	var midpoint := (local_start + local_end) * 0.5 + Vector3.DOWN * maxf(sag_m, 0.0)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	_mesh.surface_add_vertex(local_start)
	_mesh.surface_add_vertex(midpoint)
	_mesh.surface_add_vertex(local_end)
	_mesh.surface_end()
	_mesh_instance.visible = true

func get_debug_state() -> Dictionary:
	return _debug_state.duplicate(true)

func _ensure_mesh_instance() -> void:
	if _mesh_instance != null and is_instance_valid(_mesh_instance):
		return
	_mesh_instance = get_node_or_null("LineMesh") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "LineMesh"
		add_child(_mesh_instance)
	_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.964706, 0.980392, 0.913725, 1.0)
	_material.emission_enabled = true
	_material.emission = Color(0.92549, 1.0, 0.847059, 1.0)
	_material.emission_energy_multiplier = 0.35
	_mesh_instance.material_override = _material

func _hide_line() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	if _mesh_instance != null and is_instance_valid(_mesh_instance):
		_mesh_instance.visible = false
