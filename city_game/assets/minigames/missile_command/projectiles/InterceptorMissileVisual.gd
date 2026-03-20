extends Node3D

const TailFlameShader := preload("res://city_game/assets/minigames/missile_command/projectiles/InterceptorTailFlame.gdshader")

const TRAIL_VISIBILITY_SPEED_MPS := 4.0
const PREVIEW_TRAVEL_DISTANCE_M := 18.0
const PREVIEW_BASE_HEIGHT_M := 1.1
const PREVIEW_BOB_HEIGHT_M := 0.18
const PREVIEW_LATERAL_SWAY_M := 0.35
const PREVIEW_CYCLE_DURATION_SEC := 2.6
const PREVIEW_TRAIL_LENGTH_MIN_M := 2.8
const PREVIEW_TRAIL_LENGTH_MAX_M := 6.8
const PREVIEW_TRAIL_WIDTH_MIN_M := 0.24
const PREVIEW_TRAIL_WIDTH_MAX_M := 0.42
const PREVIEW_CAMERA_LOOK_SENSITIVITY := 0.0032
const PREVIEW_CAMERA_MOVE_SPEED_MPS := 9.5
const PREVIEW_CAMERA_SPRINT_MULTIPLIER := 2.4
const PREVIEW_CAMERA_PITCH_MIN_RAD := deg_to_rad(-88.0)
const PREVIEW_CAMERA_PITCH_MAX_RAD := deg_to_rad(88.0)
const FLAME_NOZZLE_CLEARANCE_M := 0.06
const FLAME_INTENSITY_PREVIEW_MULTIPLIER := 1.18
const FLAME_CROSS_PHASE_OFFSET := 1.37
const FLAME_CROSS_INTENSITY_SCALE := 0.92

var _trail_visual: MeshInstance3D = null
var _trail_visual_cross: MeshInstance3D = null
var _trail_visible := false
var _preview_mode := false
var _preview_origin := Vector3.ZERO
var _preview_time_sec := 0.0
var _preview_previous_position := Vector3.ZERO
var _runtime_direction := Vector3.FORWARD
var _runtime_speed_mps := 0.0
var _runtime_active := false
var _last_runtime_sync_frame := -1
var _preview_camera: Camera3D = null
var _preview_previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _preview_camera_yaw_rad := 0.0
var _preview_camera_pitch_rad := 0.0
var _preview_camera_local_position := Vector3.ZERO
var _preview_mouse_captured := false
var _preview_move_forward := false
var _preview_move_backward := false
var _preview_move_left := false
var _preview_move_right := false
var _preview_move_up := false
var _preview_move_down := false
var _preview_move_fast := false
var _model_back_extent_m := 0.58

func _ready() -> void:
	_preview_origin = global_position
	_preview_previous_position = global_position
	_trail_visual = get_node_or_null("TrailVisual") as MeshInstance3D
	_trail_visual_cross = get_node_or_null("TrailVisualCross") as MeshInstance3D
	_preview_camera = get_node_or_null("PreviewCamera") as Camera3D
	_ensure_trail_visuals()
	_model_back_extent_m = _measure_model_back_extent()
	_refresh_preview_mode()
	_apply_preview_helper_state()
	_update_trail_visual(_runtime_direction, 0.0, false)

func _process(delta: float) -> void:
	_refresh_preview_mode()
	if _preview_mode and not _was_synced_this_frame():
		_advance_preview(delta)
		_update_preview_camera(delta)
		return
	if not _was_synced_this_frame():
		_update_trail_visual(_runtime_direction, 0.0, false)

func _input(event: InputEvent) -> void:
	if not _preview_mode:
		return
	if event is InputEventMouseMotion and _preview_mouse_captured:
		var motion := event as InputEventMouseMotion
		_apply_preview_look_delta(motion.relative)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE):
			_capture_preview_mouse()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		_update_preview_key_state(key_event)
		if key_event.pressed and not key_event.echo and _resolve_event_keycode(key_event) == KEY_ESCAPE:
			_toggle_preview_mouse_capture()

func _exit_tree() -> void:
	if _preview_mode:
		_restore_preview_mouse_mode()

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

