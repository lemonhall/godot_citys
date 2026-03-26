extends CharacterBody3D

const SYSTEM_STATE_STOWED := "stowed"
const SYSTEM_STATE_ACTIVE := "active"
const BEHAVIOR_MODE_FOLLOW := "follow"
const BEHAVIOR_MODE_CONTROLLED := "controlled"
const CONTROL_TOGGLE_KEY := KEY_INSERT
const CONTROL_INPUT_KEYCODES := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_P]

@export var visual_scale := 3.7
@export var walk_speed_mps := 4.6
@export var run_speed_mps := 6.8
@export var backward_speed_mps := 2.2
@export var ground_accel_mps2 := 20.0
@export var ground_decel_mps2 := 22.0
@export var turn_rate_deg := 96.0
@export var turn_move_rate_deg := 76.0
@export var floor_snap_length_m := 0.45
@export var mouse_sensitivity := 0.003
@export var min_pitch_deg := -68.0
@export var max_pitch_deg := 35.0
@export var follow_walk_speed_mps := 6.6
@export var follow_run_speed_mps := 10.4
@export var follow_lateral_offset_m := 1.85
@export var follow_forward_offset_m := -0.35
@export var follow_stop_distance_m := 0.48
@export var follow_run_distance_m := 2.2
@export var follow_turn_deadzone_deg := 6.0
@export var follow_move_heading_threshold_deg := 82.0
@export var follow_heading_blend_distance_m := 2.4
@export var follow_teleport_recover_distance_m := 7.0

@onready var visual_mount: Node3D = $VisualMount
@onready var robot_dog: Node3D = $VisualMount/RobotDog
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _player_owner: Node3D = null
var _player_camera: Camera3D = null
var _system_state := SYSTEM_STATE_STOWED
var _behavior_mode := BEHAVIOR_MODE_CONTROLLED
var _locked_player_position := Vector3.ZERO
var _pressed_keys := {}
var _move_input := Vector2.ZERO
var _turn_input := 0.0
var _sprint_requested := false
var _speed_mps := 0.0
var _target_speed_override_mps := -1.0
var _camera_pitch_rad := 0.0
var _default_camera_pitch_rad := 0.0
var _follow_anchor_world_position := Vector3.ZERO
var _follow_distance_m := 0.0
var _follow_player_speed_mps := 0.0
var _last_player_owner_world_position := Vector3.ZERO

func _ready() -> void:
	if visual_mount != null:
		visual_mount.scale = Vector3.ONE * visual_scale
	if camera_rig != null:
		_default_camera_pitch_rad = camera_rig.rotation.x
		_camera_pitch_rad = _default_camera_pitch_rad
	if camera != null:
		camera.current = false
	if robot_dog != null and robot_dog.has_method("reset_robot_dog_pose"):
		robot_dog.reset_robot_dog_pose()

func bind_player_owner(player_owner: Node3D) -> void:
	_player_owner = player_owner
	_player_camera = _resolve_player_camera()
	if _player_owner != null and is_instance_valid(_player_owner):
		_last_player_owner_world_position = _player_owner.global_position

func activate_at(world_position: Vector3, heading_rad: float, start_in_follow_mode: bool = false) -> void:
	global_position = world_position
	rotation = Vector3(0.0, heading_rad, 0.0)
	velocity = Vector3.ZERO
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_speed_mps = 0.0
	_target_speed_override_mps = -1.0
	_restore_camera_pitch()
	floor_snap_length = floor_snap_length_m
	if robot_dog != null and robot_dog.has_method("reset_robot_dog_pose"):
		robot_dog.reset_robot_dog_pose()
	_system_state = SYSTEM_STATE_ACTIVE
	_follow_anchor_world_position = world_position
	_follow_distance_m = 0.0
	_follow_player_speed_mps = 0.0
	if _player_owner != null and is_instance_valid(_player_owner):
		_last_player_owner_world_position = _player_owner.global_position
	_set_behavior_mode(BEHAVIOR_MODE_FOLLOW if start_in_follow_mode else BEHAVIOR_MODE_CONTROLLED)

func deactivate() -> void:
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_speed_mps = 0.0
	_target_speed_override_mps = -1.0
	velocity = Vector3.ZERO
	_sync_visual_robot_dog(0.0)
	_system_state = SYSTEM_STATE_STOWED
	_behavior_mode = BEHAVIOR_MODE_CONTROLLED
	_follow_anchor_world_position = Vector3.ZERO
	_follow_distance_m = 0.0
	_follow_player_speed_mps = 0.0
	_set_player_lock(false)
	_apply_camera_ownership()
	_restore_camera_pitch()
	_set_mouse_capture(false)

