extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone speed and attitude contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone speed and attitude contract requires CityPrototype.get_player_drone_debug_state()"):
		return
	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_visual_root"), "Player drone speed and attitude contract requires a mounted PlayerDroneRuntime with get_visual_root()"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone speed and attitude contract requires the drone to reach active flight before validating motion tuning"):
		return
	if not T.require_true(self, active_state.has("body_yaw_deg"), "Player drone speed and attitude contract requires debug state to expose body_yaw_deg so rotorcraft strafe semantics can be regression tested"):
		return
	var baseline_yaw_deg := float(active_state.get("body_yaw_deg", 0.0))

	var initial_position: Vector3 = runtime.global_position
	_set_key_pressed(KEY_W, true)
	await _advance_frames(36)
	var forward_state: Dictionary = world.get_player_drone_debug_state()
	_set_key_pressed(KEY_W, false)

	if not T.require_true(self, runtime.global_position.distance_to(initial_position) >= 10.0, "Forward drone flight must cover a much longer distance than the current sluggish baseline"):
		return
	if not T.require_true(self, float(forward_state.get("planar_velocity_mps", 0.0)) >= 28.0, "Forward drone flight must reach a clearly faster cruise speed so the aircraft no longer feels capped like a slow hover toy"):
		return
	if not T.require_true(self, forward_state.has("visual_pitch_deg"), "Drone debug state must expose visual_pitch_deg so forward-tilt behavior can be regression tested formally"):
		return
	if not T.require_true(self, float(forward_state.get("visual_pitch_deg", 0.0)) <= -12.0, "Forward drone flight must visibly pitch the nose down instead of staying too level while accelerating"):
		return
	if not T.require_true(self, _angle_delta_deg(float(forward_state.get("body_yaw_deg", baseline_yaw_deg)), baseline_yaw_deg) <= 4.0, "Forward drone flight must preserve a stable body heading instead of auto-yawing toward velocity like an arcade missile"):
		return

	await _advance_frames(36)
	var hover_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, absf(float(hover_state.get("visual_pitch_deg", 999.0))) <= 4.0, "Releasing forward input must let the drone visually settle back toward level hover instead of staying locked in a dive posture"):
		return

	_set_key_pressed(KEY_S, true)
	await _advance_frames(24)
	var reverse_state: Dictionary = world.get_player_drone_debug_state()
	_set_key_pressed(KEY_S, false)
	if not T.require_true(self, float(reverse_state.get("visual_pitch_deg", 0.0)) >= 8.0, "Holding S during active flight must visibly pitch the nose up instead of reusing the same forward-dive attitude"):
		return
	if not T.require_true(self, _angle_delta_deg(float(reverse_state.get("body_yaw_deg", baseline_yaw_deg)), baseline_yaw_deg) <= 4.0, "Holding S during active flight must not auto-rotate the body toward the travel direction"):
		return

	await _advance_frames(24)

	_set_key_pressed(KEY_A, true)
	await _advance_frames(24)
	var left_state: Dictionary = world.get_player_drone_debug_state()
	_set_key_pressed(KEY_A, false)
	if not T.require_true(self, float(left_state.get("visual_roll_deg", 0.0)) >= 6.0, "Holding A during active flight must visibly bank left instead of flattening or rotating the whole craft sideways"):
		return
	if not T.require_true(self, _angle_delta_deg(float(left_state.get("body_yaw_deg", baseline_yaw_deg)), baseline_yaw_deg) <= 4.0, "Holding A during active flight must strafe left under a stable heading instead of slewing the body toward velocity"):
		return

	await _advance_frames(24)

	_set_key_pressed(KEY_D, true)
	await _advance_frames(24)
	var right_state: Dictionary = world.get_player_drone_debug_state()
	_set_key_pressed(KEY_D, false)
	if not T.require_true(self, float(right_state.get("visual_roll_deg", 0.0)) <= -6.0, "Holding D during active flight must visibly bank right instead of flattening or rotating the whole craft sideways"):
		return
	if not T.require_true(self, _angle_delta_deg(float(right_state.get("body_yaw_deg", baseline_yaw_deg)), baseline_yaw_deg) <= 4.0, "Holding D during active flight must strafe right under a stable heading instead of slewing the body toward velocity"):
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

func _angle_delta_deg(a_deg: float, b_deg: float) -> float:
	return absf(rad_to_deg(wrapf(deg_to_rad(a_deg - b_deg), -PI, PI)))
