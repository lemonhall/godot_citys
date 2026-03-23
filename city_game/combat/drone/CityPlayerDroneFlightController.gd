extends RefCounted

var max_planar_speed_mps := 26.0
var planar_accel_mps2 := 42.0
var planar_brake_mps2 := 42.0
var max_vertical_speed_mps := 6.8
var vertical_accel_mps2 := 42.0
var yaw_turn_speed_rad := 6.0
var visual_response := 8.5
var max_roll_deg := 11.0
var max_pitch_deg := 16.0

func step(drone: CharacterBody3D, camera: Camera3D, visual_root: Node3D, delta: float) -> Dictionary:
	if drone == null or camera == null:
		return {
			"planar_speed_mps": 0.0,
			"vertical_speed_mps": 0.0,
		}
	var input_state := _read_input_state()
	var planar_input: Vector2 = input_state.get("planar_input", Vector2.ZERO)
	var vertical_input := float(input_state.get("vertical_input", 0.0))
	var target_basis := camera.global_transform.basis
	var forward := -target_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = -drone.global_transform.basis.z
	forward = forward.normalized()
	var right := target_basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = drone.global_transform.basis.x
	right = right.normalized()
	var desired_direction := (right * planar_input.x + forward * planar_input.y)
	if desired_direction.length_squared() > 1.0:
		desired_direction = desired_direction.normalized()
	var target_planar_velocity := desired_direction * max_planar_speed_mps
	var current_planar_velocity := Vector3(drone.velocity.x, 0.0, drone.velocity.z)
	var planar_step := (planar_accel_mps2 if target_planar_velocity.length_squared() > current_planar_velocity.length_squared() else planar_brake_mps2) * maxf(delta, 0.0)
	current_planar_velocity = current_planar_velocity.move_toward(target_planar_velocity, planar_step)
	drone.velocity.x = current_planar_velocity.x
	drone.velocity.z = current_planar_velocity.z
	var target_vertical_velocity := vertical_input * max_vertical_speed_mps
	var vertical_step := vertical_accel_mps2 * maxf(delta, 0.0)
	if absf(target_vertical_velocity) > 0.01 and absf(drone.velocity.y) > 0.01 and signf(target_vertical_velocity) != signf(drone.velocity.y):
		vertical_step *= 2.2
	drone.velocity.y = move_toward(drone.velocity.y, target_vertical_velocity, vertical_step)
	if current_planar_velocity.length_squared() > 0.05:
		var target_heading := current_planar_velocity.normalized()
		var target_yaw := atan2(-target_heading.x, -target_heading.z)
		drone.rotation.y = rotate_toward(drone.rotation.y, target_yaw, yaw_turn_speed_rad * maxf(delta, 0.0))
	drone.move_and_slide()
	_apply_visual_bank(drone, visual_root, delta)
	return {
		"planar_speed_mps": Vector2(drone.velocity.x, drone.velocity.z).length(),
		"vertical_speed_mps": drone.velocity.y,
	}

func _read_input_state() -> Dictionary:
	var planar_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		planar_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		planar_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		planar_input.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		planar_input.y -= 1.0
	if planar_input.length_squared() > 1.0:
		planar_input = planar_input.normalized()
	var vertical_input := 0.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept"):
		vertical_input += 1.0
	if Input.is_key_pressed(KEY_Q):
		vertical_input -= 1.0
	return {
		"planar_input": planar_input,
		"vertical_input": clampf(vertical_input, -1.0, 1.0),
	}

func _apply_visual_bank(drone: CharacterBody3D, visual_root: Node3D, delta: float) -> void:
	if visual_root == null:
		return
	var right_axis := drone.global_transform.basis.x.normalized()
	var forward_axis := (-drone.global_transform.basis.z).normalized()
	var lateral_speed := right_axis.dot(drone.velocity)
	var forward_speed := forward_axis.dot(drone.velocity)
	var roll_target := deg_to_rad(clampf((-lateral_speed / maxf(max_planar_speed_mps, 0.001)) * max_roll_deg, -max_roll_deg, max_roll_deg))
	var pitch_target := deg_to_rad(clampf((-forward_speed / maxf(max_planar_speed_mps, 0.001)) * max_pitch_deg, -max_pitch_deg, max_pitch_deg))
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, roll_target, clampf(visual_response * maxf(delta, 0.0), 0.0, 1.0))
	visual_root.rotation.x = lerp_angle(visual_root.rotation.x, pitch_target, clampf(visual_response * maxf(delta, 0.0), 0.0, 1.0))
