extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for drone artillery target-marking contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Drone artillery target-marking contract requires drone debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Drone artillery target-marking contract requires artillery fire-mission introspection"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Drone artillery target-marking contract requires map render-state introspection"):
		return
	if not T.require_true(self, world.has_method("set_full_map_open"), "Drone artillery target-marking contract requires full-map visibility control"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Drone artillery target-marking contract requires the mounted PlayerDroneRuntime crosshair API"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_drone_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Drone artillery target-marking contract requires the drone to reach active flight before T can calibrate artillery"):
		return

	_toggle_fpv_ads()
	await _advance_frames(12)

	var first_crosshair_state := await _aim_fpv_toward_close_target(runtime, 220.0)
	var first_target_world_position := first_crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, first_target_world_position != Vector3.ZERO, "Drone artillery target-marking contract requires a formal FPV crosshair world target before T is pressed"):
		return
	if not T.require_true(self, runtime.global_position.distance_to(first_target_world_position) <= 220.0, "Drone artillery target-marking contract requires a reachable FPV ground target instead of a far-horizon dummy point"):
		return

	_press_world_key(world, KEY_T)
	await _advance_frames(6)

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	if not T.require_true(self, bool(mission_state.get("active", false)), "Pressing T in drone FPV mode must create a formal artillery fire mission instead of doing nothing"):
		return
	var planned_target_world_position := mission_state.get("target_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, planned_target_world_position.distance_to(first_target_world_position) <= 1.5, "Drone T calibration must forward the FPV crosshair world target into the formal artillery mission state"):
		return
	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, not bool(solution_state.get("solved", false)), "Without live howitzer operation, drone T calibration must still leave the mission pending instead of pretending a solved solution already exists"):
		return
	if not T.require_true(self, str(solution_state.get("reason", "")) == "requires_live_howitzer_operation", "Pending drone T calibration must preserve the same requires_live_howitzer_operation reason as map-side planning"):
		return

	world.set_full_map_open(true)
	await process_frame
	var map_state := world.get_map_screen_state() as Dictionary
	if not T.require_true(self, _count_artillery_fire_mission_pins(map_state.get("pin_markers", [])) == 1, "Drone T calibration must surface exactly one formal artillery fire-mission pin on the full map"):
		return
	world.set_full_map_open(false)
	await process_frame

	var second_crosshair_state := await _retarget_fpv_crosshair(runtime, first_target_world_position, 40.0, 220.0)
	var second_target_world_position := second_crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, second_target_world_position.distance_to(first_target_world_position) >= 40.0, "Drone artillery recalibration contract requires a materially different second FPV target before T is pressed again"):
		return

	_press_world_key(world, KEY_T)
	await _advance_frames(6)

	mission_state = world.get_artillery_fire_mission_state() as Dictionary
	planned_target_world_position = mission_state.get("target_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, planned_target_world_position.distance_to(second_target_world_position) <= 1.5, "Pressing T again in drone FPV mode must update the formal artillery mission target instead of leaving the old point in place"):
		return
	if not T.require_true(self, planned_target_world_position.distance_to(first_target_world_position) >= 30.0, "Drone artillery recalibration must replace the previous target instead of silently preserving the original fire-mission point"):
		return

	world.set_full_map_open(true)
	await process_frame
	map_state = world.get_map_screen_state() as Dictionary
	if not T.require_true(self, _count_artillery_fire_mission_pins(map_state.get("pin_markers", [])) == 1, "Repeated drone T calibration must still keep a single artillery fire-mission pin instead of accumulating duplicates"):
		return
	var map_fire_mission_state := map_state.get("artillery_fire_mission", {}) as Dictionary
	if not T.require_true(self, bool(map_fire_mission_state.get("active", false)), "Full map artillery summary must keep reading the shared active fire-mission state after drone-side recalibration"):
		return
	world.set_full_map_open(false)
	await process_frame

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

func _aim_fpv_toward_close_target(runtime: CharacterBody3D, max_distance_m: float) -> Dictionary:
	var crosshair_state := runtime.get_crosshair_state() as Dictionary
	for _attempt in range(12):
		var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
		if target_world_position != Vector3.ZERO and runtime.global_position.distance_to(target_world_position) <= max_distance_m:
			return crosshair_state
		_set_mouse_motion(0.0, 28.0)
		await _advance_frames(4)
		crosshair_state = runtime.get_crosshair_state() as Dictionary
	return crosshair_state

func _retarget_fpv_crosshair(runtime: CharacterBody3D, baseline_target_world_position: Vector3, min_target_delta_m: float, max_distance_m: float) -> Dictionary:
	var crosshair_state := runtime.get_crosshair_state() as Dictionary
	var lateral_step := runtime.global_transform.basis.x
	lateral_step.y = 0.0
	if lateral_step.length_squared() <= 0.0001:
		lateral_step = Vector3.RIGHT
	lateral_step = lateral_step.normalized() * 18.0
	for _attempt in range(12):
		var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
		if target_world_position != Vector3.ZERO and runtime.global_position.distance_to(target_world_position) <= max_distance_m and target_world_position.distance_to(baseline_target_world_position) >= min_target_delta_m:
			return crosshair_state
		_set_mouse_motion(28.0, 0.0)
		if ((_attempt + 1) % 4) == 0:
			runtime.global_position += lateral_step
		await _advance_frames(4)
		crosshair_state = runtime.get_crosshair_state() as Dictionary
	return crosshair_state

func _count_artillery_fire_mission_pins(pin_markers: Array) -> int:
	var count := 0
	for pin_variant in pin_markers:
		var pin: Dictionary = pin_variant
		if str(pin.get("pin_type", "")) == "artillery_fire_mission":
			count += 1
	return count

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

func _toggle_fpv_ads() -> void:
	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)

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
