extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for map artillery fire-mission flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Map artillery fire-mission flow requires full-map visibility control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Map artillery fire-mission flow requires map render state introspection"):
		return
	if not T.require_true(self, world.has_method("request_artillery_fire_mission_from_world_point"), "Map artillery fire-mission flow requires the formal artillery mission request API"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Map artillery fire-mission flow requires artillery fire-mission state introspection"):
		return
	if not T.require_true(self, world.has_method("get_artillery_observation_state"), "Map artillery fire-mission flow requires artillery observation state introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Map artillery fire-mission flow requires the formal PlayerController runtime"):
		return

	world.set_full_map_open(true)
	await process_frame

	var full_map := world.get_node_or_null("Hud/Root/FullMap") as Control
	if not T.require_true(self, full_map != null and full_map.has_method("world_to_map"), "Map artillery fire-mission flow requires the mounted FullMap control with world_to_map() support"):
		return

	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target_world_position := player.global_position + forward * 3200.0
	var map_click_position: Vector2 = full_map.world_to_map(target_world_position)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = map_click_position
	full_map._gui_input(right_click)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	var context_menu: Dictionary = map_state.get("context_menu", {})
	if not T.require_true(self, bool(context_menu.get("visible", false)), "Right-clicking the full map target must open the artillery context menu before the mission is committed"):
		return

	var mission_contract := world.request_artillery_fire_mission_from_world_point(target_world_position) as Dictionary
	if not T.require_true(self, not mission_contract.is_empty(), "Map artillery fire-mission flow must commit a formal mission contract for the selected target"):
		return

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(solution_state.get("solved", false)), "Map artillery fire-mission flow requires an in-range solved bearing/pitch solution"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, not world.is_world_simulation_paused(), "Closing the full map after creating the artillery mission must resume the world simulation"):
		return

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "Map artillery fire-mission flow must allow the user to summon the main-world howitzer after planning a mission"):
		return
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "Map artillery fire-mission flow requires the summoned formal howitzer runtime"):
		return
	howitzer.set_axis_angles_degrees(
		float(solution_state.get("world_bearing_deg", 0.0)),
		float(solution_state.get("pitch_deg", 0.0))
	)
	await _settle_frames()

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_key(world, KEY_E)
	await _settle_frames()

	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(8)
	_release_live_key(KEY_SPACE)

	var observation_state := await _wait_for_observation_phase(world, "impact_stage", 360)
	if not T.require_true(self, str(observation_state.get("camera_owner", "")) == "artillery_observer", "Map artillery fire-mission flow must eventually cut to the artillery observer camera during the impact stage"):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 360)
	if not T.require_true(self, not explosion_result.is_empty(), "Map artillery fire-mission flow requires a formal artillery shell impact result in the observer window"):
		return

	var restored_state := await _wait_for_observation_restore(world, 360)
	if not T.require_true(self, str(restored_state.get("camera_owner", "")) == "player", "Map artillery fire-mission flow must restore player camera ownership after observer closeout"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_observation_phase(world: Node, phase: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var state := world.get_artillery_observation_state() as Dictionary
		if str(state.get("phase", "")) == phase:
			return state
	return {}

func _wait_for_observation_restore(world: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var state := world.get_artillery_observation_state() as Dictionary
		if not bool(state.get("active", false)) and str(state.get("camera_owner", "")) == "player":
			return state
	return world.get_artillery_observation_state() as Dictionary

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
