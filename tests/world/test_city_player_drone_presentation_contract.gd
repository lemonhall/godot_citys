extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone presentation contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone presentation contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone presentation contract requires a mounted PlayerDroneRuntime CharacterBody3D"):
		return

	var model_root := runtime.get_node_or_null("ModelRoot") as Node3D
	var rotor_blur_root := runtime.get_node_or_null("RotorBlurRoot") as Node3D
	if not T.require_true(self, model_root != null and rotor_blur_root != null, "Player drone presentation contract requires authored ModelRoot and RotorBlurRoot nodes"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone presentation contract requires the drone to reach active flight before validating presentation wiring"):
		return
	if not T.require_true(self, active_state.has("presentation_scale"), "Player drone presentation contract requires debug state to expose presentation_scale for visual size regression coverage"):
		return
	if not T.require_true(self, float(active_state.get("presentation_scale", 0.0)) >= 2.8, "Drone third-person presentation must be scaled up to roughly 3x so the aircraft no longer reads as a toy-sized speck"):
		return
	if not T.require_true(self, model_root.scale.x >= 2.8 and model_root.scale.y >= 2.8 and model_root.scale.z >= 2.8, "Drone ModelRoot must carry the enlarged third-person presentation scale"):
		return
	if not T.require_true(self, rotor_blur_root.scale.distance_to(model_root.scale) <= 0.05, "Rotor blur presentation must share the same enlarged scale as the visible drone body"):
		return

	_set_key_pressed(KEY_W, true)
	await _advance_frames(24)
	_set_key_pressed(KEY_W, false)

	var pitch_delta_deg := absf(rad_to_deg(rotor_blur_root.rotation.x - model_root.rotation.x))
	var roll_delta_deg := absf(rad_to_deg(rotor_blur_root.rotation.z - model_root.rotation.z))
	if not T.require_true(self, absf(rad_to_deg(model_root.rotation.x)) >= 8.0, "Drone presentation contract requires enough visible forward pitch to make the rotor sync assertion meaningful"):
		return
	if not T.require_true(self, pitch_delta_deg <= 1.0 and roll_delta_deg <= 1.0, "Rotor blur presentation must inherit the same bank/pitch posture as the drone body instead of staying upright while the fuselage tilts"):
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
