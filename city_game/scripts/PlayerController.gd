extends CharacterBody3D

@export var walk_speed := 8.0
@export var sprint_speed := 13.0
@export var inspection_walk_speed := 96.0
@export var inspection_sprint_speed := 180.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003
@export var min_pitch_deg := -68.0
@export var max_pitch_deg := 35.0

@onready var camera_rig: Node3D = $CameraRig

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _pitch := deg_to_rad(-18.0)
var _control_enabled := true
var _speed_profile := "player"

func _ready() -> void:
	camera_rig.rotation.x = _pitch
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _control_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera_rig.rotation.x = _pitch
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _control_enabled and _jump_requested():
		velocity.y = jump_velocity

	var input_dir := _read_move_input() if _control_enabled else Vector2.ZERO
	var move_dir := Vector3.ZERO
	if input_dir.length() > 0.0:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()

		move_dir = (right * input_dir.x + forward * input_dir.y).normalized()

	var speed := _current_sprint_speed() if _sprint_requested() else _current_walk_speed()
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	move_and_slide()

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0

func is_control_enabled() -> bool:
	return _control_enabled

func set_speed_profile(profile: String) -> void:
	if profile != "player" and profile != "inspection":
		return
	_speed_profile = profile

func get_speed_profile() -> String:
	return _speed_profile

func get_walk_speed_mps() -> float:
	return _current_walk_speed()

func get_sprint_speed_mps() -> float:
	return _current_sprint_speed()

func get_pitch_limits_degrees() -> Dictionary:
	return {
		"min": min_pitch_deg,
		"max": max_pitch_deg,
	}

func _read_move_input() -> Vector2:
	var horizontal := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		horizontal += 1.0

	var vertical := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		vertical += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		vertical -= 1.0

	return Vector2(horizontal, vertical).normalized()

func _jump_requested() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept")

func _sprint_requested() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

func _current_walk_speed() -> float:
	return inspection_walk_speed if _speed_profile == "inspection" else walk_speed

func _current_sprint_speed() -> float:
	return inspection_sprint_speed if _speed_profile == "inspection" else sprint_speed

func teleport_to_world_position(world_position: Vector3) -> void:
	global_position = world_position
	velocity = Vector3.ZERO

func advance_toward_world_position(target_position: Vector3, step_distance: float) -> bool:
	var planar_delta := Vector3(target_position.x - global_position.x, 0.0, target_position.z - global_position.z)
	var planar_distance := planar_delta.length()
	if planar_distance <= step_distance:
		global_position = Vector3(target_position.x, target_position.y, target_position.z)
		velocity = Vector3.ZERO
		return true

	var direction := planar_delta / planar_distance
	global_position += direction * step_distance
	global_position.y = target_position.y
	velocity = Vector3.ZERO
	return false
