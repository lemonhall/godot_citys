extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player vehicle drive mode contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Player vehicle drive mode contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for drive mode setup"):
		return
	if not T.require_true(self, player.has_method("is_driving_vehicle"), "PlayerController must expose is_driving_vehicle() for drive mode contract"):
		return
	if not T.require_true(self, player.has_method("get_driving_vehicle_state"), "PlayerController must expose get_driving_vehicle_state() for drive continuity validation"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "PlayerController must expose set_vehicle_drive_input() for drive mode contract"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "PlayerController must expose clear_vehicle_drive_input() for drive mode contract"):
		return
	if not T.require_true(self, world.has_method("resolve_vehicle_projectile_hit"), "CityPrototype must expose resolve_vehicle_projectile_hit() for drive mode setup"):
		return
	if not T.require_true(self, world.has_method("try_hijack_nearby_vehicle"), "CityPrototype must expose try_hijack_nearby_vehicle() for drive mode setup"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_state := await _prepare_hijacked_vehicle(world, player)
	if not T.require_true(self, not target_state.is_empty(), "Drive mode contract requires a successfully hijacked vehicle"):
		return
	if not T.require_true(self, player.is_driving_vehicle(), "Player must report driving mode after successful hijack"):
		return

	var foot_visual := player.get_node_or_null("Visual") as Node3D
	if not T.require_true(self, foot_visual != null and not foot_visual.visible, "Entering drive mode must hide the on-foot player visual"):
		return
	if not T.require_true(self, player.get_node_or_null("DriveVehicleVisual") != null, "Entering drive mode must mount a hijacked vehicle visual under the player rig"):
		return

	var baseline_position: Vector3 = player.global_position
	var baseline_yaw := float(player.rotation.y)
	player.set_vehicle_drive_input(1.0, 0.45, false)
	for _frame_index in range(36):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()

	var travelled_distance_m := baseline_position.distance_to(player.global_position)
	if not T.require_true(self, travelled_distance_m >= 4.5, "Driving mode must move the hijacked vehicle a noticeable distance instead of only swapping visuals"):
		return
	if not T.require_true(self, absf(wrapf(player.rotation.y - baseline_yaw, -PI, PI)) >= 0.08, "Driving mode must allow the hijacked vehicle to steer and rotate"):
		return
	if not T.require_true(self, not player.request_primary_fire(), "Driving mode must suppress rifle fire requests while the player is controlling a vehicle"):
		return
	if not T.require_true(self, not player.request_ground_slam(), "Driving mode must suppress ground slam requests while the player is controlling a vehicle"):
		return

	var driving_state: Dictionary = player.get_driving_vehicle_state()
	if not T.require_true(self, str(driving_state.get("vehicle_id", "")) == str(target_state.get("vehicle_id", "")), "Driving mode continuity must preserve the hijacked vehicle_id"):
		return
	if not T.require_true(self, float(driving_state.get("speed_mps", 0.0)) > 0.0, "Driving mode runtime state must report a positive vehicle speed after acceleration"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _prepare_hijacked_vehicle(world, player) -> Dictionary:
	var target_state := await _find_promoted_vehicle_state(world, player)
	if target_state.is_empty():
		return {}
	var target_vehicle_id := str(target_state.get("vehicle_id", ""))
	var aim_position: Vector3 = _resolve_vehicle_aim_position(target_state)
	var shot_origin: Vector3 = player.global_position + Vector3.UP * 0.9
	var shot_velocity: Vector3 = (aim_position - shot_origin).normalized() * 180.0
	world.resolve_vehicle_projectile_hit(shot_origin, aim_position, 1.0, shot_velocity)
	var stopped_snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	var stopped_state := _find_state(stopped_snapshot, target_vehicle_id)
	if stopped_state.is_empty():
		return {}
	player.teleport_to_world_position(_resolve_hijack_stand_position(stopped_state))
	await _refresh_vehicle_snapshot(world, player.global_position)
	var hijack_result: Dictionary = world.try_hijack_nearby_vehicle()
	if str(hijack_result.get("vehicle_id", "")) != target_vehicle_id:
		return {}
	return hijack_result

func _find_promoted_vehicle_state(world, player) -> Dictionary:
	var snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	var candidate := {}
	for state_variant in snapshot.get("tier1_states", []):
		candidate = state_variant
		break
	if candidate.is_empty():
		var fallback_states := _collect_states(snapshot)
		if not fallback_states.is_empty():
			candidate = fallback_states[0]
	if candidate.is_empty():
		return {}
	var candidate_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
	player.teleport_to_world_position(candidate_position + Vector3(-6.0, 0.0, -6.0))
	var promoted_snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	return _find_state(promoted_snapshot, str(candidate.get("vehicle_id", "")))

func _refresh_vehicle_snapshot(world, anchor_world_position: Vector3) -> Dictionary:
	for _step_index in range(4):
		world.update_streaming_for_position(anchor_world_position, 0.25)
		await process_frame
	return world.get_vehicle_runtime_snapshot()

func _resolve_vehicle_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.6))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)

func _resolve_hijack_stand_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	var lateral := Vector3(-heading.z, 0.0, heading.x).normalized()
	return world_position + lateral * 2.2

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _find_state(snapshot: Dictionary, vehicle_id: String) -> Dictionary:
	for state_variant in _collect_states(snapshot):
		var state: Dictionary = state_variant
		if str(state.get("vehicle_id", "")) == vehicle_id:
			return state
	return {}