func get_debug_state() -> Dictionary:
	var preview_camera := _preview_camera
	var preview_light := get_node_or_null("PreviewLight") as Node3D
	return {
		"trail_present": _trail_visual != null and is_instance_valid(_trail_visual),
		"trail_cross_present": _trail_visual_cross != null and is_instance_valid(_trail_visual_cross),
		"trail_visible": _trail_visible and _trail_visual != null and is_instance_valid(_trail_visual) and _trail_visual.visible,
		"preview_mode": _preview_mode,
		"preview_camera_current": preview_camera != null and preview_camera.current,
		"preview_camera_local_position": preview_camera.position if preview_camera != null else Vector3.ZERO,
		"preview_camera_world_position": preview_camera.global_position if preview_camera != null else Vector3.ZERO,
		"preview_camera_forward": (-preview_camera.transform.basis.z).normalized() if preview_camera != null else Vector3.FORWARD,
		"preview_light_visible": preview_light != null and preview_light.visible,
		"preview_mouse_captured": _preview_mouse_captured,
		"runtime_active": _runtime_active,
		"runtime_speed_mps": _runtime_speed_mps,
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

func _apply_preview_helper_state() -> void:
	var preview_camera := _preview_camera
	if preview_camera != null:
		preview_camera.current = _preview_mode
	var preview_light := get_node_or_null("PreviewLight") as Node3D
	if preview_light != null:
		preview_light.visible = _preview_mode

func _refresh_preview_mode() -> void:
	var resolved_preview_mode := _detect_preview_mode()
	if resolved_preview_mode == _preview_mode:
		return
	_preview_mode = resolved_preview_mode
	if _preview_mode:
		_preview_origin = global_position
		_preview_previous_position = global_position
		_preview_time_sec = 0.0
		_initialize_preview_camera_state()
		_capture_preview_mouse()
	else:
		_restore_preview_mouse_mode()
		_reset_preview_move_state()
	_apply_preview_helper_state()

func _detect_preview_mode() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if tree.current_scene == self:
		return true
	return get_parent() == tree.root

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
	if _preview_mode:
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

func _initialize_preview_camera_state() -> void:
	if _preview_camera == null or not is_instance_valid(_preview_camera):
		return
	_preview_camera_local_position = _preview_camera.position
	var local_forward := (-_preview_camera.transform.basis.z).normalized()
	_preview_camera_pitch_rad = clampf(asin(clampf(local_forward.y, -1.0, 1.0)), PREVIEW_CAMERA_PITCH_MIN_RAD, PREVIEW_CAMERA_PITCH_MAX_RAD)
	_preview_camera_yaw_rad = atan2(local_forward.x, -local_forward.z)
	_apply_preview_camera_transform()

func _update_preview_camera(delta: float) -> void:
	if _preview_camera == null or not is_instance_valid(_preview_camera):
		return
	var move_direction := Vector3.ZERO
	var camera_basis := _preview_camera.transform.basis
	if _preview_move_forward:
		move_direction += -camera_basis.z
	if _preview_move_backward:
		move_direction += camera_basis.z
	if _preview_move_left:
		move_direction += -camera_basis.x
	if _preview_move_right:
		move_direction += camera_basis.x
	if _preview_move_up:
		move_direction += Vector3.UP
	if _preview_move_down:
		move_direction += Vector3.DOWN
	if move_direction.length_squared() <= 0.0001:
		return
	var speed_mps := PREVIEW_CAMERA_MOVE_SPEED_MPS * (PREVIEW_CAMERA_SPRINT_MULTIPLIER if _preview_move_fast else 1.0)
	_preview_camera_local_position += move_direction.normalized() * speed_mps * maxf(delta, 0.0)
	_apply_preview_camera_transform()

func _apply_preview_look_delta(relative: Vector2) -> void:
	_preview_camera_yaw_rad -= relative.x * PREVIEW_CAMERA_LOOK_SENSITIVITY
	_preview_camera_pitch_rad = clampf(
		_preview_camera_pitch_rad - relative.y * PREVIEW_CAMERA_LOOK_SENSITIVITY,
		PREVIEW_CAMERA_PITCH_MIN_RAD,
		PREVIEW_CAMERA_PITCH_MAX_RAD
	)
	_apply_preview_camera_transform()

func _apply_preview_camera_transform() -> void:
	if _preview_camera == null or not is_instance_valid(_preview_camera):
		return
	_preview_camera.position = _preview_camera_local_position
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, _preview_camera_yaw_rad)
	basis = basis.rotated(Vector3.RIGHT, _preview_camera_pitch_rad)
	_preview_camera.transform = Transform3D(basis.orthonormalized(), _preview_camera.position)

func _update_preview_key_state(key_event: InputEventKey) -> void:
	if key_event.echo:
		return
	var keycode := _resolve_event_keycode(key_event)
	var pressed := key_event.pressed
	match keycode:
		KEY_W:
			_preview_move_forward = pressed
		KEY_S:
			_preview_move_backward = pressed
		KEY_A:
			_preview_move_left = pressed
		KEY_D:
			_preview_move_right = pressed
		KEY_E:
			_preview_move_up = pressed
		KEY_Q:
			_preview_move_down = pressed
		KEY_SHIFT:
			_preview_move_fast = pressed

func _resolve_event_keycode(key_event: InputEventKey) -> Key:
	return key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode

func _capture_preview_mouse() -> void:
	_preview_previous_mouse_mode = Input.mouse_mode
	_preview_mouse_captured = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _toggle_preview_mouse_capture() -> void:
	if _preview_mouse_captured:
		_preview_mouse_captured = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_capture_preview_mouse()

func _restore_preview_mouse_mode() -> void:
	_preview_mouse_captured = false
	Input.set_mouse_mode(_preview_previous_mouse_mode)

func _reset_preview_move_state() -> void:
	_preview_move_forward = false
	_preview_move_backward = false
	_preview_move_left = false
	_preview_move_right = false
	_preview_move_up = false
	_preview_move_down = false
	_preview_move_fast = false

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
