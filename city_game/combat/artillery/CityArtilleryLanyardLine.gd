extends Node3D

@export_range(8, 32, 1) var curve_sample_count := 10

var _mesh_instance: MeshInstance3D = null
var _mesh: ImmediateMesh = null
var _material: StandardMaterial3D = null
var _debug_state: Dictionary = _build_hidden_debug_state()

func _ready() -> void:
	top_level = true
	_ensure_mesh_instance()
	_hide_line()

func set_line_state(should_show: bool, start_world_position: Vector3, end_world_position: Vector3, sag_m: float = 0.18) -> void:
	top_level = true
	_ensure_mesh_instance()
	if not should_show or _mesh_instance == null or _mesh == null:
		_hide_line()
		return
	var sample_points_world := _build_curve_points_world(start_world_position, end_world_position, sag_m)
	var curve_origin_world := (start_world_position + end_world_position) * 0.5
	global_transform = Transform3D(Basis.IDENTITY, curve_origin_world)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	var min_world_y := INF
	for point_world in sample_points_world:
		min_world_y = minf(min_world_y, point_world.y)
		_mesh.surface_add_vertex(point_world - curve_origin_world)
	_mesh.surface_end()
	_mesh_instance.visible = true
	_debug_state = {
		"visible": true,
		"start_world_position": start_world_position,
		"end_world_position": end_world_position,
		"sample_count": sample_points_world.size(),
		"min_world_y": min_world_y,
	}

func get_debug_state() -> Dictionary:
	return _debug_state.duplicate(true)

func _build_curve_points_world(start_world_position: Vector3, end_world_position: Vector3, sag_m: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var resolved_sample_count := maxi(curve_sample_count, 2)
	var resolved_sag_m := maxf(sag_m, 0.0)
	var denominator := maxf(float(resolved_sample_count - 1), 1.0)
	for sample_index in range(resolved_sample_count):
		var t := float(sample_index) / denominator
		var point_world := start_world_position.lerp(end_world_position, t)
		point_world.y -= resolved_sag_m * 4.0 * t * (1.0 - t)
		points.append(point_world)
	return points

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
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _hide_line() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	if _mesh_instance != null and is_instance_valid(_mesh_instance):
		_mesh_instance.visible = false
	global_transform = Transform3D.IDENTITY
	_debug_state = _build_hidden_debug_state()

func _build_hidden_debug_state() -> Dictionary:
	return {
		"visible": false,
		"start_world_position": Vector3.ZERO,
		"end_world_position": Vector3.ZERO,
		"sample_count": 0,
		"min_world_y": 0.0,
	}
