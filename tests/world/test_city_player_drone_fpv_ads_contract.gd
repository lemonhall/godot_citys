extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone FPV ADS contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone FPV ADS contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone FPV ADS contract requires the mounted PlayerDroneRuntime node"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone FPV ADS contract requires the drone to reach active flight before validating FPV mode"):
		return
	if not T.require_true(self, str(active_state.get("view_mode", "")) == "third_person", "Active drone must start in third_person view before any FPV ADS toggle"):
		return
	if not T.require_true(self, not bool(active_state.get("fpv_filter_enabled", true)), "Third-person drone flight must not leak the FPV infrared filter by default"):
		return
	if not T.require_true(self, not bool(active_state.get("fpv_crosshair_visible", true)), "Third-person drone flight must not force the FPV crosshair visible before ADS is entered"):
		return

	_set_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_set_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance_frames(12)

	var fpv_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(fpv_state.get("view_mode", "")) == "fpv_ads", "Right click during active drone flight must switch the drone into fpv_ads view mode"):
		return
	if not T.require_true(self, bool(fpv_state.get("fpv_filter_enabled", false)), "FPV ADS drone mode must enable the infrared black-and-white filter contract"):
		return
	if not T.require_true(self, bool(fpv_state.get("fpv_crosshair_visible", false)), "FPV ADS drone mode must expose a visible crosshair contract"):
		return
	if not T.require_true(self, float(fpv_state.get("fpv_fov_deg", 999.0)) <= 56.0, "FPV ADS drone mode must narrow the field of view into an ADS-style zoomed camera"):
		return

	_set_mouse_motion(-24.0, 16.0)
	await _advance_frames(4)
	var look_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, absf(float(look_state.get("fpv_yaw_deg", 0.0))) >= 2.0, "FPV ADS drone mode must let horizontal mouse motion steer the first-person view left and right"):
		return
	if not T.require_true(self, absf(float(look_state.get("fpv_pitch_deg", 0.0))) >= 1.0, "FPV ADS drone mode must let vertical mouse motion tilt the first-person view up and down"):
		return
	if not T.require_true(self, absf(float(look_state.get("fpv_pitch_deg", 0.0))) <= 75.0, "FPV ADS drone mode must clamp pitch so the view cannot flip into an unusable full inversion"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_crosshair_state"), "Player drone FPV ADS contract requires the mounted HUD crosshair state API"):
		return
	await _advance_frames(8)
	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "FPV ADS drone mode must route the HUD crosshair onto the drone view instead of leaving the HUD blind"):
		return
	var screen_position := crosshair_state.get("screen_position", Vector2.ZERO) as Vector2
	var viewport_size := crosshair_state.get("viewport_size", Vector2.ZERO) as Vector2
	if not T.require_true(self, screen_position.distance_to(viewport_size * 0.5) <= 8.0, "Drone FPV ADS crosshair must stay centered on the first-person view"):
		return
	if not T.require_true(self, crosshair_state.has("world_target"), "Drone FPV ADS crosshair contract must expose a world_target for later kamikaze lock-on"):
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
