extends Node3D

const TracerSmokeShader := preload("res://city_game/combat/shaders/CityProjectileTracerSmoke.gdshader")

@export var lifetime_sec := 0.075
@export var base_segment_length_m := 4.6
@export var max_segment_length_m := 7.4
@export var base_segment_width_m := 0.12
@export var max_segment_width_m := 0.18
@export var muzzle_clearance_m := 0.45

var _primary_mesh: MeshInstance3D = null
var _cross_mesh: MeshInstance3D = null
var _direction := Vector3.FORWARD
var _origin := Vector3.ZERO
var _speed_mps := 0.0
var _segment_length_m := 0.0
var _segment_width_m := 0.0
var _time_remaining_sec := 0.0

func _ready() -> void:
	_ensure_visuals()
	if _time_remaining_sec <= 0.0:
		_time_remaining_sec = maxf(lifetime_sec, 0.01)
	_apply_visual_state(0.0)

func configure(origin: Vector3, direction: Vector3, speed_mps: float) -> void:
	_origin = origin
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_speed_mps = maxf(speed_mps, 0.0)
	_segment_length_m = clampf(base_segment_length_m + _speed_mps * 0.0018, base_segment_length_m, max_segment_length_m)
	_segment_width_m = clampf(base_segment_width_m + _speed_mps * 0.00004, base_segment_width_m, max_segment_width_m)
	_time_remaining_sec = maxf(lifetime_sec, 0.01)

func _process(delta: float) -> void:
	if _time_remaining_sec <= 0.0:
		queue_free()
		return
	_time_remaining_sec = maxf(_time_remaining_sec - maxf(delta, 0.0), 0.0)
	var progress := 1.0 - (_time_remaining_sec / maxf(lifetime_sec, 0.01))
	_apply_visual_state(progress)
	if _time_remaining_sec <= 0.0:
		queue_free()

func get_debug_state() -> Dictionary:
	return {
		"active": _time_remaining_sec > 0.0,
		"segment_length_m": _segment_length_m,
		"segment_width_m": _segment_width_m,
		"speed_mps": _speed_mps,
		"origin": _origin,
		"direction": _direction,
		"time_remaining_sec": _time_remaining_sec,
	}

func _ensure_visuals() -> void:
	if _primary_mesh == null:
		_primary_mesh = MeshInstance3D.new()
		_primary_mesh.name = "PrimarySmokeStreak"
		add_child(_primary_mesh)
	if _cross_mesh == null:
		_cross_mesh = MeshInstance3D.new()
		_cross_mesh.name = "CrossSmokeStreak"
		add_child(_cross_mesh)
	for mesh_instance in [_primary_mesh, _cross_mesh]:
		if mesh_instance == null:
			continue
		var plane_mesh := mesh_instance.mesh as PlaneMesh
		if plane_mesh == null:
			plane_mesh = PlaneMesh.new()
			plane_mesh.size = Vector2(base_segment_width_m, base_segment_length_m)
			plane_mesh.subdivide_width = 1
			plane_mesh.subdivide_depth = 8
			mesh_instance.mesh = plane_mesh
		if not (mesh_instance.material_override is ShaderMaterial):
			var material := ShaderMaterial.new()
			material.shader = TracerSmokeShader
			mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.top_level = true
		mesh_instance.visible = false

func _apply_visual_state(progress: float) -> void:
	var alpha := clampf(1.0 - progress, 0.0, 1.0)
	var segment_length := _segment_length_m * lerpf(1.0, 1.18, progress)
	var segment_width := _segment_width_m * lerpf(1.0, 1.26, progress)
	var segment_start := _origin + _direction * muzzle_clearance_m
	var segment_center := segment_start + _direction * segment_length * 0.5
	var up_axis := Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	_apply_mesh_state(_primary_mesh, segment_center, _direction, up_axis, segment_length, segment_width, alpha, 0.0)
	_apply_mesh_state(_cross_mesh, segment_center, _direction, up_axis, segment_length * 0.97, segment_width * 0.94, alpha * 0.86, PI * 0.5)

func _apply_mesh_state(
	mesh_instance: MeshInstance3D,
	world_position: Vector3,
	direction: Vector3,
	up_axis: Vector3,
	segment_length: float,
	segment_width: float,
	alpha: float,
	axial_roll_rad: float
) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return
	mesh_instance.visible = alpha > 0.01
	if not mesh_instance.visible:
		return
	var plane_mesh := mesh_instance.mesh as PlaneMesh
	if plane_mesh != null:
		plane_mesh.size = Vector2(segment_width, segment_length)
	mesh_instance.global_position = world_position
	mesh_instance.look_at(world_position + direction, up_axis, true)
	if absf(axial_roll_rad) > 0.0001:
		mesh_instance.rotate_object_local(Vector3.FORWARD, axial_roll_rad)
	mesh_instance.set_instance_shader_parameter("trace_length", segment_length)
	mesh_instance.set_instance_shader_parameter("trace_width", segment_width)
	mesh_instance.set_instance_shader_parameter("trace_alpha", alpha)
	mesh_instance.set_instance_shader_parameter("trace_phase", 0.0 if absf(axial_roll_rad) <= 0.0001 else 1.37)