func get_visual_robot_dog() -> Node3D:
	return robot_dog

func handle_input_event(event: InputEvent) -> bool:
	if _system_state != SYSTEM_STATE_ACTIVE:
		return false
	var key_event := event as InputEventKey
	if key_event != null:
		var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if keycode == CONTROL_TOGGLE_KEY and key_event.pressed and not key_event.echo:
			_set_behavior_mode(BEHAVIOR_MODE_FOLLOW if _is_controlled_mode() else BEHAVIOR_MODE_CONTROLLED)
			return true
	if not _is_controlled_mode():
		return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera_pitch_rad = clamp(_camera_pitch_rad - motion.relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		_apply_camera_pitch()
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			_set_mouse_capture(true)
		return _system_state == SYSTEM_STATE_ACTIVE
	if event.is_action_pressed("ui_cancel"):
		if DisplayServer.get_name() != "headless":
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
		return true
	if key_event == null:
		return false
	var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if not CONTROL_INPUT_KEYCODES.has(keycode):
		return false
	if keycode == KEY_P and key_event.pressed and not key_event.echo:
		if robot_dog != null and robot_dog.has_method("toggle_crouch_requested"):
			robot_dog.toggle_crouch_requested()
		return true
	_pressed_keys[keycode] = key_event.pressed
	return true

func get_debug_state() -> Dictionary:
	var locomotion_debug_state := _get_robot_dog_locomotion_debug_state()
	var locomotion_state := "stowed"
	if _system_state == SYSTEM_STATE_ACTIVE:
		locomotion_state = str(locomotion_debug_state.get("locomotion_state", "idle"))
	return {
		"system_state": _system_state,
		"behavior_mode": _behavior_mode if _system_state == SYSTEM_STATE_ACTIVE else "stowed",
		"control_owner": "robot_dog" if _is_controlled_mode() else "player",
		"camera_mode": "third_person" if _is_controlled_mode() else "player",
		"locomotion_state": locomotion_state,
		"move_input": _move_input,
		"turn_input": _turn_input,
		"speed_mps": _speed_mps,
		"camera_pitch_deg": rad_to_deg(_camera_pitch_rad),
		"gait_cycle_hz": float(locomotion_debug_state.get("gait_cycle_hz", 0.0)),
		"active_robot_dog": _system_state == SYSTEM_STATE_ACTIVE,
		"should_drive_world_streaming": should_drive_world_streaming(),
		"player_frozen": _is_player_locked(),
		"player_owner_path": str(_player_owner.get_path()) if _player_owner != null and is_instance_valid(_player_owner) else "",
		"follow_anchor_world_position": _follow_anchor_world_position,
		"follow_distance_m": _follow_distance_m,
		"follow_player_speed_mps": _follow_player_speed_mps,
		"formation_lateral_offset_m": follow_lateral_offset_m,
		"formation_forward_offset_m": follow_forward_offset_m,
		"world_position": global_position,
		"heading_deg": rad_to_deg(rotation.y),
	}.duplicate(true)

func _physics_process(delta: float) -> void:
	_maintain_player_lock_position()
	if _system_state != SYSTEM_STATE_ACTIVE:
		_speed_mps = 0.0
		return
	if _is_controlled_mode():
		_update_manual_control_intent()
	else:
		_update_follow_control_intent(delta)
	_apply_ground_locomotion(delta)
	_sync_visual_robot_dog(delta)

func _set_player_lock(locked: bool) -> void:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return
	if locked:
		_locked_player_position = _player_owner.global_position
	if _player_owner.has_method("set_control_enabled"):
		_player_owner.set_control_enabled(not locked)
	if _player_owner.has_method("set_movement_locked"):
		_player_owner.set_movement_locked(locked)

func _maintain_player_lock_position() -> void:
	if not _is_controlled_mode():
		return
	if _player_owner == null or not is_instance_valid(_player_owner):
		return
	if _player_owner.has_method("teleport_to_world_position"):
		_player_owner.teleport_to_world_position(_locked_player_position)
	else:
		_player_owner.global_position = _locked_player_position

func _apply_camera_ownership() -> void:
	_player_camera = _resolve_player_camera()
	if camera != null:
		camera.current = _is_controlled_mode()
	if _player_camera != null:
		_player_camera.current = not _is_controlled_mode()

func _resolve_player_camera() -> Camera3D:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return null
	return _player_owner.get_node_or_null("CameraRig/Camera3D") as Camera3D

func _is_player_locked() -> bool:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return _is_controlled_mode()
	if _player_owner.has_method("is_movement_locked"):
		return bool(_player_owner.is_movement_locked())
	return _is_controlled_mode()

func _update_manual_control_intent() -> void:
	var forward_input := 0.0
	if bool(_pressed_keys.get(KEY_W, false)):
		forward_input += 1.0
	if bool(_pressed_keys.get(KEY_S, false)):
		forward_input -= 1.0
	var turn_input := 0.0
	if bool(_pressed_keys.get(KEY_D, false)):
		turn_input -= 1.0
	if bool(_pressed_keys.get(KEY_A, false)):
		turn_input += 1.0
	var prone_active := _is_prone_active()
	_sprint_requested = bool(_pressed_keys.get(KEY_SHIFT, false)) and forward_input > 0.0 and not prone_active
	if prone_active:
		forward_input = 0.0
		turn_input = 0.0
	_move_input = Vector2(0.0, clampf(forward_input, -1.0, 1.0))
	_turn_input = clampf(turn_input, -1.0, 1.0)
	_target_speed_override_mps = -1.0

func _update_follow_control_intent(delta: float) -> void:
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_target_speed_override_mps = -1.0
	if _player_owner == null or not is_instance_valid(_player_owner):
		_follow_anchor_world_position = global_position
		_follow_distance_m = 0.0
		_follow_player_speed_mps = 0.0
		return
	var player_forward := _resolve_player_planar_forward()
	var player_right := _resolve_player_planar_right()
	var player_position := _player_owner.global_position
	_follow_anchor_world_position = player_position + player_right * follow_lateral_offset_m + player_forward * follow_forward_offset_m
	var to_anchor := _follow_anchor_world_position - global_position
	to_anchor.y = 0.0
	_follow_distance_m = to_anchor.length()
	_follow_player_speed_mps = _resolve_player_planar_speed_mps(delta)
	if _follow_distance_m >= follow_teleport_recover_distance_m:
		global_position = Vector3(_follow_anchor_world_position.x, player_position.y, _follow_anchor_world_position.z)
		velocity.x = 0.0
		velocity.z = 0.0
		rotation.y = atan2(player_forward.x, -player_forward.z)
		to_anchor = Vector3.ZERO
		_follow_distance_m = 0.0
	var current_forward := _resolve_planar_forward()
	var desired_forward := player_forward
	if to_anchor.length_squared() > 0.0001 and _follow_distance_m > follow_stop_distance_m:
		var anchor_forward := to_anchor.normalized()
		if _follow_distance_m >= follow_run_distance_m:
			desired_forward = anchor_forward.slerp(player_forward, 0.18).normalized()
		else:
			var heading_blend := clampf(
				(_follow_distance_m - follow_stop_distance_m) / maxf(follow_heading_blend_distance_m - follow_stop_distance_m, 0.001),
				0.0,
				1.0
			)
			desired_forward = player_forward.slerp(anchor_forward, heading_blend * 0.45).normalized()
	var heading_delta_deg := _signed_heading_delta_deg(current_forward, desired_forward)
	if absf(heading_delta_deg) >= follow_turn_deadzone_deg:
		_turn_input = clampf(heading_delta_deg / 50.0, -1.0, 1.0)
	var should_move := _follow_distance_m > follow_stop_distance_m
	if should_move and absf(heading_delta_deg) > follow_move_heading_threshold_deg and _follow_distance_m < follow_run_distance_m:
		should_move = false
	if should_move:
		_move_input = Vector2(0.0, 1.0)
		var desired_speed_mps := clampf(_follow_distance_m * 4.2, follow_walk_speed_mps * 0.42, follow_walk_speed_mps)
		if _follow_distance_m >= follow_run_distance_m:
			desired_speed_mps = minf(follow_run_speed_mps, maxf(follow_walk_speed_mps, _follow_distance_m * 2.8))
		if _follow_player_speed_mps >= follow_walk_speed_mps * 0.92:
			desired_speed_mps = maxf(desired_speed_mps, follow_run_speed_mps * 0.86)
		_sprint_requested = desired_speed_mps > follow_walk_speed_mps + 0.2
		_target_speed_override_mps = desired_speed_mps
	if _follow_distance_m <= follow_stop_distance_m and _follow_player_speed_mps <= 0.2:
		_move_input = Vector2.ZERO
		_target_speed_override_mps = -1.0
		_sprint_requested = false

func _apply_ground_locomotion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * maxf(delta, 0.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	var move_axis := _move_input.y
	var has_forward_motion := absf(move_axis) > 0.05
	var target_speed := 0.0
	if has_forward_motion:
		if _target_speed_override_mps >= 0.0:
			target_speed = _target_speed_override_mps
		elif move_axis > 0.0:
			target_speed = run_speed_mps if _sprint_requested else walk_speed_mps
		else:
			target_speed = backward_speed_mps
	var active_turn_rate_deg := turn_move_rate_deg if has_forward_motion else turn_rate_deg
	if absf(_turn_input) > 0.05:
		rotation.y += deg_to_rad(active_turn_rate_deg * _turn_input * maxf(delta, 0.0))
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target_velocity := forward * target_speed * signf(move_axis)
	var accel := ground_accel_mps2 if target_velocity.length() > Vector2(velocity.x, velocity.z).length() else ground_decel_mps2
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * maxf(delta, 0.0))
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * maxf(delta, 0.0))
	if velocity.y <= 0.0:
		apply_floor_snap()
	move_and_slide()
	_speed_mps = Vector2(velocity.x, velocity.z).length()

