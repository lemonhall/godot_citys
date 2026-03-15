extends Node3D

const DEFAULT_RADIUS_M := 8.0
const OUTER_RING_HEIGHT_M := 0.07
const INNER_RING_HEIGHT_M := 0.05
const CORE_DISC_HEIGHT_M := 0.03
const FLAME_HEIGHT_M := 2.6
const FLAME_RING_SCALE := 0.82
const FLAME_COUNT := 4
const DASH_COUNT := 10

var _radius_m := DEFAULT_RADIUS_M
var _elapsed_sec := 0.0
var _outer_ring: MeshInstance3D = null
var _inner_ring: MeshInstance3D = null
var _core_disc: MeshInstance3D = null
var _dash_ring_root: Node3D = null
var _cross_ring_root: Node3D = null
var _dash_segments: Array[MeshInstance3D] = []
var _cross_segments: Array[MeshInstance3D] = []
var _flame_columns: Array[MeshInstance3D] = []

func _ready() -> void:
	top_level = true
	_ensure_visuals()
	visible = false

func set_marker_radius(radius_m: float) -> void:
	var resolved_radius := maxf(radius_m, 1.5)
	if is_equal_approx(_radius_m, resolved_radius):
		return
	_radius_m = resolved_radius
	_apply_radius()

func set_marker_world_position(world_position: Vector3) -> void:
	global_position = world_position

func set_marker_visible(is_visible: bool) -> void:
	visible = is_visible
	if not is_visible:
		_elapsed_sec = 0.0

func tick(delta: float) -> void:
	if not visible:
		return
	_elapsed_sec += maxf(delta, 0.0)
	var outer_pulse := 1.0 + sin(_elapsed_sec * 1.8) * 0.025
	var inner_pulse := 1.0 + sin(_elapsed_sec * 2.6 + 0.6) * 0.05
	if _outer_ring != null:
		_outer_ring.scale = Vector3(outer_pulse, 1.0, outer_pulse)
	if _inner_ring != null:
		_inner_ring.scale = Vector3(inner_pulse, 1.0, inner_pulse)
	if _core_disc != null:
		var core_pulse := 1.0 + sin(_elapsed_sec * 3.1) * 0.08
		_core_disc.scale = Vector3(core_pulse, 1.0, core_pulse)
	if _dash_ring_root != null:
		_dash_ring_root.rotation.y += delta * 0.38
	if _cross_ring_root != null:
		_cross_ring_root.rotation.y -= delta * 0.24
	for flame_index in range(_flame_columns.size()):
		var flame := _flame_columns[flame_index]
		if flame == null:
			continue
		var flame_pulse := 0.92 + sin(_elapsed_sec * (3.2 + float(flame_index) * 0.45) + float(flame_index) * 0.7) * 0.18
		flame.scale = Vector3(1.0, flame_pulse, 1.0)
		flame.position.y = FLAME_HEIGHT_M * flame_pulse * 0.5

func get_state() -> Dictionary:
	return {
		"visible": visible,
		"world_position": global_position,
		"radius_m": _radius_m,
		"dash_segment_count": _dash_segments.size(),
		"flame_column_count": _flame_columns.size(),
	}

func _ensure_visuals() -> void:
	if _outer_ring != null:
		return
	_outer_ring = _create_disc(
		"OuterRing",
		Color(0.98, 0.54, 0.14, 0.22),
		Color(1.0, 0.66, 0.2, 1.0),
		1.25,
		OUTER_RING_HEIGHT_M
	)
	_inner_ring = _create_disc(
		"InnerRing",
		Color(1.0, 0.76, 0.38, 0.18),
		Color(1.0, 0.84, 0.46, 1.0),
		0.95,
		INNER_RING_HEIGHT_M
	)
	_inner_ring.position.y = 0.025
	_core_disc = _create_disc(
		"CoreDisc",
		Color(1.0, 0.58, 0.16, 0.09),
		Color(1.0, 0.72, 0.24, 1.0),
		0.75,
		CORE_DISC_HEIGHT_M
	)
	_core_disc.position.y = 0.012
	_dash_ring_root = Node3D.new()
	_dash_ring_root.name = "DashRing"
	add_child(_dash_ring_root)
	_cross_ring_root = Node3D.new()
	_cross_ring_root.name = "CrossRing"
	add_child(_cross_ring_root)
	_create_dash_ring(_dash_ring_root, DASH_COUNT, 0.86, 0.42, 0.14, Color(1.0, 0.78, 0.34, 0.72), Color(1.0, 0.86, 0.42, 1.0))
	_create_dash_ring(_cross_ring_root, 4, 0.48, 0.62, 0.16, Color(1.0, 0.62, 0.18, 0.58), Color(1.0, 0.72, 0.26, 1.0))
	_create_flame_columns()
	_apply_radius()

