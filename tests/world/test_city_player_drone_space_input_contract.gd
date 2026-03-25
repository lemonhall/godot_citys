extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone Space input contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone Space input contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone Space input contract requires the mounted PlayerDroneRuntime node"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_drone_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone Space input contract requires the drone to reach active flight state after numpad 5 deploy"):
		return

	await _advance_frames(12)
	var baseline_position := runtime.global_position

	_set_key_pressed(KEY_SPACE, true)
	await _advance_frames(24)
	_set_key_pressed(KEY_SPACE, false)
	await _advance_frames(6)
	var space_height_delta_m := runtime.global_position.y - baseline_position.y
	if not T.require_true(self, absf(space_height_delta_m) <= 0.12, "Active drone must no longer climb on Space input; Space height delta should stay near zero (delta=%0.3fm)" % space_height_delta_m):
		return

	var e_baseline_position := runtime.global_position
	_set_key_pressed(KEY_E, true)
	await _advance_frames(24)
	_set_key_pressed(KEY_E, false)
	await _advance_frames(6)
	var e_height_delta_m := runtime.global_position.y - e_baseline_position.y
	if not T.require_true(self, e_height_delta_m >= 0.45, "Active drone must still climb on E input after Space ownership is removed (delta=%0.3fm)" % e_height_delta_m):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_drone_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
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
