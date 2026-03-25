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
	if not T.require_true(self, world.has_method("get_world_howitzer_operation_state"), "Artillery observer closeout contract requires world howitzer operation-state introspection for observer restore validation"):
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
	var operation_state_before_fire := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state_before_fire.get("active", false)), "Entering howitzer operation before the shot must activate the formal操炮状态 instead of leaving the player outside the fire-control loop"):
		return

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
	var planned_total_duration_sec := float(observation_state.get("planned_total_duration_sec", 0.0))
	if not T.require_true(self, planned_total_duration_sec >= 3.0 and planned_total_duration_sec <= 5.0, "Artillery observer closeout must stay within the intended 3-5 second observation envelope instead of restoring too abruptly or lingering too long (planned_total=%0.2fs)" % planned_total_duration_sec):
		return

	var impact_stage_state := await _wait_for_observation_phase(world, "impact_stage", 240)
	if not T.require_true(self, str(impact_stage_state.get("camera_owner", "")) == "artillery_observer", "During the impact-stage cutaway, camera ownership must transfer to the artillery observer view instead of staying on the player"):
		return
	var observer_camera := world.get_node_or_null("ArtilleryFireMissionRuntime/ObserverRig/ObserverCamera") as Camera3D
	if not T.require_true(self, observer_camera != null and observer_camera.current, "Impact-stage cutaway must drive a live observer camera node instead of only toggling camera-owner text"):
		return
	var predicted_impact_world_position := impact_stage_state.get("predicted_impact_world_position", Vector3.ZERO) as Vector3
	var observer_forward := (-observer_camera.global_transform.basis.z).normalized()
	var camera_to_target := (predicted_impact_world_position + Vector3.UP * 4.0) - observer_camera.global_position
	if not T.require_true(self, camera_to_target.length_squared() > 0.01, "Observer camera contract requires a non-degenerate target vector toward the predicted impact point"):
		return
	var observer_alignment := observer_forward.dot(camera_to_target.normalized())
	if not T.require_true(self, observer_alignment >= 0.82, "Impact-stage observer camera must actually face the predicted impact point instead of flipping away toward the sky (alignment=%0.3f)" % observer_alignment):
		return
	var observer_planar_distance_m := Vector2(camera_to_target.x, camera_to_target.z).length()
	if not T.require_true(self, observer_planar_distance_m <= 46.0, "Impact-stage observer camera must cut in close enough to the impact point instead of hanging too far back over the target chunk (planar_distance=%0.2fm)" % observer_planar_distance_m):
		return
	if not T.require_true(self, observer_camera.global_position.y <= predicted_impact_world_position.y + 32.0, "Impact-stage observer camera must stay closer to the intended ~30m overhead framing instead of drifting too high above the target area"):
		return
	if not T.require_true(self, observer_camera.global_position.y >= predicted_impact_world_position.y + 18.0, "Impact-stage observer camera must stay above the target area for a proper俯视 cutaway instead of collapsing to near-ground level"):
		return
	if not T.require_true(self, observer_forward.y <= -0.24, "Impact-stage observer camera must keep a downward-looking pitch instead of tilting upward toward the horizon or sun (forward_y=%0.3f)" % observer_forward.y):
		return

	var explosion_result := await _wait_for_shell_explosion(world, 240)
	if not T.require_true(self, not explosion_result.is_empty(), "Artillery observer closeout contract requires the live shell impact result during the observation window"):
		return

	var restored_state := await _wait_for_observation_restore(world, 240)
	if not T.require_true(self, not bool(restored_state.get("active", true)), "Artillery observer closeout runtime must finish and clear its active flag after the cutaway completes"):
		return
	if not T.require_true(self, str(restored_state.get("camera_owner", "")) == "player", "After the observer closeout completes, camera ownership must return to the player"):
		return
	var operation_state_after_restore := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state_after_restore.get("active", false)), "Observer closeout must return the player to the ongoing操炮状态 instead of silently dropping out of howitzer operation after one shot"):
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
