extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for artillery observer closeout contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_artillery_observation_state"), "Artillery observer closeout contract requires CityPrototype.get_artillery_observation_state()"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "Artillery observer closeout contract requires artillery shell explosion introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Artillery observer closeout contract requires the teleportable PlayerController runtime"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "Artillery observer closeout contract requires a formal summoned howitzer"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_key(world, KEY_E)
	await _settle_frames()

	howitzer.set_axis_angles_degrees(0.0, 0.0)
	await _settle_frames()

	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(8)
	_release_live_key(KEY_SPACE)
	await _settle_frames()

	var observation_state := await _wait_for_observation_activation(world, 120)
	if not T.require_true(self, bool(observation_state.get("active", false)), "Accepted artillery fire must activate a formal observer closeout runtime even without an active map mission marker"):
		return
	if not T.require_true(self, str(observation_state.get("phase", "")) != "", "Artillery observer closeout runtime must expose its current phase instead of hiding it inside private timers"):
		return
	if not T.require_true(self, observation_state.get("predicted_impact_world_position", null) is Vector3, "Artillery observer closeout runtime must expose the predicted impact world position derived from the actual firing solution"):
		return
	if not T.require_true(self, str(observation_state.get("predicted_impact_chunk_id", "")) != "", "Artillery observer closeout runtime must expose the prewarmed impact chunk id"):
		return
	if not T.require_true(self, int(observation_state.get("prewarm_entry_count", 0)) > 0, "Artillery observer closeout runtime must prewarm at least one target chunk/page entry before the impact cutaway"):
		return

	var impact_stage_state := await _wait_for_observation_phase(world, "impact_stage", 240)
	if not T.require_true(self, str(impact_stage_state.get("camera_owner", "")) == "artillery_observer", "During the impact-stage cutaway, camera ownership must transfer to the artillery observer view instead of staying on the player"):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 240)
	if not T.require_true(self, not explosion_result.is_empty(), "Artillery observer closeout contract requires the live shell impact result during the observation window"):
		return

	var restored_state := await _wait_for_observation_restore(world, 240)
	if not T.require_true(self, not bool(restored_state.get("active", true)), "Artillery observer closeout runtime must finish and clear its active flag after the cutaway completes"):
		return
	if not T.require_true(self, str(restored_state.get("camera_owner", "")) == "player", "After the observer closeout completes, camera ownership must return to the player"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_observation_activation(world: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var state := world.get_artillery_observation_state() as Dictionary
		if bool(state.get("active", false)):
			return state
	return {}

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
