extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TARGET_MAX_DISTANCE_M := 220.0
const EXPECTED_EXPLOSION_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for wingman impact presentation contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Wingman impact presentation contract requires leader debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_squadron_debug_state"), "Wingman impact presentation contract requires squadron debug-state introspection"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Wingman impact presentation contract requires the mounted PlayerDroneRuntime crosshair API"):
		return

	await _summon_total_drones(world, 3)

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var crosshair_state := await _aim_fpv_toward_close_target(runtime, TARGET_MAX_DISTANCE_M)
	var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, runtime.global_position.distance_to(target_world_position) <= TARGET_MAX_DISTANCE_M, "Wingman impact presentation contract requires a reachable FPV target point"):
		return

	_set_mouse_button(MOUSE_BUTTON_LEFT, true)
	_set_mouse_button(MOUSE_BUTTON_LEFT, false)

	var resolved_events := await _wait_for_resolved_strike_events(world, 1, 360)
	if not T.require_true(self, resolved_events.size() >= 1, "Wingman impact presentation contract requires at least one resolved strike event"):
		return
	var first_event: Dictionary = resolved_events[0]
	if not T.require_true(self, bool(first_event.get("impact_fx_played", false)), "Wingman impact presentation contract must record impact_fx_played=true once the wingman hits the ground"):
		return
	if not T.require_true(self, bool(first_event.get("impact_fx_ring_enabled", false)), "Wingman impact presentation contract must record that the formal explosion ring participated in the impact FX"):
		return
	if not T.require_true(self, bool(first_event.get("impact_fx_sphere_enabled", false)), "Wingman impact presentation contract must record that the formal explosion sphere participated in the impact FX"):
		return
	if not T.require_true(self, int(first_event.get("impact_audio_trigger_count", 0)) >= 1, "Wingman impact presentation contract must trigger at least one explosion audio play at impact time"):
		return
	if not T.require_true(self, str(first_event.get("impact_audio_stream_path", "")) == EXPECTED_EXPLOSION_AUDIO_PATH, "Wingman impact presentation contract must reuse the formal weapon-8 explosion audio asset"):
		return
	if not T.require_true(self, first_event.get("impact_world_position", null) is Vector3, "Wingman impact presentation contract must expose the resolved impact_world_position for verification"):
		return

	var leader_state := world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, str(leader_state.get("camera_owner", "")) == "drone" and str(leader_state.get("input_owner", "")) == "drone", "Wingman impact presentation must not steal camera/input ownership away from the leader"):
		return
	if not T.require_true(self, not bool(leader_state.get("signal_loss_active", false)) and not bool(leader_state.get("no_signal_visible", false)), "Wingman impact presentation must not trigger NO SIGNAL on the leader"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _summon_total_drones(world: Node, total_count: int) -> void:
	if total_count <= 0:
		return
	_press_world_key(world, KEY_KP_5)
	await _wait_for_leader_state(world, "active", 180)
	for _spawn_index in range(2, total_count + 1):
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

func _wait_for_resolved_strike_events(world: Node, minimum_count: int, max_frames: int) -> Array[Dictionary]:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var resolved_events := _extract_resolved_strike_events(world.get_player_drone_squadron_debug_state() as Dictionary)
		if resolved_events.size() >= minimum_count:
			return resolved_events
	return _extract_resolved_strike_events(world.get_player_drone_squadron_debug_state() as Dictionary)

func _extract_resolved_strike_events(squadron_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var events_variant: Variant = squadron_state.get("recent_strike_events", [])
	if not (events_variant is Array):
		return result
	for event_variant: Variant in events_variant:
		if not (event_variant is Dictionary):
			continue
		var strike_event := (event_variant as Dictionary).duplicate(true)
		if bool(strike_event.get("resolved", false)):
			result.append(strike_event)
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
