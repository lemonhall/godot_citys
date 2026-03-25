extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const DRONE_FORWARD_OFFSET_M := 1850.0
const DRONE_ALTITUDE_M := 220.0
const MIN_SOLVABLE_DISTANCE_M := 1500.0
const MAX_SOLVABLE_DISTANCE_M := 2400.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for drone artillery recalibration flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "Drone artillery recalibration flow requires get_active_world_howitzer()"):
		return
	if not T.require_true(self, world.has_method("get_world_howitzer_operation_state"), "Drone artillery recalibration flow requires howitzer operation introspection"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Drone artillery recalibration flow requires drone debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Drone artillery recalibration flow requires artillery fire-mission introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Drone artillery recalibration flow requires the teleportable PlayerController runtime"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "Drone artillery recalibration flow requires the shared artillery solution HUD consumer"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null, "Drone artillery recalibration flow requires the summoned formal howitzer runtime"):
		return
	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_world_key(world, KEY_E)
	await _settle_frames()
	var operation_state := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Drone artillery recalibration flow requires live howitzer operation before the drone recalibration can refresh solved data"):
		return

	_press_world_key(world, KEY_KP_5)
	var drone_state := await _wait_for_drone_state(world, "active", 180)
	if not T.require_true(self, str(drone_state.get("camera_owner", "")) == "drone", "Drone artillery recalibration flow requires the drone to own the camera after deploy completes"):
		return

	var drone_runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, drone_runtime != null and drone_runtime.has_method("get_crosshair_state"), "Drone artillery recalibration flow requires the mounted PlayerDroneRuntime crosshair API"):
		return

	drone_runtime.global_position = howitzer.global_position + Vector3(0.0, DRONE_ALTITUDE_M, -DRONE_FORWARD_OFFSET_M)
	await _settle_frames(45)

	_toggle_fpv_ads()
	await _settle_frames(12)

	var first_crosshair_state := await _aim_fpv_toward_solved_target(drone_runtime, howitzer.global_position, MIN_SOLVABLE_DISTANCE_M, MAX_SOLVABLE_DISTANCE_M)
	var first_target_world_position := first_crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, first_target_world_position != Vector3.ZERO, "Drone artillery recalibration flow requires a formal FPV target before T is pressed"):
		return
	var first_target_distance_m := howitzer.global_position.distance_to(first_target_world_position)
	if not T.require_true(self, first_target_distance_m >= MIN_SOLVABLE_DISTANCE_M and first_target_distance_m <= MAX_SOLVABLE_DISTANCE_M, "Drone artillery recalibration flow requires the first drone target to land inside the howitzer solvable distance envelope (distance=%0.2fm)" % first_target_distance_m):
		return

	_press_world_key(world, KEY_T)
	await _settle_frames(8)

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(mission_state.get("active", false)), "Pressing T in drone-assisted howitzer mode must create an active artillery fire mission"):
		return
	if not T.require_true(self, bool(solution_state.get("solved", false)), "Live howitzer operation plus drone T calibration must immediately produce solved firing data"):
		return
	if not T.require_true(self, (mission_state.get("target_world_position", Vector3.ZERO) as Vector3).distance_to(first_target_world_position) <= 1.5, "Solved drone T calibration must preserve the first FPV target as the fire-mission point"):
		return
	var first_bearing_deg := float(solution_state.get("world_bearing_deg", 0.0))
	var first_pitch_deg := float(solution_state.get("pitch_deg", 0.0))

	var artillery_solution_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Drone artillery recalibration flow must keep the artillery solution HUD visible after the first T calibration"):
		return

	var second_crosshair_state := await _retarget_fpv_toward_solved_target(drone_runtime, howitzer.global_position, first_target_world_position, 45.0, MIN_SOLVABLE_DISTANCE_M, MAX_SOLVABLE_DISTANCE_M)
	var second_target_world_position := second_crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, second_target_world_position.distance_to(first_target_world_position) >= 45.0, "Drone artillery recalibration flow requires a materially different second FPV target before T is pressed again"):
		return

	_press_world_key(world, KEY_T)
	await _settle_frames(8)

	mission_state = world.get_artillery_fire_mission_state() as Dictionary
	solution_state = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(solution_state.get("solved", false)), "Re-pressing T in drone-assisted howitzer mode must keep the mission solved instead of regressing to pending state"):
		return
	var recalibrated_target_world_position := mission_state.get("target_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, recalibrated_target_world_position.distance_to(second_target_world_position) <= 1.5, "The second drone T press must update the shared fire-mission target to the new FPV point"):
		return
	if not T.require_true(self, recalibrated_target_world_position.distance_to(first_target_world_position) >= 35.0, "Drone artillery recalibration must replace the earlier solved target instead of silently keeping it"):
		return
	var second_bearing_deg := float(solution_state.get("world_bearing_deg", first_bearing_deg))
	var second_pitch_deg := float(solution_state.get("pitch_deg", first_pitch_deg))
	if not T.require_true(self, absf(second_bearing_deg - first_bearing_deg) >= 0.1 or absf(second_pitch_deg - first_pitch_deg) >= 0.1, "Drone artillery recalibration must refresh the solved bearing or pitch after the target changes"):
		return

	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Drone artillery recalibration must not drop live howitzer operation ownership while updating the target"):
		return
	artillery_solution_state = hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Drone artillery recalibration must keep the artillery solution HUD visible after the second T calibration"):
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

func _aim_fpv_toward_solved_target(runtime: CharacterBody3D, artillery_origin_world_position: Vector3, min_distance_m: float, max_distance_m: float) -> Dictionary:
	var crosshair_state := runtime.get_crosshair_state() as Dictionary
	for _attempt in range(16):
		var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
		var target_distance_m := artillery_origin_world_position.distance_to(target_world_position)
		if target_world_position != Vector3.ZERO and target_distance_m >= min_distance_m and target_distance_m <= max_distance_m:
			return crosshair_state
		_set_mouse_motion(0.0, 18.0)
		await _settle_frames(4)
		crosshair_state = runtime.get_crosshair_state() as Dictionary
	return crosshair_state

func _retarget_fpv_toward_solved_target(runtime: CharacterBody3D, artillery_origin_world_position: Vector3, baseline_target_world_position: Vector3, min_target_delta_m: float, min_distance_m: float, max_distance_m: float) -> Dictionary:
	var crosshair_state := runtime.get_crosshair_state() as Dictionary
	var lateral_step := runtime.global_transform.basis.x
	lateral_step.y = 0.0
	if lateral_step.length_squared() <= 0.0001:
		lateral_step = Vector3.RIGHT
	lateral_step = lateral_step.normalized() * 28.0
	for _attempt in range(18):
		var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
		var target_distance_m := artillery_origin_world_position.distance_to(target_world_position)
		if target_world_position != Vector3.ZERO and target_distance_m >= min_distance_m and target_distance_m <= max_distance_m and target_world_position.distance_to(baseline_target_world_position) >= min_target_delta_m:
			return crosshair_state
		_set_mouse_motion(32.0, 0.0)
		if ((_attempt + 1) % 6) == 0:
			runtime.global_position += lateral_step
		await _settle_frames(4)
		crosshair_state = runtime.get_crosshair_state() as Dictionary
	return crosshair_state

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_world_key(world: Node, keycode: Key) -> void:
	world._unhandled_input(_build_key_event(keycode, true))

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

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
