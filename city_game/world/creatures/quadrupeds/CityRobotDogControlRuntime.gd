extends CharacterBody3D

const SYSTEM_STATE_STOWED := "stowed"
const SYSTEM_STATE_ACTIVE := "active"
const INPUT_KEYCODES := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_P]

@export var visual_scale := 4.0
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

@onready var visual_mount: Node3D = $VisualMount
@onready var robot_dog: Node3D = $VisualMount/RobotDog
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _player_owner: Node3D = null
var _player_camera: Camera3D = null
var _system_state := SYSTEM_STATE_STOWED
var _locked_player_position := Vector3.ZERO
var _pressed_keys := {}
var _move_input := Vector2.ZERO
var _turn_input := 0.0
var _sprint_requested := false
var _speed_mps := 0.0
var _camera_pitch_rad := 0.0
var _default_camera_pitch_rad := 0.0

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

func activate_at(world_position: Vector3, heading_rad: float) -> void:
	global_position = world_position
	rotation = Vector3(0.0, heading_rad, 0.0)
	velocity = Vector3.ZERO
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_speed_mps = 0.0
	_restore_camera_pitch()
	floor_snap_length = floor_snap_length_m
	if robot_dog != null and robot_dog.has_method("reset_robot_dog_pose"):
		robot_dog.reset_robot_dog_pose()
	_set_player_lock(true)
	_system_state = SYSTEM_STATE_ACTIVE
	_apply_camera_ownership()
	_set_mouse_capture(true)

func deactivate() -> void:
	_pressed_keys.clear()
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_speed_mps = 0.0
	velocity = Vector3.ZERO
	_sync_visual_robot_dog(0.0)
	_system_state = SYSTEM_STATE_STOWED
	_set_player_lock(false)
	_apply_camera_ownership()
	_restore_camera_pitch()
	_set_mouse_capture(false)

func get_visual_robot_dog() -> Node3D:
	return robot_dog

func handle_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _system_state != SYSTEM_STATE_ACTIVE:
			return false
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
		return _system_state == SYSTEM_STATE_ACTIVE
	var key_event := event as InputEventKey
	if key_event == null:
		return false
	var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if not INPUT_KEYCODES.has(keycode):
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
		"control_owner": "robot_dog" if _system_state == SYSTEM_STATE_ACTIVE else "player",
		"camera_mode": "third_person" if _system_state == SYSTEM_STATE_ACTIVE else "player",
		"locomotion_state": locomotion_state,
		"move_input": _move_input,
		"turn_input": _turn_input,
		"speed_mps": _speed_mps,
		"camera_pitch_deg": rad_to_deg(_camera_pitch_rad),
		"gait_cycle_hz": float(locomotion_debug_state.get("gait_cycle_hz", 0.0)),
		"active_robot_dog": _system_state == SYSTEM_STATE_ACTIVE,
		"player_frozen": _is_player_locked(),
		"player_owner_path": str(_player_owner.get_path()) if _player_owner != null and is_instance_valid(_player_owner) else "",
		"world_position": global_position,
		"heading_deg": rad_to_deg(rotation.y),
	}.duplicate(true)

func _physics_process(delta: float) -> void:
	_maintain_player_lock_position()
	if _system_state != SYSTEM_STATE_ACTIVE:
		_speed_mps = 0.0
		return
	_update_control_intent()
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
	if _system_state != SYSTEM_STATE_ACTIVE:
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
		camera.current = _system_state == SYSTEM_STATE_ACTIVE
	if _player_camera != null:
		_player_camera.current = _system_state != SYSTEM_STATE_ACTIVE

func _resolve_player_camera() -> Camera3D:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return null
	return _player_owner.get_node_or_null("CameraRig/Camera3D") as Camera3D

func _is_player_locked() -> bool:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return _system_state == SYSTEM_STATE_ACTIVE
	if _player_owner.has_method("is_movement_locked"):
		return bool(_player_owner.is_movement_locked())
	return _system_state == SYSTEM_STATE_ACTIVE

func _update_control_intent() -> void:
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

func _apply_ground_locomotion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * maxf(delta, 0.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	var move_axis := _move_input.y
	var has_forward_motion := absf(move_axis) > 0.05
	var target_speed := 0.0
	if has_forward_motion:
		if move_axis > 0.0:
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
	return _system_state == SYSTEM_STATE_ACTIVE

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