func _sync_visual_robot_dog(delta: float) -> void:
	if robot_dog == null:
		return
	if robot_dog.has_method("set_motion_command"):
		robot_dog.set_motion_command(_move_input, _turn_input, _sprint_requested, _speed_mps)
	if robot_dog.has_method("tick_robot_dog"):
		robot_dog.tick_robot_dog(delta)

func _get_robot_dog_locomotion_debug_state() -> Dictionary:
	if robot_dog == null or not robot_dog.has_method("get_locomotion_debug_state"):
		return {}
	return (robot_dog.get_locomotion_debug_state() as Dictionary).duplicate(true)

func _is_prone_active() -> bool:
	if robot_dog == null or not robot_dog.has_method("get_pose_debug_state"):
		return false
	var pose_debug_state: Dictionary = robot_dog.get_pose_debug_state()
	return bool(pose_debug_state.get("crouch_requested", false)) or float(pose_debug_state.get("crouch_alpha", 0.0)) > 0.05

func should_drive_world_streaming() -> bool:
	return _is_controlled_mode()

func get_focus_heading_rad() -> float:
	var forward := _resolve_planar_forward()
	return atan2(forward.x, -forward.z)

func get_focus_world_position() -> Vector3:
	return global_position

func _restore_camera_pitch() -> void:
	_camera_pitch_rad = _default_camera_pitch_rad
	_apply_camera_pitch()

