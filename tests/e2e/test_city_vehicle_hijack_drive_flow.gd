extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle hijack drive flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "Vehicle hijack drive flow requires CityPrototype.fire_player_projectile_toward()"):
		return
	if not T.require_true(self, world.has_method("try_hijack_nearby_vehicle"), "Vehicle hijack drive flow requires CityPrototype.try_hijack_nearby_vehicle()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "Vehicle hijack drive flow requires CityPrototype.get_vehicle_runtime_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_player_vehicle_state"), "Vehicle hijack drive flow requires CityPrototype.get_player_vehicle_state()"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle hijack drive flow requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for vehicle hijack drive flow"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "PlayerController must expose set_vehicle_drive_input() for vehicle hijack drive flow"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "PlayerController must expose clear_vehicle_drive_input() for vehicle hijack drive flow"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_state := await _find_promoted_vehicle_state(world, player)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle hijack drive flow needs a promoted nearfield vehicle to target"):
		return
	var target_vehicle_id := str(target_state.get("vehicle_id", ""))
	player.teleport_to_world_position(_resolve_shooter_position(target_state))
	await _refresh_vehicle_snapshot(world, player.global_position)

	var fired_projectile := false
	for _burst_index in range(3):
		var live_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
		var live_target := _find_state(live_snapshot, target_vehicle_id)
		if live_target.is_empty():
			break
		var aim_position: Vector3 = _resolve_vehicle_aim_position(live_target)
		var projectile = world.fire_player_projectile_toward(aim_position)
		if projectile != null:
			fired_projectile = true
		for _frame_index in range(8):
			await physics_frame
			await process_frame
		var refreshed_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
		var refreshed_target := _find_state(refreshed_snapshot, target_vehicle_id)
		if not refreshed_target.is_empty() and str(refreshed_target.get("interaction_state", "")) == "stopped":
			break
	if not T.require_true(self, fired_projectile, "Vehicle hijack drive flow must fire at least one live projectile"):
		return

	var stopped_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
	var stopped_state := _find_state(stopped_snapshot, target_vehicle_id)
	if not T.require_true(self, not stopped_state.is_empty(), "Projectile stop flow must keep the target vehicle queryable before hijack"):
		return
	if not T.require_true(self, str(stopped_state.get("interaction_state", "")) == "stopped", "Live projectile flow must stop the target vehicle before hijack"):
		return
	player.teleport_to_world_position(_resolve_hijack_stand_position(stopped_state))
	await _refresh_vehicle_snapshot(world, player.global_position)

	var hijack_result: Dictionary = world.try_hijack_nearby_vehicle()
	if not T.require_true(self, bool(hijack_result.get("success", false)), "Vehicle hijack drive flow must successfully claim the stopped vehicle"):
		return
	if not T.require_true(self, str(hijack_result.get("vehicle_id", "")) == target_vehicle_id, "Vehicle hijack drive flow must keep the same vehicle_id through the user flow"):
		return

	var baseline_position: Vector3 = player.global_position
	player.set_vehicle_drive_input(1.0, 0.22, false)
	for _frame_index in range(48):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()

	var travelled_distance_m := baseline_position.distance_to(player.global_position)
	if not T.require_true(self, travelled_distance_m >= 6.5, "Vehicle hijack drive flow must let the player drive the hijacked vehicle through the city instead of stalling in place"):
		return

	var player_vehicle_state: Dictionary = world.get_player_vehicle_state()
	if not T.require_true(self, str(player_vehicle_state.get("vehicle_id", "")) == target_vehicle_id, "Player driving state must keep the hijacked vehicle_id after travel"):
		return
	if not T.require_true(self, float(player_vehicle_state.get("speed_mps", 0.0)) > 0.0, "Player driving state must report positive speed during the travel phase"):
		return

	var runtime_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
	if not T.require_true(self, int(runtime_snapshot.get("duplicate_page_load_count", 0)) == 0, "Vehicle hijack drive flow must not introduce duplicate page loads while driving"):
		return
	if not T.require_true(self, not _snapshot_contains_vehicle(runtime_snapshot, target_vehicle_id), "Hijacked vehicle must stay removed from ambient runtime during the drive phase"):
		return

	world.queue_free()
	T.pass_and_quit(self)

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
	return world_position + Vector3.UP * maxf(height_m * 0.9, 1.35)

func _resolve_hijack_stand_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	var lateral := Vector3(-heading.z, 0.0, heading.x).normalized()
	return world_position + lateral * 2.2

func _resolve_shooter_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	var lateral := Vector3(-heading.z, 0.0, heading.x).normalized()
	return world_position - heading.normalized() * 5.0 + lateral * 1.5

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

func _snapshot_contains_vehicle(snapshot: Dictionary, vehicle_id: String) -> bool:
	return not _find_state(snapshot, vehicle_id).is_empty()
