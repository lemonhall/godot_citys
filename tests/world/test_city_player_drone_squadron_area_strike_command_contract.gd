extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TARGET_MAX_DISTANCE_M := 220.0
const AREA_STRIKE_RADIUS_M := 12.0
const MIN_WAVE_INTERVAL_SEC := 0.55

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone squadron area strike command contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Area strike command contract requires leader debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_squadron_debug_state"), "Area strike command contract requires squadron debug-state introspection"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Area strike command contract requires the mounted PlayerDroneRuntime crosshair API"):
		return

	await _summon_total_drones(world, 7)
	var initial_squadron_state := world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, int(initial_squadron_state.get("active_total_count", -1)) == 7, "Area strike command contract requires one leader plus six wingmen to validate the 1/2/3 wave schedule"):
		return

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var crosshair_state := await _aim_fpv_toward_close_target(runtime, TARGET_MAX_DISTANCE_M)
	var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, runtime.global_position.distance_to(target_world_position) <= TARGET_MAX_DISTANCE_M, "Area strike command contract requires a reachable FPV target point"):
		return

	_set_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_set_mouse_button(MOUSE_BUTTON_MIDDLE, false)

	var dispatch_state := await _wait_for_strike_event_count(world, 6, 360)
	var leader_state := world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, not bool(leader_state.get("strike_committed", false)), "Middle-click area strike must not commit the leader into kamikaze mode"):
		return
	if not T.require_true(self, str(leader_state.get("camera_owner", "")) == "drone" and str(leader_state.get("input_owner", "")) == "drone", "Middle-click area strike must keep camera/input ownership on the leader"):
		return
	if not T.require_true(self, not bool(leader_state.get("signal_loss_active", false)) and not bool(leader_state.get("no_signal_visible", false)), "Middle-click area strike must not trigger NO SIGNAL on the leader"):
		return

	var strike_events := _extract_strike_events(dispatch_state)
	if not T.require_true(self, strike_events.size() >= 6, "Area strike command contract must expose one dispatch event per consumed wingman"):
		return

	var area_events := _extract_area_events(strike_events)
	if not T.require_true(self, area_events.size() == 6, "Area strike command contract must mark all six wingman dispatches as area-order events"):
		return

	var unique_targets := _count_unique_targets(area_events)
	if not T.require_true(self, unique_targets >= 4, "Area strike command contract must spread the six wingmen across multiple impact points instead of collapsing to one target"):
		return
	if not T.require_true(self, _all_targets_within_radius(area_events, target_world_position, AREA_STRIKE_RADIUS_M + 0.25), "Area strike command contract must keep every assigned target inside the frozen area radius %0.2fm" % AREA_STRIKE_RADIUS_M):
		return

	var wave_sizes := _collect_wave_sizes(area_events)
	if not T.require_true(self, wave_sizes.size() >= 3 and wave_sizes[0] == 1 and wave_sizes[1] == 2 and wave_sizes[2] == 3, "Area strike command contract must dispatch the first three waves as 1 then 2 then 3 wingmen"):
		return
	if not T.require_true(self, _wave_intervals_respect_minimum(area_events, MIN_WAVE_INTERVAL_SEC), "Area strike command contract must enforce at least %0.2fs between area-strike waves" % MIN_WAVE_INTERVAL_SEC):
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

func _extract_strike_events(squadron_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var events_variant: Variant = squadron_state.get("recent_strike_events", [])
	if not (events_variant is Array):
		return result
	for event_variant: Variant in events_variant:
		if event_variant is Dictionary:
			result.append((event_variant as Dictionary).duplicate(true))
	return result

func _extract_area_events(strike_events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for strike_event: Dictionary in strike_events:
		if str(strike_event.get("order_kind", "")) == "area":
			result.append(strike_event)
	return result

func _count_unique_targets(strike_events: Array[Dictionary]) -> int:
	var encoded_targets: Dictionary = {}
	for strike_event: Dictionary in strike_events:
		var target_world_position := strike_event.get("target_world_position", Vector3.ZERO) as Vector3
		var key := "%0.2f|%0.2f|%0.2f" % [target_world_position.x, target_world_position.y, target_world_position.z]
		encoded_targets[key] = true
	return encoded_targets.size()

func _all_targets_within_radius(strike_events: Array[Dictionary], center_world_position: Vector3, radius_m: float) -> bool:
	for strike_event: Dictionary in strike_events:
		var target_world_position := strike_event.get("target_world_position", Vector3.ZERO) as Vector3
		if target_world_position.distance_to(center_world_position) > radius_m:
			return false
	return true

func _collect_wave_sizes(strike_events: Array[Dictionary]) -> Array[int]:
	var wave_size_map: Dictionary = {}
	for strike_event: Dictionary in strike_events:
		var wave_index := int(strike_event.get("wave_index", -1))
		if wave_index < 0:
			continue
		wave_size_map[wave_index] = int(wave_size_map.get(wave_index, 0)) + 1
	var keys := wave_size_map.keys()
	keys.sort()
	var result: Array[int] = []
	for wave_key_variant: Variant in keys:
		result.append(int(wave_size_map.get(int(wave_key_variant), 0)))
	return result

func _wave_intervals_respect_minimum(strike_events: Array[Dictionary], minimum_interval_sec: float) -> bool:
	var first_dispatch_per_wave: Dictionary = {}
	for strike_event: Dictionary in strike_events:
		var wave_index := int(strike_event.get("wave_index", -1))
		var dispatch_time_sec := float(strike_event.get("dispatch_time_sec", -1.0))
		if wave_index < 0 or dispatch_time_sec < 0.0:
			return false
		if not first_dispatch_per_wave.has(wave_index):
			first_dispatch_per_wave[wave_index] = dispatch_time_sec
			continue
		first_dispatch_per_wave[wave_index] = minf(float(first_dispatch_per_wave.get(wave_index, dispatch_time_sec)), dispatch_time_sec)
	var keys := first_dispatch_per_wave.keys()
	keys.sort()
	for key_index in range(keys.size() - 1):
		var current_key := int(keys[key_index])
		var next_key := int(keys[key_index + 1])
		var interval_sec := float(first_dispatch_per_wave.get(next_key, 0.0)) - float(first_dispatch_per_wave.get(current_key, 0.0))
		if interval_sec < minimum_interval_sec:
			return false
	return true

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
