extends CharacterBody3D

signal primary_fire_requested

@export var walk_speed := 8.0
@export var sprint_speed := 13.0
@export var inspection_walk_speed := 96.0
@export var inspection_sprint_speed := 180.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003
@export var min_pitch_deg := -68.0
@export var max_pitch_deg := 35.0
@export var player_floor_snap_length := 0.9
@export var inspection_floor_snap_length := 1.8
@export var primary_fire_cooldown_sec := 0.12
@export var primary_fire_shoulder_offset := Vector3(0.46, 1.22, -0.18)
@export var primary_fire_forward_offset_m := 0.72
@export var aim_trace_distance_m := 240.0

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _pitch := deg_to_rad(-18.0)
var _control_enabled := true
var _speed_profile := "player"
var _stabilization_suspend_frames := 0
var _collision_resume_process_frames := 0
var _primary_fire_cooldown_remaining := 0.0
var _primary_fire_active := false

func _ready() -> void:
	camera_rig.rotation.x = _pitch
	floor_snap_length = _current_floor_snap_length()
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if _primary_fire_cooldown_remaining > 0.0:
		_primary_fire_cooldown_remaining = maxf(_primary_fire_cooldown_remaining - delta, 0.0)
	if _primary_fire_active and _control_enabled:
		request_primary_fire()
	if _collision_resume_process_frames <= 0:
		return
	_collision_resume_process_frames -= 1
	if _collision_resume_process_frames == 0:
		_set_primary_collision_enabled(true)

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
		if button.button_index == MOUSE_BUTTON_LEFT:
			set_primary_fire_active(button.pressed)
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	floor_snap_length = _current_floor_snap_length()
	if _stabilization_suspend_frames > 0:
		_stabilization_suspend_frames -= 1
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

	if velocity.y <= 0.0 and not _jump_requested():
		apply_floor_snap()
	move_and_slide()
	if _stabilization_suspend_frames <= 0 and velocity.y <= 0.0 and not _jump_requested():
		var snapped_to_ground := _stabilize_ground_contact()
		if snapped_to_ground and not is_on_floor():
			apply_floor_snap()
			velocity.y = -0.01
			move_and_slide()

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		_primary_fire_active = false
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

func get_floor_snap_config() -> Dictionary:
	return {
		"player": player_floor_snap_length,
		"inspection": inspection_floor_snap_length,
	}

func set_primary_fire_active(active: bool) -> void:
	_primary_fire_active = active and _control_enabled
	if _primary_fire_active:
		request_primary_fire()

func request_primary_fire() -> bool:
	if not _control_enabled:
		return false
	if _primary_fire_cooldown_remaining > 0.0:
		return false
	_primary_fire_cooldown_remaining = primary_fire_cooldown_sec
	primary_fire_requested.emit()
	return true

func get_projectile_spawn_transform() -> Transform3D:
	var basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
	var right := global_transform.basis.x.normalized()
	var up := Vector3.UP
	var player_forward := (-global_transform.basis.z).normalized()
	var origin := global_position
	origin += right * primary_fire_shoulder_offset.x
	origin += up * primary_fire_shoulder_offset.y
	origin += player_forward * (primary_fire_forward_offset_m + primary_fire_shoulder_offset.z)
	return Transform3D(basis, origin)

func get_projectile_direction() -> Vector3:
	var spawn_origin := get_projectile_spawn_transform().origin
	var aim_target := _resolve_aim_target_world_position()
	return (aim_target - spawn_origin).normalized()

func _resolve_aim_target_world_position() -> Vector3:
	var basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
	var origin := camera.global_position if camera != null else global_position + Vector3.UP * 1.4
	var forward := (-basis.z).normalized()
	var fallback_target := origin + forward * aim_trace_distance_m
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return fallback_target
	var query := PhysicsRayQueryParameters3D.create(origin, fallback_target)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback_target
	return hit.get("position", fallback_target)

func suspend_ground_stabilization(frame_count: int) -> void:
	_stabilization_suspend_frames = maxi(_stabilization_suspend_frames, frame_count)

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

func _current_floor_snap_length() -> float:
	return inspection_floor_snap_length if _speed_profile == "inspection" else player_floor_snap_length

func _stabilize_ground_contact() -> bool:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return false
	var standing_height := _estimate_standing_height()
	var probe_length := standing_height + _current_floor_snap_length() + 0.6
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.25,
		global_position + Vector3.DOWN * probe_length
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", global_position)
	var target_y := hit_position.y + standing_height
	if absf(global_position.y - target_y) > _current_floor_snap_length() + 0.75:
		return false
	global_position.y = target_y
	velocity.y = 0.0
	return true

func _estimate_standing_height() -> float:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func teleport_to_world_position(world_position: Vector3) -> void:
	_suspend_primary_collision_for_frames(2)
	global_position = world_position
	velocity = Vector3.ZERO

func advance_toward_world_position(target_position: Vector3, step_distance: float) -> bool:
	var planar_delta := Vector3(target_position.x - global_position.x, 0.0, target_position.z - global_position.z)
	var planar_distance := planar_delta.length()
	if planar_distance <= step_distance:
		_suspend_primary_collision_for_frames(2)
		global_position = Vector3(target_position.x, target_position.y, target_position.z)
		velocity = Vector3.ZERO
		return true

	var direction := planar_delta / planar_distance
	global_position += direction * step_distance
	global_position.y = target_position.y
	velocity = Vector3.ZERO
	return false

func _suspend_primary_collision_for_frames(frame_count: int) -> void:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return
	_set_primary_collision_enabled(false)
	_collision_resume_process_frames = maxi(_collision_resume_process_frames, frame_count)

func _set_primary_collision_enabled(enabled: bool) -> void:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return
	collision_shape.disabled = not enabled
