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

	var initial_position: Vector3 = runtime.global_position
	_set_key_pressed(KEY_W, true)
	await _advance_frames(36)
	var forward_state: Dictionary = world.get_player_drone_debug_state()
	_set_key_pressed(KEY_W, false)

	if not T.require_true(self, runtime.global_position.distance_to(initial_position) >= 7.0, "Forward drone flight must cover a much longer distance than the current sluggish baseline"):
		return
	if not T.require_true(self, float(forward_state.get("planar_velocity_mps", 0.0)) >= 18.0, "Forward drone flight must reach a clearly faster cruise speed so the aircraft no longer feels capped like a slow hover toy"):
		return
	if not T.require_true(self, forward_state.has("visual_pitch_deg"), "Drone debug state must expose visual_pitch_deg so forward-tilt behavior can be regression tested formally"):
		return
	if not T.require_true(self, float(forward_state.get("visual_pitch_deg", 0.0)) <= -12.0, "Forward drone flight must visibly pitch the nose down instead of staying too level while accelerating"):
		return

	await _advance_frames(36)
	var hover_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, absf(float(hover_state.get("visual_pitch_deg", 999.0))) <= 4.0, "Releasing forward input must let the drone visually settle back toward level hover instead of staying locked in a dive posture"):
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
