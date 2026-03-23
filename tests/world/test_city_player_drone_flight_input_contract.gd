extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone flight input contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone flight input contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone flight input contract requires a mounted PlayerDroneRuntime CharacterBody3D"):
		return
	var drone_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, drone_camera != null, "Player drone flight input contract requires the dedicated drone chase camera"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone flight input contract requires the drone to reach active flight before input mapping can be validated"):
		return
	if not T.require_true(self, active_state.has("body_yaw_deg"), "Player drone flight input contract requires debug state to expose body_yaw_deg so mouse yaw steering can be regression tested"):
		return

	var initial_position: Vector3 = runtime.global_position
	var camera_forward := -drone_camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := drone_camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var baseline_yaw_deg := float(active_state.get("body_yaw_deg", 0.0))

	_set_key_pressed(KEY_W, true)
	await _advance_frames(24)
	_set_key_pressed(KEY_W, false)
	var forward_position: Vector3 = runtime.global_position
	var forward_delta := forward_position - initial_position
	if not T.require_true(self, forward_delta.dot(camera_forward) >= 1.2, "Holding W during active flight must move the drone forward in camera-relative space"):
		return
	if not T.require_true(self, float(world.get_player_drone_debug_state().get("planar_velocity_mps", 0.0)) > 0.5, "Holding W during active flight must produce non-trivial planar drone speed"):
		return

	_set_key_pressed(KEY_D, true)
	await _advance_frames(24)
	_set_key_pressed(KEY_D, false)
	var right_position: Vector3 = runtime.global_position
	var right_delta := right_position - forward_position
	if not T.require_true(self, right_delta.dot(camera_right) >= 0.9, "Holding D during active flight must move the drone right in camera-relative space"):
		return

	_set_key_pressed(KEY_E, true)
	await _advance_frames(18)
	_set_key_pressed(KEY_E, false)
	var ascend_from_e_y := runtime.global_position.y
	if not T.require_true(self, ascend_from_e_y >= right_position.y + 1.2, "Holding E during active flight must raise the drone altitude much faster so vertical repositioning no longer feels lethargic"):
		return
	if not T.require_true(self, float(world.get_player_drone_debug_state().get("vertical_velocity_mps", 0.0)) >= 12.0, "Holding E during active flight must reach a clearly higher climb speed than the previous slow hover lift"):
		return

	_set_key_pressed(KEY_Q, true)
	await _advance_frames(18)
	_set_key_pressed(KEY_Q, false)
	var descend_y := runtime.global_position.y
	if not T.require_true(self, descend_y <= ascend_from_e_y - 1.0, "Holding Q during active flight must lower the drone altitude much faster so vertical descent does not feel artificially capped"):
		return
	if not T.require_true(self, float(world.get_player_drone_debug_state().get("vertical_velocity_mps", 0.0)) <= -12.0, "Holding Q during active flight must reach a clearly higher descent speed than the previous slow hover sink"):
		return

	_set_key_pressed(KEY_SPACE, true)
	await _advance_frames(18)
	_set_key_pressed(KEY_SPACE, false)
	var ascend_from_space_y := runtime.global_position.y
	if not T.require_true(self, ascend_from_space_y >= descend_y + 1.0, "Holding Space during active flight must share the formal high-speed ascent mapping with E"):
		return

	_set_mouse_motion(-32.0)
	await _advance_frames(2)
	var yaw_left_state: Dictionary = world.get_player_drone_debug_state()
	var yaw_left_delta_deg := _signed_angle_delta_deg(float(yaw_left_state.get("body_yaw_deg", baseline_yaw_deg)), baseline_yaw_deg)
	if not T.require_true(self, yaw_left_delta_deg >= 2.0, "Dragging the mouse left during active flight must yaw the drone left instead of leaving heading locked forever"):
		return
	if not T.require_true(self, yaw_left_delta_deg <= 15.0, "Dragging the mouse left during active flight must stay reasonably damped instead of spinning the drone too aggressively"):
		return

	_set_mouse_motion(32.0)
	await _advance_frames(2)
	var yaw_right_state: Dictionary = world.get_player_drone_debug_state()
	var yaw_right_delta_deg := _signed_angle_delta_deg(float(yaw_right_state.get("body_yaw_deg", baseline_yaw_deg)), float(yaw_left_state.get("body_yaw_deg", baseline_yaw_deg)))
	if not T.require_true(self, yaw_right_delta_deg <= -2.0, "Dragging the mouse right during active flight must yaw the drone back to the right instead of keeping the left-turn heading"):
		return
	if not T.require_true(self, absf(yaw_right_delta_deg) <= 15.0, "Dragging the mouse right during active flight must stay reasonably damped instead of over-rotating the drone body"):
		return

	await _advance_frames(48)
	var hover_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, absf(float(hover_state.get("vertical_velocity_mps", 999.0))) <= 0.35, "Releasing vertical input must let the drone settle back toward hover instead of continuing to climb or dive"):
		return
	if not T.require_true(self, float(hover_state.get("planar_velocity_mps", 999.0)) <= 0.45, "Releasing planar input must let the drone bleed back toward a near-zero hover instead of drifting indefinitely"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = world.get_player_drone_debug_state()
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state()

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _press_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _set_key_pressed(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	Input.parse_input_event(event)

func _set_mouse_motion(relative_x: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(relative_x, 0.0)
	event.velocity = Vector2(relative_x * 60.0, 0.0)
	Input.parse_input_event(event)

func _signed_angle_delta_deg(a_deg: float, b_deg: float) -> float:
	return rad_to_deg(wrapf(deg_to_rad(a_deg - b_deg), -PI, PI))
