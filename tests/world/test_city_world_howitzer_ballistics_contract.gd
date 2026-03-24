extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const SHELL_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryShell.gd"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "World howitzer ballistics contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "World howitzer ballistics contract requires get_active_world_howitzer()"):
		return
	if not T.require_true(self, world.has_method("get_active_artillery_shell_count"), "World howitzer ballistics contract requires get_active_artillery_shell_count()"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "World howitzer ballistics contract requires get_last_artillery_shell_explosion_result()"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "World howitzer ballistics contract requires a teleportable PlayerController"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees") and howitzer.has_method("get_last_fired_solution"), "World howitzer ballistics contract requires the formal howitzer runtime and firing solution API"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_key(world, KEY_E)
	await _settle_frames()

	howitzer.set_axis_angles_degrees(0.0, 0.0)
	await _settle_frames()

	var fire_count_before := int((howitzer.get_fire_state() as Dictionary).get("fire_count", 0))
	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(8)
	_release_live_key(KEY_SPACE)
	await _settle_frames()

	if not T.require_true(self, int((howitzer.get_fire_state() as Dictionary).get("fire_count", 0)) == fire_count_before + 1, "Accepted world howitzer fire must still advance the formal howitzer fire count before shell verification starts"):
		return
	if not T.require_true(self, int(world.get_active_artillery_shell_count()) >= 1, "Accepted world howitzer fire must spawn at least one live artillery shell runtime instead of only muzzle presentation"):
		return

	var shell := _find_shell_node(world)
	if not T.require_true(self, shell != null and shell.has_method("get_debug_state") and shell.has_method("get_last_explosion_result"), "Main-world artillery shot must instantiate the formal CityArtilleryShell runtime"):
		return

	var shell_state := shell.get_debug_state() as Dictionary
	if not T.require_true(self, shell_state.get("firing_solution", null) is Dictionary, "Artillery shell runtime must preserve the launch firing_solution payload instead of inventing a separate ad-hoc launch contract"):
		return
	if not T.require_true(self, float(shell_state.get("distance_travelled_m", 0.0)) > 0.0, "Fresh artillery shell runtime must start travelling after the accepted shot instead of idling at the muzzle"):
		return
	if not T.require_true(self, float(shell_state.get("simulation_time_scale", 0.0)) > 0.0, "Artillery shell runtime must expose its formal ballistic time-compression factor for regression verification"):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 240)
	if not T.require_true(self, not explosion_result.is_empty(), "Artillery shell runtime must eventually resolve an impact/explosion result in the main world"):
		return
	if not T.require_true(self, str(explosion_result.get("trigger_kind", "")) != "", "Artillery shell explosion result must expose a concrete trigger_kind"):
		return
	if not T.require_true(self, explosion_result.get("firing_solution", null) is Dictionary, "Artillery shell explosion result must carry the originating firing_solution payload forward for downstream systems"):
		return
	if not T.require_true(self, explosion_result.has("pedestrian_result") and explosion_result.has("vehicle_result"), "Artillery shell explosion result must expose the world pedestrian/vehicle blast consumer results even when they are empty"):
		return
	if not T.require_true(self, float(explosion_result.get("distance_travelled_m", 0.0)) > 0.0 and float(explosion_result.get("flight_time_sec", 0.0)) > 0.0, "Artillery shell explosion result must expose non-zero flight distance and flight time so ballistics are not reduced to an instant detonation"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

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

func _press_key(target: Node, keycode: Key) -> void:
	target._unhandled_input(_build_key_event(keycode, true))

func _release_live_key(keycode: Key) -> void:
	Input.parse_input_event(_build_key_event(keycode, false))

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
