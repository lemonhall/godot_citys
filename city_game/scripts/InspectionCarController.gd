extends CharacterBody3D

@export var acceleration := 26.0
@export var brake_deceleration := 42.0
@export var coast_deceleration := 12.0
@export var max_forward_speed := 42.0
@export var turbo_forward_speed := 120.0
@export var max_reverse_speed := 18.0
@export var steer_limit := 0.65
@export var steer_response := 3.2
@export var yaw_rate := 1.8

@onready var camera_rig: Node3D = $CameraRig

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _control_enabled := false
var _forward_speed := 0.0
var _steer_angle := 0.0

func _ready() -> void:
	camera_rig.rotation.x = deg_to_rad(-14.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var throttle: float = _read_throttle_input() if _control_enabled else 0.0
	var steer_target: float = (_read_steer_input() if _control_enabled else 0.0) * steer_limit
	_steer_angle = move_toward(_steer_angle, steer_target, steer_response * delta)
	_forward_speed = _integrate_forward_speed(_forward_speed, throttle, delta)

	var speed_ratio: float = clamp(absf(_forward_speed) / maxf(_current_top_speed(), 0.01), 0.0, 1.0)
	if speed_ratio > 0.01 and absf(_steer_angle) > 0.001:
		rotate_y(_steer_angle * yaw_rate * speed_ratio * signf(_forward_speed) * delta)

	var forward: Vector3 = -global_transform.basis.z
	velocity.x = forward.x * _forward_speed
	velocity.z = forward.z * _forward_speed
	move_and_slide()

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		_forward_speed = move_toward(_forward_speed, 0.0, brake_deceleration * 0.25)

func is_control_enabled() -> bool:
	return _control_enabled

func teleport_to_world_position(world_position: Vector3) -> void:
	global_position = world_position
	velocity = Vector3.ZERO
	_forward_speed = 0.0

func advance_toward_world_position(target_position: Vector3, step_distance: float) -> bool:
	var planar_delta := Vector3(target_position.x - global_position.x, 0.0, target_position.z - global_position.z)
	var planar_distance := planar_delta.length()
	if planar_distance <= step_distance:
		global_position = Vector3(target_position.x, target_position.y, target_position.z)
		velocity = Vector3.ZERO
		_forward_speed = 0.0
		return true

	var direction: Vector3 = planar_delta / planar_distance
	look_at(global_position + direction, Vector3.UP)
	global_position += direction * step_distance
	global_position.y = target_position.y
	velocity = Vector3.ZERO
	_forward_speed = 0.0
	return false

func get_speed_mps() -> float:
	return absf(_forward_speed)

func _read_throttle_input() -> float:
	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		throttle -= 1.0
	return throttle

func _read_steer_input() -> float:
	var steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		steer += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		steer -= 1.0
	return steer

func _integrate_forward_speed(current_speed: float, throttle: float, delta: float) -> float:
	if throttle > 0.0:
		return move_toward(current_speed, _current_top_speed(), acceleration * delta)
	if throttle < 0.0:
		if current_speed > 0.0:
			return move_toward(current_speed, 0.0, brake_deceleration * delta)
		return move_toward(current_speed, -max_reverse_speed, acceleration * delta)
	return move_toward(current_speed, 0.0, coast_deceleration * delta)

func _current_top_speed() -> float:
	return turbo_forward_speed if Input.is_key_pressed(KEY_SHIFT) else max_forward_speed