func _apply_camera_pitch() -> void:
	if camera_rig != null:
		camera_rig.rotation.x = _camera_pitch_rad

func _set_mouse_capture(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE)

func _resolve_planar_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()

func _is_controlled_mode() -> bool:
	return _system_state == SYSTEM_STATE_ACTIVE and _behavior_mode == BEHAVIOR_MODE_CONTROLLED

func _set_behavior_mode(mode: String) -> void:
	var resolved_mode := BEHAVIOR_MODE_FOLLOW if mode == BEHAVIOR_MODE_FOLLOW else BEHAVIOR_MODE_CONTROLLED
	_behavior_mode = resolved_mode
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_target_speed_override_mps = -1.0
	if _is_controlled_mode():
		_set_player_lock(true)
		_apply_camera_ownership()
		_set_mouse_capture(true)
		return
	_set_player_lock(false)
	_apply_camera_ownership()

func _resolve_player_planar_forward() -> Vector3:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return _resolve_planar_forward()
	var forward := -_player_owner.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()

func _resolve_player_planar_right() -> Vector3:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return Vector3.RIGHT
	var right := _player_owner.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return right.normalized()

func _resolve_player_planar_speed_mps(delta: float) -> float:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return 0.0
	var player_character := _player_owner as CharacterBody3D
	if player_character != null:
		return Vector2(player_character.velocity.x, player_character.velocity.z).length()
	var current_position := _player_owner.global_position
	var planar_distance := Vector2(
		current_position.x - _last_player_owner_world_position.x,
		current_position.z - _last_player_owner_world_position.z
	).length()
	_last_player_owner_world_position = current_position
	return planar_distance / maxf(delta, 0.001)

func _signed_heading_delta_deg(current_forward: Vector3, desired_forward: Vector3) -> float:
	if current_forward.length_squared() <= 0.0001 or desired_forward.length_squared() <= 0.0001:
		return 0.0
	var normalized_current := current_forward.normalized()
	var normalized_desired := desired_forward.normalized()
	var signed_angle_rad := atan2(normalized_current.cross(normalized_desired).y, clampf(normalized_current.dot(normalized_desired), -1.0, 1.0))
	return rad_to_deg(signed_angle_rad)
