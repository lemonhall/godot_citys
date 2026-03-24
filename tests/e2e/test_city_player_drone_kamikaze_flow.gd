extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone kamikaze flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone kamikaze flow requires CityPrototype.get_player_drone_debug_state()"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "Player drone kamikaze flow requires CityPrototype.spawn_trauma_enemy_at_world_position() for strike target setup"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("is_control_enabled"), "Player drone kamikaze flow requires the mounted PlayerController runtime"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Player drone kamikaze flow requires PlayerController.request_primary_fire() for post-strike restore verification"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Player drone kamikaze flow requires the mounted PlayerDroneRuntime crosshair API"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone kamikaze flow requires the drone to reach active flight before strike setup"):
		return

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var crosshair_state := await _aim_fpv_toward_close_target(runtime, 180.0)
	var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, runtime.global_position.distance_to(target_world_position) <= 180.0, "Player drone kamikaze flow requires a reachable FPV target setup instead of an unreachable skyline aim point"):
		return

	var enemy: CharacterBody3D = world.spawn_trauma_enemy_at_world_position(target_world_position)
	if not T.require_true(self, enemy != null and enemy.has_method("get_health_state"), "Player drone kamikaze flow must spawn a trauma enemy on the FPV target line"):
		return
	await _advance_frames(6)

	var initial_enemy_health := enemy.get_health_state() as Dictionary
	if not T.require_true(self, bool(initial_enemy_health.get("alive", false)), "Kamikaze flow target enemy must begin alive before the suicide strike commits"):
		return

	_set_mouse_button(MOUSE_BUTTON_LEFT, true)
	_set_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _advance_frames(10)

	var strike_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, bool(strike_state.get("strike_committed", false)), "Kamikaze flow must commit the suicide strike after left click in FPV ADS mode"):
		return
	if not T.require_true(self, not bool(strike_state.get("manual_flight_input_enabled", true)), "Kamikaze flow must hand flight motion to autopilot after target lock-on"):
		return

	var signal_loss_state := await _wait_for_strike_state(world, "signal_loss", 240)
	if not T.require_true(self, str(signal_loss_state.get("strike_state", "")) == "signal_loss", "Kamikaze flow must pass through a signal_loss FPV closeout window after the blast instead of hard-cutting back to the player"):
		return
	if not T.require_true(self, bool(signal_loss_state.get("signal_loss_active", false)), "Kamikaze flow must hold a visible signal_loss overlay after the blast"):
		return
	if not T.require_true(self, bool(signal_loss_state.get("no_signal_visible", false)), "Kamikaze flow must visibly flash NO SIGNAL during the post-blast feed loss window"):
		return
	if not T.require_true(self, str(signal_loss_state.get("camera_owner", "")) == "drone", "Kamikaze flow must keep the drone camera until the signal loss closeout finishes"):
		return

	var stowed_state := await _wait_for_state(world, "stowed", 360)
	if not T.require_true(self, str(stowed_state.get("camera_owner", "")) == "player", "Kamikaze flow must restore player camera ownership after drone detonation closeout"):
		return
	if not T.require_true(self, str(stowed_state.get("input_owner", "")) == "player", "Kamikaze flow must restore player input ownership after drone detonation closeout"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "Kamikaze flow must return live control to the player after the suicide strike finishes"):
		return
	if not T.require_true(self, player.request_primary_fire(), "Kamikaze flow must restore the player weapon chain after the suicide strike finishes"):
		return

	if not T.require_true(self, is_instance_valid(enemy), "Kamikaze flow target enemy must still expose a post-strike health state for verification"):
		return
	var final_enemy_health := enemy.get_health_state() as Dictionary
	if not T.require_true(self, not bool(final_enemy_health.get("alive", true)), "Kamikaze flow strike must lethally resolve a trauma enemy caught on the locked FPV impact point"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 0, "Kamikaze flow must remove the target trauma enemy from the active combat roster after the suicide strike kill"):
		return

	var last_strike_result := stowed_state.get("last_strike_result", {}) as Dictionary
	if not T.require_true(self, int(last_strike_result.get("enemy_hit_count", 0)) >= 1, "Kamikaze flow strike summary must report at least one city_enemy hit when the target enemy is on the locked impact point"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _aim_fpv_toward_close_target(runtime: CharacterBody3D, max_distance_m: float) -> Dictionary:
	var crosshair_state := runtime.get_crosshair_state() as Dictionary
	for _attempt in range(10):
		var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
		if target_world_position != Vector3.ZERO and runtime.global_position.distance_to(target_world_position) <= max_distance_m:
			return crosshair_state
		_set_mouse_motion(0.0, 28.0)
		await _advance_frames(4)
		crosshair_state = runtime.get_crosshair_state() as Dictionary
	return crosshair_state

func _wait_for_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = world.get_player_drone_debug_state()
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state()

func _wait_for_strike_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = world.get_player_drone_debug_state()
		if str(debug_state.get("strike_state", "")) == expected_state:
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

func _set_mouse_button(button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)

func _set_mouse_motion(relative_x: float, relative_y: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(relative_x, relative_y)
	event.velocity = Vector2(relative_x * 60.0, relative_y * 60.0)
	Input.parse_input_event(event)
