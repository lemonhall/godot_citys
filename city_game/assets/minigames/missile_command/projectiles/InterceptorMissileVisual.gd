extends Node3D

const TailFlameShader := preload("res://city_game/assets/minigames/missile_command/projectiles/InterceptorTailFlame.gdshader")

const TRAIL_VISIBILITY_SPEED_MPS := 4.0
const PREVIEW_CAMERA_LOCAL_POSITION := Vector3(5.4749017, 1.2936201, -2.3609767)
const PREVIEW_CAMERA_FOCUS_LOCAL_POSITION := Vector3.ZERO
const PREVIEW_TRAVEL_DISTANCE_M := 18.0
const PREVIEW_BASE_HEIGHT_M := 1.1
const PREVIEW_BOB_HEIGHT_M := 0.18
const PREVIEW_LATERAL_SWAY_M := 0.35
const PREVIEW_CYCLE_DURATION_SEC := 2.6
const PREVIEW_TRAIL_LENGTH_MIN_M := 2.8
const PREVIEW_TRAIL_LENGTH_MAX_M := 6.8
const PREVIEW_TRAIL_WIDTH_MIN_M := 0.24
const PREVIEW_TRAIL_WIDTH_MAX_M := 0.42
const FLAME_NOZZLE_CLEARANCE_M := 0.06
const FLAME_INTENSITY_PREVIEW_MULTIPLIER := 1.18
const FLAME_CROSS_PHASE_OFFSET := 1.37
const FLAME_CROSS_INTENSITY_SCALE := 0.92

var _trail_visual: MeshInstance3D = null
var _trail_visual_cross: MeshInstance3D = null
var _trail_visible := false
var _preview_active := false
var _preview_origin := Vector3.ZERO
var _preview_time_sec := 0.0
var _preview_previous_position := Vector3.ZERO
var _runtime_direction := Vector3.FORWARD
var _runtime_speed_mps := 0.0
var _runtime_active := false
var _last_runtime_sync_frame := -1
var _model_back_extent_m := 0.58

func _ready() -> void:
	_preview_origin = global_position
	_preview_previous_position = global_position
	_trail_visual = get_node_or_null("TrailVisual") as MeshInstance3D
	_trail_visual_cross = get_node_or_null("TrailVisualCross") as MeshInstance3D
	_ensure_trail_visuals()
	_model_back_extent_m = _measure_model_back_extent()
	_update_trail_visual(_runtime_direction, 0.0, false)

func _process(delta: float) -> void:
	if _preview_active and not _was_synced_this_frame():
		_advance_preview(delta)
		return
	if not _was_synced_this_frame():
		_update_trail_visual(_runtime_direction, 0.0, false)

