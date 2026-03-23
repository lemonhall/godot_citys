extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("is_control_enabled"), "Player drone flow requires the mounted PlayerController runtime"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Player drone flow requires PlayerController.request_primary_fire() for restore verification"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone flow requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone flow requires the mounted PlayerDroneRuntime node"):
		return

	var baseline_player_position: Vector3 = player.global_position
	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("camera_owner", "")) == "drone", "End-to-end drone flow must hand camera ownership to the drone after deploy completes"):
		return
	if not T.require_true(self, str(active_state.get("input_owner", "")) == "drone", "End-to-end drone flow must hand input ownership to the drone after deploy completes"):
		return
	if not T.require_true(self, player.global_position.distance_to(baseline_player_position) <= 0.01, "End-to-end drone flow must keep the player body frozen during drone ownership"):
		return

	var baseline_drone_position: Vector3 = runtime.global_position
	_set_key_pressed(KEY_W, true)
	_set_key_pressed(KEY_E, true)
	await _advance_frames(30)
	_set_key_pressed(KEY_W, false)
	_set_key_pressed(KEY_E, false)
	if not T.require_true(self, runtime.global_position.distance_to(baseline_drone_position) >= 2.5, "End-to-end drone flow must let the active drone travel a visible distance under combined forward/up input"):
		return
	if not T.require_true(self, runtime.global_position.y >= baseline_drone_position.y + 0.4, "End-to-end drone flow must let the active drone climb under upward input"):
		return

	_press_world_key(world, KEY_KP_5)
	var stowed_state := await _wait_for_state(world, "stowed", 180)
	if not T.require_true(self, str(stowed_state.get("camera_owner", "")) == "player", "End-to-end drone flow must restore camera ownership to the player after recovery completes"):
		return
	if not T.require_true(self, str(stowed_state.get("input_owner", "")) == "player", "End-to-end drone flow must restore input ownership to the player after recovery completes"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "End-to-end drone flow must restore PlayerController control after recovery completes"):
		return
	if not T.require_true(self, player.request_primary_fire(), "End-to-end drone flow must restore the player weapon chain once the drone has been recovered"):
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
