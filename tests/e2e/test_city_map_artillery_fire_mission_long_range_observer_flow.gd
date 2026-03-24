extends SceneTree

const T := preload("res://tests/_test_util.gd")

const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const LONG_RANGE_TARGET_DISTANCE_M := 5000.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for long-range artillery observer flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Long-range artillery observer flow requires full-map visibility control"):
		return
	if not T.require_true(self, world.has_method("request_artillery_fire_mission_from_world_point"), "Long-range artillery observer flow requires the formal artillery mission request API"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Long-range artillery observer flow requires artillery fire-mission state introspection"):
		return
	if not T.require_true(self, world.has_method("get_artillery_observation_state"), "Long-range artillery observer flow requires artillery observation state introspection"):
		return
	if not T.require_true(self, world.has_method("get_chunk_streamer"), "Long-range artillery observer flow requires chunk-streamer introspection"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Long-range artillery observer flow requires the formal PlayerController runtime"):
		return

	world.set_full_map_open(true)
	await process_frame

	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target_world_position := player.global_position + forward * LONG_RANGE_TARGET_DISTANCE_M
	var mission_contract := world.request_artillery_fire_mission_from_world_point(target_world_position) as Dictionary
	if not T.require_true(self, not mission_contract.is_empty(), "Long-range artillery observer flow must commit a formal mission contract for the selected target"):
		return

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(solution_state.get("solved", false)), "Long-range artillery observer flow requires an in-range solved bearing/pitch solution"):
		return

	world.set_full_map_open(false)
	await process_frame

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "Long-range artillery observer flow must allow summoning the main-world howitzer after planning a mission"):
		return
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "Long-range artillery observer flow requires the summoned formal howitzer runtime"):
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

	var observation_state := await _wait_for_observation_activation(world, 120)
	if not T.require_true(self, bool(observation_state.get("active", false)), "Long-range artillery observer flow must activate the observer runtime after accepted fire"):
		return
	var predicted_flight_time_sec := float(observation_state.get("flight_time_sec", 0.0))
	if not T.require_true(self, predicted_flight_time_sec >= 10.0, "Long-range artillery observer flow must expose the long predicted shell flight time so observer timing can compress it intentionally instead of behaving as if every shot were point-blank (flight_time=%0.2fs)" % predicted_flight_time_sec):
		return
	var planned_total_duration_sec := float(observation_state.get("planned_total_duration_sec", 0.0))
	if not T.require_true(self, planned_total_duration_sec >= 3.0 and planned_total_duration_sec <= 5.0, "Long-range artillery observer flow must keep observer closeout within a 3-5 second window instead of inheriting full shell flight time (planned_total=%0.2fs)" % planned_total_duration_sec):
		return

	var impact_stage_state := await _wait_for_observation_phase(world, "impact_stage", 180)
	if not T.require_true(self, str(impact_stage_state.get("camera_owner", "")) == "artillery_observer", "Long-range artillery observer flow must cut to the observer camera during impact stage"):
		return
	var predicted_impact_chunk_id := str(impact_stage_state.get("predicted_impact_chunk_id", ""))
	var chunk_streamer = world.get_chunk_streamer()
	var streaming_snapshot := chunk_streamer.get_streaming_snapshot() as Dictionary if chunk_streamer != null and chunk_streamer.has_method("get_streaming_snapshot") else {}
	if not T.require_true(self, str(streaming_snapshot.get("current_chunk_id", "")) == predicted_impact_chunk_id, "Long-range artillery observer flow must retarget world streaming to the predicted impact chunk instead of leaving streaming anchored on the player position"):
		return

	var restored_state := await _wait_for_observation_restore(world, 360)
	if not T.require_true(self, not bool(restored_state.get("active", true)), "Long-range artillery observer flow must restore from observer closeout within a short window instead of waiting for long shell lifetimes"):
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
		if not bool(state.get("active", false)):
			return state
	return world.get_artillery_observation_state() as Dictionary

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
