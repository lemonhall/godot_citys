extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TARGET_MAX_DISTANCE_M := 220.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone squadron single strike dispatch contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Single strike dispatch contract requires leader debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_squadron_debug_state"), "Single strike dispatch contract requires squadron debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "Single strike dispatch contract requires enemy spawn support for impact verification"):
		return
	if not T.require_true(self, world.has_method("get_active_enemy_count"), "Single strike dispatch contract requires active enemy roster introspection"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Single strike dispatch contract requires the mounted PlayerDroneRuntime crosshair API"):
		return

	await _summon_total_drones(world, 3)
	var initial_squadron_state := world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, int(initial_squadron_state.get("active_total_count", -1)) == 3, "Single strike dispatch contract requires one leader plus two wingmen before the left-click redirect can be validated"):
		return

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var crosshair_state := await _aim_fpv_toward_close_target(runtime, TARGET_MAX_DISTANCE_M)
	var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, runtime.global_position.distance_to(target_world_position) <= TARGET_MAX_DISTANCE_M, "Single strike dispatch contract requires a reachable FPV target point"):
		return

	var enemy := world.spawn_trauma_enemy_at_world_position(target_world_position) as CharacterBody3D
	if not T.require_true(self, enemy != null and enemy.has_method("get_health_state"), "Single strike dispatch contract requires a spawned trauma enemy on the selected impact point"):
		return
	await _advance_frames(6)

	_set_mouse_button(MOUSE_BUTTON_LEFT, true)
	_set_mouse_button(MOUSE_BUTTON_LEFT, false)

	var dispatch_state := await _wait_for_strike_event_count(world, 1, 240)
	var leader_state := world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, not bool(leader_state.get("strike_committed", false)), "When wingmen are available, left click must not commit the leader into suicide strike"):
		return
	if not T.require_true(self, str(leader_state.get("camera_owner", "")) == "drone" and str(leader_state.get("input_owner", "")) == "drone", "Single wingman strike dispatch must keep camera/input ownership on the leader"):
		return
	if not T.require_true(self, bool(leader_state.get("manual_flight_input_enabled", false)), "Single wingman strike dispatch must keep manual flight input enabled on the leader"):
		return
	if not T.require_true(self, not bool(leader_state.get("signal_loss_active", false)) and not bool(leader_state.get("no_signal_visible", false)), "Single wingman strike dispatch must not trigger the leader NO SIGNAL closeout"):
		return

	var strike_events := _extract_strike_events(dispatch_state)
	if not T.require_true(self, strike_events.size() >= 1, "Single wingman strike dispatch must expose at least one dispatch event in squadron debug state"):
		return
	var first_event: Dictionary = strike_events[0]
	if not T.require_true(self, str(first_event.get("order_kind", "")) == "single", "Single left-click redirect must tag the first dispatch event as order_kind=single"):
		return
	if not T.require_true(self, int(dispatch_state.get("striking_wingman_count", 0)) >= 1, "Single wingman strike dispatch must place one wingman into a striking state"):
		return

	var resolved_state := await _wait_for_active_total_count(world, 2, 360)
	leader_state = world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, int(resolved_state.get("active_total_count", -1)) == 2 and int(resolved_state.get("desired_total_count", -1)) == 2, "After one wingman strike resolves, the squadron must formally lose exactly one drone"):
		return
	if not T.require_true(self, str(leader_state.get("system_state", "")) == "active", "After one wingman strike resolves, the leader must remain in active flight instead of stowing itself"):
		return
	if not T.require_true(self, str(leader_state.get("camera_owner", "")) == "drone" and not bool(leader_state.get("signal_loss_active", false)), "Leader observation state must survive the wingman strike resolution without signal loss"):
		return

	if not T.require_true(self, is_instance_valid(enemy), "Single wingman strike contract requires the target enemy to expose a post-strike health state"):
		return
	var final_enemy_health := enemy.get_health_state() as Dictionary
	if not T.require_true(self, not bool(final_enemy_health.get("alive", true)), "Single wingman strike must lethally resolve the enemy sitting on the locked target point"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 0, "Single wingman strike must clear the struck enemy from the active combat roster"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _summon_total_drones(world: Node, total_count: int) -> void:
	if total_count <= 0:
		return
	_press_world_key(world, KEY_KP_5)
	await _wait_for_leader_state(world, "active", 180)
	for spawn_index in range(2, total_count + 1):
		_tap_world_key(world, KEY_KP_5)
		await _advance_frames(18)

func _wait_for_leader_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state := world.get_player_drone_debug_state() as Dictionary
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state() as Dictionary

func _wait_for_strike_event_count(world: Node, minimum_count: int, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var squadron_state := world.get_player_drone_squadron_debug_state() as Dictionary
		if _extract_strike_events(squadron_state).size() >= minimum_count:
			return squadron_state
	return world.get_player_drone_squadron_debug_state() as Dictionary

func _wait_for_active_total_count(world: Node, expected_total_count: int, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var squadron_state := world.get_player_drone_squadron_debug_state() as Dictionary
		if int(squadron_state.get("active_total_count", -1)) == expected_total_count:
			return squadron_state
	return world.get_player_drone_squadron_debug_state() as Dictionary

func _extract_strike_events(squadron_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var events_variant: Variant = squadron_state.get("recent_strike_events", [])
	if not (events_variant is Array):
		return result
	for event_variant: Variant in events_variant:
		if event_variant is Dictionary:
			result.append((event_variant as Dictionary).duplicate(true))
	return result

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

func _release_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _tap_world_key(world: Node, keycode: Key) -> void:
	_press_world_key(world, keycode)
	_release_world_key(world, keycode)

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