func _apply_radius() -> void:
	_set_disc_radius(_outer_ring, _radius_m)
	_set_disc_radius(_inner_ring, _radius_m * 0.68)
	_set_disc_radius(_core_disc, _radius_m * 0.22)
	_layout_dash_ring(_dash_ring_root, _dash_segments, _radius_m * 0.86)
	_layout_dash_ring(_cross_ring_root, _cross_segments, _radius_m * 0.48)
	for flame_index in range(_flame_columns.size()):
		var flame := _flame_columns[flame_index]
		if flame == null:
			continue
		var flame_mesh := flame.mesh as CylinderMesh
		if flame_mesh != null:
			flame_mesh.top_radius = maxf(_radius_m * 0.035, 0.12)
			flame_mesh.bottom_radius = maxf(_radius_m * 0.085, 0.24)
			flame_mesh.height = FLAME_HEIGHT_M
		var angle := TAU * float(flame_index) / float(maxi(_flame_columns.size(), 1))
		flame.position = Vector3(cos(angle) * _radius_m * FLAME_RING_SCALE, FLAME_HEIGHT_M * 0.5, sin(angle) * _radius_m * FLAME_RING_SCALE)

func _set_disc_radius(mesh_instance: MeshInstance3D, radius_m: float) -> void:
	if mesh_instance == null:
		return
	var mesh := mesh_instance.mesh as CylinderMesh
	if mesh == null:
		return
	mesh.top_radius = radius_m
	mesh.bottom_radius = radius_m

func _create_disc(node_name: String, base_color: Color, emission_color: Color, emission_energy: float, height_m: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = _radius_m
	mesh.bottom_radius = _radius_m
	mesh.height = height_m
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(base_color, emission_color, emission_energy)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _create_dash_ring(root: Node3D, segment_count: int, radius_scale: float, length_scale: float, width_m: float, base_color: Color, emission_color: Color) -> void:
	var target_segments := _dash_segments if root == _dash_ring_root else _cross_segments
	for segment_index in range(segment_count):
		var segment := MeshInstance3D.new()
		segment.name = "Segment%d" % segment_index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width_m, 0.045, maxf(_radius_m * length_scale, 0.9))
		segment.mesh = mesh
		segment.material_override = _make_material(base_color, emission_color, 1.05 if root == _dash_ring_root else 0.88)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(segment)
		target_segments.append(segment)
	_layout_dash_ring(root, target_segments, _radius_m * radius_scale)

func _layout_dash_ring(root: Node3D, segments: Array[MeshInstance3D], radius_m: float) -> void:
	if root == null:
		return
	for segment_index in range(segments.size()):
		var segment := segments[segment_index]
		if segment == null:
			continue
		var angle := TAU * float(segment_index) / float(maxi(segments.size(), 1))
		segment.position = Vector3(cos(angle) * radius_m, 0.04 if root == _dash_ring_root else 0.055, sin(angle) * radius_m)
		segment.rotation.y = angle + PI * 0.5
		var mesh := segment.mesh as BoxMesh
		if mesh != null:
			mesh.size.z = maxf(_radius_m * (0.42 if root == _dash_ring_root else 0.62), 0.9)
			mesh.size.x = 0.14 if root == _dash_ring_root else 0.16

func _create_flame_columns() -> void:
	for flame_index in range(FLAME_COUNT):
		var flame := MeshInstance3D.new()
		flame.name = "FlameColumn%d" % flame_index
		var mesh := CylinderMesh.new()
		mesh.top_radius = maxf(_radius_m * 0.035, 0.12)
		mesh.bottom_radius = maxf(_radius_m * 0.085, 0.24)
		mesh.height = FLAME_HEIGHT_M
		mesh.radial_segments = 12
		flame.mesh = mesh
		flame.material_override = _make_material(
			Color(1.0, 0.55, 0.14, 0.2),
			Color(1.0, 0.72, 0.22, 1.0),
			1.35
		)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		_flame_columns.append(flame)

func _make_material(base_color: Color, emission_color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	return material
