extends CharacterBody3D

@export var walk_speed := 8.0
@export var sprint_speed := 13.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

@onready var camera_rig: Node3D = $CameraRig

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _pitch := deg_to_rad(-18.0)

func _ready() -> void:
	camera_rig.rotation.x = _pitch
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(-60.0), deg_to_rad(10.0))
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
	elif _jump_requested():
		velocity.y = jump_velocity

	var input_dir := _read_move_input()
	var move_dir := Vector3.ZERO
	if input_dir.length() > 0.0:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()

		move_dir = (right * input_dir.x + forward * input_dir.y).normalized()

	var speed := sprint_speed if _sprint_requested() else walk_speed
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	move_and_slide()

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
