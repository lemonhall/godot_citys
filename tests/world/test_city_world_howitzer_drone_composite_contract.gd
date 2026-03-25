extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const SHELL_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryShell.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for world howitzer drone composite contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "World howitzer drone composite contract requires get_active_world_howitzer()"):
		return
	if not T.require_true(self, world.has_method("get_world_howitzer_operation_state"), "World howitzer drone composite contract requires get_world_howitzer_operation_state()"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "World howitzer drone composite contract requires get_player_drone_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_artillery_observation_state"), "World howitzer drone composite contract requires artillery observation introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "World howitzer drone composite contract requires artillery shell explosion introspection"):
		return
	if not T.require_true(self, world.has_method("get_active_artillery_shell_count"), "World howitzer drone composite contract requires live shell-count introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "World howitzer drone composite contract requires the teleportable PlayerController runtime"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "World howitzer drone composite contract requires the shared artillery solution HUD consumer"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "World howitzer drone composite contract requires a summoned formal howitzer runtime"):
		return
	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_world_key(world, KEY_E)
	await _settle_frames()
	var operation_state := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Entering howitzer operation is required before validating the drone-assisted composite contract"):
		return

	_press_world_key(world, KEY_KP_5)
	var drone_state := await _wait_for_drone_state(world, "active", 180)
	if not T.require_true(self, str(drone_state.get("camera_owner", "")) == "drone", "Drone-assisted composite contract requires the drone to own the camera after deploy completes"):
		return

	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Deploying the drone while already operating the howitzer must not release the howitzer operation state"):
		return
	var artillery_solution_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Drone-assisted composite contract must keep the artillery solution HUD visible while the player is still operating the howitzer"):
		return

	var drone_runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, drone_runtime != null, "Drone-assisted composite contract requires the mounted PlayerDroneRuntime node for composite input verification"):
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
	var blocked_interaction_result := world.handle_primary_interaction() as Dictionary
	if not T.require_true(self, not bool(blocked_interaction_result.get("success", false)), "Drone-assisted composite contract must explicitly reject howitzer exit interaction while the drone is active instead of silently toggling operation state"):
		return
	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Drone-assisted composite contract must not let E exit howitzer operation once the composite drone+artillery mode is active"):
		return
	var drone_e_height_delta_m := drone_runtime.global_position.y - drone_y_before_e
	if not T.require_true(self, drone_e_height_delta_m >= 0.35, "Drone-assisted composite contract must still route E to drone ascend while preserving howitzer operation (delta=%0.3fm)" % drone_e_height_delta_m):
		return

	var yaw_before := float(howitzer.get_yaw_degrees())
	var pitch_before := float(howitzer.get_pitch_degrees())
	_press_live_key(world, KEY_L)
	await _settle_frames(8)
	_release_live_key(world, KEY_L)
	_press_live_key(world, KEY_I)
	await _settle_frames(8)
	_release_live_key(world, KEY_I)
	await _settle_frames()
	if not T.require_true(self, absf(float(howitzer.get_yaw_degrees()) - yaw_before) >= 0.1, "Drone-assisted composite contract must keep coarse howitzer yaw input alive while the drone is active"):
		return
	if not T.require_true(self, float(howitzer.get_pitch_degrees()) > pitch_before + 0.1, "Drone-assisted composite contract must keep coarse howitzer pitch input alive while the drone is active"):
		return

	var fine_yaw_before := float(howitzer.get_yaw_degrees())
	var fine_pitch_before := float(howitzer.get_pitch_degrees())
	_press_live_key(world, KEY_SHIFT)
	await _settle_frames(1)
	_press_live_key(world, KEY_L)
	await _settle_frames(10)
	_release_live_key(world, KEY_L)
	_press_live_key(world, KEY_I)
	await _settle_frames(10)
	_release_live_key(world, KEY_I)
	_release_live_key(world, KEY_SHIFT)
	await _settle_frames(2)
	if not T.require_true(self, absf(absf(float(howitzer.get_yaw_degrees()) - fine_yaw_before) - 0.1) <= 0.03, "Drone-assisted composite contract must preserve Shift+L 0.1 degree fine yaw while the drone is active"):
		return
	if not T.require_true(self, absf((float(howitzer.get_pitch_degrees()) - fine_pitch_before) - 0.1) <= 0.03, "Drone-assisted composite contract must preserve Shift+I 0.1 degree fine pitch while the drone is active"):
		return

	howitzer.set_axis_angles_degrees(0.0, 0.0)
	await _settle_frames(8)
	await _settle_frames(8)
	var drone_y_before_fire := drone_runtime.global_position.y
	var fire_count_before := int((howitzer.get_fire_state() as Dictionary).get("fire_count", 0))
	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._input(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(10)
	_release_live_key(world, KEY_SPACE)
	await _settle_frames(24)

	var fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, int(fire_state.get("fire_count", 0)) == fire_count_before + 1, "Drone-assisted composite contract must keep Space owned by howitzer fire even while the drone is active"):
		return
	var drone_fire_height_delta_m := drone_runtime.global_position.y - drone_y_before_fire
	if not T.require_true(self, absf(drone_fire_height_delta_m) <= 0.12, "Drone-assisted composite contract must not let Space firing input leak into drone climb (delta=%0.3fm)" % drone_fire_height_delta_m):
		return

	var observation_state := world.get_artillery_observation_state() as Dictionary
	if not T.require_true(self, not bool(observation_state.get("active", false)), "Drone-assisted composite contract must skip observer closeout when drone active and howitzer operation active are both true"):
		return

	if not T.require_true(self, int(world.get_active_artillery_shell_count()) >= 1, "Drone-assisted composite contract must still spawn a live artillery shell runtime even when observer closeout is skipped"):
		return
	var shell := _find_shell_node(world)
	if not T.require_true(self, shell != null and shell.has_method("get_debug_state"), "Drone-assisted composite contract must expose the spawned artillery shell runtime so the composite launch payload can be verified"):
		return
	var shell_state := shell.get_debug_state() as Dictionary
	var shell_firing_solution := shell_state.get("firing_solution", {}) as Dictionary
	if not T.require_true(self, bool(shell_firing_solution.get("observer_force_predicted_impact", false)), "Drone-assisted composite contract must still stamp the shell payload with observer_force_predicted_impact so the skipped camera closeout does not also skip the solved target impact"):
		return
	if not T.require_true(self, shell_firing_solution.get("observer_forced_impact_world_position", null) is Vector3, "Drone-assisted composite contract must still stamp the shell payload with a forced impact world position"):
		return
	if not T.require_true(self, maxf(float(shell_firing_solution.get("observer_forced_impact_flight_time_sec", 0.0)), 0.0) > 0.0, "Drone-assisted composite contract must still stamp the shell payload with a forced impact flight time once observer closeout is skipped"):
		return
	if not T.require_true(self, maxf(float(shell_firing_solution.get("observation_ballistic_time_scale", 0.0)), 0.0) > 0.0, "Drone-assisted composite contract must still stamp the shell payload with the observation ballistic time scale so composite shots keep their target-area timing contract"):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 360)
	if not T.require_true(self, not explosion_result.is_empty(), "Drone-assisted composite contract must still produce the artillery shell impact result even when observer closeout is skipped"):
		return
	if not T.require_true(self, str(explosion_result.get("trigger_kind", "")) == "forced_predicted_impact", "Drone-assisted composite contract must still resolve the shell through forced_predicted_impact instead of falling back to an arbitrary physics collision once observer closeout is skipped"):
		return

	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Drone-assisted composite contract must return the player to the still-active howitzer operation state after the shot instead of dropping operation ownership"):
		return
	artillery_solution_state = hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Drone-assisted composite contract must keep the artillery solution HUD visible after the shot because operation ownership never left the howitzer"):
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

func _find_shell_node(root_node: Node) -> Node3D:
	for node_variant: Variant in root_node.find_children("*", "Node3D", true, false):
		var node := node_variant as Node3D
		if node == null:
			continue
		var script: Variant = node.get_script()
		if script == null:
			continue
		if str(script.resource_path) == SHELL_SCRIPT_PATH:
			return node
	return null

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_world_key(world: Node, keycode: Key) -> void:
	world._unhandled_input(_build_key_event(keycode, true))

func _press_live_key(world: Node, keycode: Key) -> void:
	var event := _build_key_event(keycode, true)
	Input.parse_input_event(event)
	world._input(event)

func _release_live_key(world: Node, keycode: Key) -> void:
	var event := _build_key_event(keycode, false)
	Input.parse_input_event(event)
	world._input(event)

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
