extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone suicide strike contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone suicide strike contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("is_control_enabled"), "Player drone suicide strike contract requires the mounted PlayerController runtime"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null and runtime.has_method("get_crosshair_state"), "Player drone suicide strike contract requires the mounted PlayerDroneRuntime crosshair API"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Suicide strike contract requires the drone to reach active flight before lock-on"):
		return

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var crosshair_state := await _aim_fpv_toward_close_target(runtime, 220.0)
	var target_world_position := crosshair_state.get("world_target", Vector3.ZERO) as Vector3
	if not T.require_true(self, runtime.global_position.distance_to(target_world_position) <= 220.0, "Drone FPV suicide strike contract requires a reachable crosshair world target instead of a far-horizon dummy point"):
		return

	_set_mouse_button(MOUSE_BUTTON_LEFT, true)
	_set_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _advance_frames(3)

	var strike_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, bool(strike_state.get("strike_committed", false)), "Left click in drone FPV ADS mode must commit a suicide strike instead of remaining manual flight"):
		return
	if not T.require_true(self, str(strike_state.get("strike_state", "")) == "locked" or str(strike_state.get("strike_state", "")) == "striking" or str(strike_state.get("strike_state", "")) == "exploding", "Committed drone suicide strike must transition into locked/striking/exploding state instead of staying idle"):
		return
	if not T.require_true(self, bool(strike_state.get("fpv_filter_enabled", false)), "Committed drone suicide strike must preserve the FPV infrared filter through the impact run"):
		return
	if not T.require_true(self, str(strike_state.get("view_mode", "")) == "fpv_ads", "Committed drone suicide strike must stay in fpv_ads view instead of snapping back to third person before impact"):
		return
	if not T.require_true(self, not bool(strike_state.get("manual_flight_input_enabled", true)), "Committed drone suicide strike must disable manual flight input once autopilot takes over"):
		return
	if not T.require_true(self, str(strike_state.get("camera_owner", "")) == "drone", "Committed drone suicide strike must keep camera ownership on the drone until blast closeout completes"):
		return
	var strike_phase := str(strike_state.get("strike_state", ""))
	var locked_target_world_position := strike_state.get("locked_target_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, locked_target_world_position.distance_to(target_world_position) <= 6.0, "Drone suicide strike must freeze the FPV lock target at commit time instead of recomputing a drifting target every frame"):
		return
	var strike_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, strike_camera != null, "Drone suicide strike contract requires the mounted drone camera for FPV forward-alignment verification"):
		return
	if strike_phase == "locked" or strike_phase == "striking":
		var camera_forward := (-strike_camera.global_transform.basis.z).normalized()
		var camera_to_target := (locked_target_world_position - strike_camera.global_position).normalized()
		var strike_alignment := camera_forward.dot(camera_to_target)
		if not T.require_true(self, strike_alignment >= 0.8, "Committed drone suicide strike must keep the FPV camera broadly facing the locked target before impact instead of flipping backward toward the player body (alignment=%0.3f)" % strike_alignment):
			return

	await _advance_frames(4)

	_press_world_key(world, KEY_KP_5)
	await _advance_frames(4)
	var interrupt_attempt_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(interrupt_attempt_state.get("system_state", "")) == "active", "Pressing KP5 after strike commit must not interrupt the kamikaze run with a recovery animation"):
		return
	if not T.require_true(self, str(interrupt_attempt_state.get("last_reject_reason", "")) == "strike_committed", "KP5 recovery requests during a committed suicide strike must be explicitly rejected as strike_committed"):
		return

	var signal_loss_state := await _wait_for_strike_state(world, "signal_loss", 240)
	if not T.require_true(self, str(signal_loss_state.get("strike_state", "")) == "signal_loss", "Drone suicide strike contract must enter a dedicated signal_loss closeout phase after the blast instead of returning to the player immediately"):
		return
	if not T.require_true(self, bool(signal_loss_state.get("signal_loss_active", false)), "Drone suicide strike contract must expose signal_loss_active while the FPV feed is visibly lost"):
		return
	if not T.require_true(self, str(signal_loss_state.get("overlay_mode", "")) == "signal_loss", "Drone suicide strike contract must switch the FPV overlay into a signal_loss mode after the blast instead of leaving infrared active"):
		return
	if not T.require_true(self, bool(signal_loss_state.get("no_signal_visible", false)), "Drone suicide strike contract must flash a visible NO SIGNAL prompt during the post-blast feed loss window"):
		return
	if not T.require_true(self, str(signal_loss_state.get("camera_owner", "")) == "drone", "Drone suicide strike contract must keep the drone camera alive during the post-blast signal loss window instead of cutting away too early"):
		return
	if not T.require_true(self, str(signal_loss_state.get("input_owner", "")) == "none", "Drone suicide strike contract must not restore manual control until the signal loss closeout finishes"):
		return

	var stowed_state := await _wait_for_state(world, "stowed", 360)
	if not T.require_true(self, str(stowed_state.get("system_state", "")) == "stowed", "Drone suicide strike contract must return the runtime to stowed after the explosion closeout finishes"):
		return
	if not T.require_true(self, str(stowed_state.get("camera_owner", "")) == "player", "Drone suicide strike contract must restore camera ownership to the player after blast closeout"):
		return
	if not T.require_true(self, str(stowed_state.get("input_owner", "")) == "player", "Drone suicide strike contract must restore player input ownership after blast closeout"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "Drone suicide strike contract must restore PlayerController control after blast closeout"):
		return
	var last_strike_result := stowed_state.get("last_strike_result", {}) as Dictionary
	if not T.require_true(self, not last_strike_result.is_empty(), "Drone suicide strike contract must preserve a last_strike_result summary for verification and debugging"):
		return
	if not T.require_true(self, str(last_strike_result.get("trigger_kind", "")) != "", "Drone suicide strike contract must record why the strike exploded instead of leaving trigger_kind empty"):
		return
	if not T.require_true(self, last_strike_result.get("explosion_world_position", Vector3.ZERO) is Vector3, "Drone suicide strike contract must record the explosion world position in the strike summary"):
		return

	_press_world_key(world, KEY_KP_5)
	var redeploy_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(redeploy_state.get("system_state", "")) == "active", "Drone suicide strike contract requires a second deploy cycle so post-strike attitude reset can be regression tested"):
		return
	var body_pitch_deg := absf(rad_to_deg(runtime.rotation.x))
	var body_roll_deg := absf(rad_to_deg(runtime.rotation.z))
	if not T.require_true(self, body_pitch_deg <= 1.0 and body_roll_deg <= 1.0, "Every fresh drone deploy must reset the root aircraft attitude back to level hover instead of inheriting post-strike pitch/roll (pitch=%0.3f roll=%0.3f)" % [body_pitch_deg, body_roll_deg]):
		return
	var model_root := runtime.get_node_or_null("ModelRoot") as Node3D
	if not T.require_true(self, model_root != null, "Drone suicide strike contract requires ModelRoot so fresh-deploy visual attitude can be verified"):
		return
	var model_pitch_deg := absf(rad_to_deg(model_root.rotation.x))
	var model_roll_deg := absf(rad_to_deg(model_root.rotation.z))
	if not T.require_true(self, model_pitch_deg <= 4.0 and model_roll_deg <= 4.0, "Every fresh drone deploy must also reset the visible drone body back near level hover instead of spawning nose-up or nose-down (pitch=%0.3f roll=%0.3f)" % [model_pitch_deg, model_roll_deg]):
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
