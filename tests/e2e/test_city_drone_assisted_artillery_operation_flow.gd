extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for drone-assisted artillery operation flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Drone-assisted artillery operation flow requires drone debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_artillery_observation_state"), "Drone-assisted artillery operation flow requires artillery observation introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "Drone-assisted artillery operation flow requires shell impact introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Drone-assisted artillery operation flow requires the teleportable PlayerController runtime"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "Drone-assisted artillery operation flow requires the shared artillery solution HUD consumer"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()
	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "Drone-assisted artillery operation flow requires the summoned formal howitzer runtime"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_world_key(world, KEY_E)
	await _settle_frames()
	_press_world_key(world, KEY_KP_5)
	var drone_state := await _wait_for_drone_state(world, "active", 180)
	if not T.require_true(self, str(drone_state.get("camera_owner", "")) == "drone", "Drone-assisted artillery operation flow must end drone deploy with drone camera ownership"):
		return

	var artillery_solution_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Drone-assisted artillery operation flow must keep artillery solution HUD visible in composite mode"):
		return

	var drone_runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, drone_runtime != null, "Drone-assisted artillery operation flow requires the mounted PlayerDroneRuntime node"):
		return
	await _settle_frames(8)
	var drone_y_before_e := drone_runtime.global_position.y
	var e_event := _build_key_event(KEY_E, true)
	Input.parse_input_event(e_event)
	world._input(e_event)
	world._unhandled_input(e_event)
	await _settle_frames(18)
	_release_live_key(world, KEY_E)
	await _settle_frames(6)
	if not T.require_true(self, bool((world.get_world_howitzer_operation_state() as Dictionary).get("active", false)), "Drone-assisted artillery operation flow must keep howitzer operation active when E is used to raise the drone in composite mode"):
		return
	var drone_e_height_delta_m := drone_runtime.global_position.y - drone_y_before_e
	if not T.require_true(self, drone_e_height_delta_m >= 0.35, "Drone-assisted artillery operation flow must still let E raise the drone in composite mode (delta=%0.3fm)" % drone_e_height_delta_m):
		return

	howitzer.set_axis_angles_degrees(0.0, 0.0)
	await _settle_frames(8)
	var fire_count_before := int((howitzer.get_fire_state() as Dictionary).get("fire_count", 0))
	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._input(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(10)
	_release_live_key(world, KEY_SPACE)

	var fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, int(fire_state.get("fire_count", 0)) == fire_count_before + 1, "Drone-assisted artillery operation flow must still let Space fire the howitzer in composite mode"):
		return

	await _settle_frames(24)
	var observation_state := world.get_artillery_observation_state() as Dictionary
	if not T.require_true(self, not bool(observation_state.get("active", false)), "Drone-assisted artillery operation flow must not enter observer closeout after the shot"):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 360)
	if not T.require_true(self, not explosion_result.is_empty(), "Drone-assisted artillery operation flow still requires a real shell impact result"):
		return

	drone_state = world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, str(drone_state.get("camera_owner", "")) == "drone", "Drone-assisted artillery operation flow must leave camera ownership on the drone so the player can observe the impact manually"):
		return
	if not T.require_true(self, bool((world.get_world_howitzer_operation_state() as Dictionary).get("active", false)), "Drone-assisted artillery operation flow must keep howitzer operation active after the shot"):
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

func _wait_for_shell_explosion(world: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var result := world.get_last_artillery_shell_explosion_result() as Dictionary
		if not result.is_empty():
			return result
	return {}

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_world_key(world: Node, keycode: Key) -> void:
	world._unhandled_input(_build_key_event(keycode, true))

func _release_live_key(world: Node, keycode: Key) -> void:
	var event := _build_key_event(keycode, false)
	Input.parse_input_event(event)
	world._input(event)

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