func sync_motion_state(world_position: Vector3, direction: Vector3, speed_mps: float, active: bool = true) -> void:
	global_position = world_position
	var resolved_direction := direction.normalized()
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = _runtime_direction
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = Vector3.FORWARD
	_runtime_direction = resolved_direction
	_runtime_speed_mps = maxf(speed_mps, 0.0)
	_runtime_active = active
	_last_runtime_sync_frame = Engine.get_process_frames()
	var up_axis := Vector3.UP if absf(_runtime_direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	look_at(global_position + _runtime_direction, up_axis, true)
	_update_trail_visual(_runtime_direction, _runtime_speed_mps, _runtime_active)

func get_scene_preview_contract() -> Dictionary:
	return {
		"follow_target_path": NodePath("."),
		"default_camera_local_position": PREVIEW_CAMERA_LOCAL_POSITION,
		"default_camera_focus_local_position": PREVIEW_CAMERA_FOCUS_LOCAL_POSITION,
		"capture_mouse_on_activate": true,
	}

func set_scene_preview_active(active: bool, _preview_context: Dictionary = {}) -> void:
	if active == _preview_active:
		return
	_preview_active = active
	var current_position := global_position if is_inside_tree() else position
	_preview_origin = current_position
	_preview_previous_position = current_position
	_preview_time_sec = 0.0
	if not _preview_active and not _runtime_active:
		_update_trail_visual(_runtime_direction, 0.0, false)

func get_debug_state() -> Dictionary:
	return {
		"trail_present": _trail_visual != null and is_instance_valid(_trail_visual),
		"trail_cross_present": _trail_visual_cross != null and is_instance_valid(_trail_visual_cross),
		"trail_visible": _trail_visible and _trail_visual != null and is_instance_valid(_trail_visual) and _trail_visual.visible,
		"preview_active": _preview_active,
		"runtime_active": _runtime_active,
		"runtime_speed_mps": _runtime_speed_mps,
		"world_position": global_position,
		"forward": (-transform.basis.z).normalized(),
	}

func _advance_preview(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0001)
	_preview_time_sec += safe_delta
	var phase := fmod(_preview_time_sec / PREVIEW_CYCLE_DURATION_SEC, 1.0)
	var travel_alpha := 1.0 - absf(phase * 2.0 - 1.0)
	var lateral := sin(_preview_time_sec * TAU / PREVIEW_CYCLE_DURATION_SEC) * PREVIEW_LATERAL_SWAY_M
	var bob_height := PREVIEW_BASE_HEIGHT_M + sin(_preview_time_sec * TAU * 1.5 / PREVIEW_CYCLE_DURATION_SEC) * PREVIEW_BOB_HEIGHT_M
	var preview_position := _preview_origin + Vector3(
		lateral,
		bob_height,
		lerpf(-PREVIEW_TRAVEL_DISTANCE_M * 0.5, PREVIEW_TRAVEL_DISTANCE_M * 0.5, travel_alpha)
	)
	var travel_vector := preview_position - _preview_previous_position
	var travel_direction := travel_vector.normalized() if travel_vector.length_squared() > 0.0001 else _runtime_direction
	var speed_mps := travel_vector.length() / safe_delta
	_preview_previous_position = preview_position
	global_position = preview_position
	var up_axis := Vector3.UP if absf(travel_direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	look_at(global_position + travel_direction, up_axis, true)
	_update_trail_visual(travel_direction, speed_mps, true)

func _ensure_trail_visuals() -> void:
	if _trail_visual == null:
		_trail_visual = MeshInstance3D.new()
		_trail_visual.name = "TrailVisual"
		add_child(_trail_visual)
	if _trail_visual_cross == null:
		_trail_visual_cross = MeshInstance3D.new()
		_trail_visual_cross.name = "TrailVisualCross"
		add_child(_trail_visual_cross)
	for trail_mesh_instance in [_trail_visual, _trail_visual_cross]:
		if trail_mesh_instance == null:
			continue
		var trail_mesh := trail_mesh_instance.mesh as PlaneMesh
		if trail_mesh == null:
			trail_mesh = PlaneMesh.new()
			trail_mesh.size = Vector2(0.18, 1.6)
			trail_mesh.subdivide_width = 1
			trail_mesh.subdivide_depth = 8
			trail_mesh_instance.mesh = trail_mesh
		if not (trail_mesh_instance.material_override is ShaderMaterial):
			trail_mesh_instance.material_override = _build_tail_flame_material()
		trail_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail_mesh_instance.visible = false
		trail_mesh_instance.top_level = true

func _update_trail_visual(direction: Vector3, speed_mps: float, active: bool) -> void:
	if _trail_visual == null or not is_instance_valid(_trail_visual):
		_trail_visible = false
		return
	var should_show_trail := active and speed_mps >= TRAIL_VISIBILITY_SPEED_MPS
	_trail_visible = should_show_trail
	_trail_visual.visible = should_show_trail
	if _trail_visual_cross != null and is_instance_valid(_trail_visual_cross):
		_trail_visual_cross.visible = should_show_trail
	if not should_show_trail:
		return
	var resolved_direction := direction.normalized()
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = Vector3.FORWARD
	var trail_length := clampf(0.92 + (speed_mps - TRAIL_VISIBILITY_SPEED_MPS) * 0.055, 0.92, 2.2)
	var trail_width := clampf(0.16 + speed_mps * 0.0028, 0.16, 0.34)
	var flame_intensity := clampf(0.9 + speed_mps * 0.018, 0.9, 1.95)
	if _preview_active:
		trail_length = clampf(trail_length * 1.55, PREVIEW_TRAIL_LENGTH_MIN_M, PREVIEW_TRAIL_LENGTH_MAX_M)
		trail_width = clampf(trail_width * 1.24, PREVIEW_TRAIL_WIDTH_MIN_M, PREVIEW_TRAIL_WIDTH_MAX_M)
		flame_intensity *= FLAME_INTENSITY_PREVIEW_MULTIPLIER
	var flame_origin_world_position := global_position - resolved_direction * (_model_back_extent_m + FLAME_NOZZLE_CLEARANCE_M)
	var trail_world_position := flame_origin_world_position - resolved_direction * trail_length * 0.5
	var up_axis := Vector3.UP if absf(resolved_direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	_apply_trail_flame_state(_trail_visual, trail_world_position, resolved_direction, up_axis, trail_length, trail_width, flame_intensity, 0.0, 0.0)
	_apply_trail_flame_state(_trail_visual_cross, trail_world_position, resolved_direction, up_axis, trail_length, trail_width * 0.96, flame_intensity * FLAME_CROSS_INTENSITY_SCALE, FLAME_CROSS_PHASE_OFFSET, PI * 0.5)

func _build_tail_flame_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TailFlameShader
	return material

func _was_synced_this_frame() -> bool:
	return _last_runtime_sync_frame == Engine.get_process_frames()

func _apply_trail_flame_state(
	trail_mesh_instance: MeshInstance3D,
	world_position: Vector3,
	direction: Vector3,
	up_axis: Vector3,
	flame_length: float,
	flame_width: float,
	flame_intensity: float,
	flame_phase: float,
	axial_roll_rad: float
) -> void:
	if trail_mesh_instance == null or not is_instance_valid(trail_mesh_instance):
		return
	var plane_mesh := trail_mesh_instance.mesh as PlaneMesh
	if plane_mesh != null:
		plane_mesh.size = Vector2(flame_width, flame_length)
	trail_mesh_instance.global_position = world_position
	trail_mesh_instance.look_at(world_position + direction, up_axis, true)
	if absf(axial_roll_rad) > 0.0001:
		trail_mesh_instance.rotate_object_local(Vector3.FORWARD, axial_roll_rad)
	trail_mesh_instance.set_instance_shader_parameter("flame_length", flame_length)
	trail_mesh_instance.set_instance_shader_parameter("flame_width", flame_width)
	trail_mesh_instance.set_instance_shader_parameter("flame_intensity", flame_intensity)
	trail_mesh_instance.set_instance_shader_parameter("flame_speed", clampf(_runtime_speed_mps / 24.0, 0.75, 2.2))
	trail_mesh_instance.set_instance_shader_parameter("flame_phase", flame_phase)

func _measure_model_back_extent() -> float:
	var model_root := get_node_or_null("ModelRoot") as Node3D
	if model_root == null:
		return 0.58
	var self_inverse := global_transform.affine_inverse()
	var min_local_z := INF
	var visual_count := 0
	for child in model_root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var local_transform := self_inverse * visual.global_transform
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var local_corner := local_transform * corner
			min_local_z = minf(min_local_z, local_corner.z)
		visual_count += 1
	if visual_count <= 0 or not is_finite(min_local_z):
		return 0.58
	return maxf(-min_local_z, 0.34)

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
