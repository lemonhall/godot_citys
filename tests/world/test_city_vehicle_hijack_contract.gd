extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle hijack contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "CityPrototype must expose get_vehicle_runtime_snapshot() for vehicle hijack contract"):
		return
	if not T.require_true(self, world.has_method("resolve_vehicle_projectile_hit"), "CityPrototype must expose resolve_vehicle_projectile_hit() for projectile-based vehicle stop"):
		return
	if not T.require_true(self, world.has_method("find_hijackable_vehicle_candidate"), "CityPrototype must expose find_hijackable_vehicle_candidate() for nearby hijack prompt resolution"):
		return
	if not T.require_true(self, world.has_method("try_hijack_nearby_vehicle"), "CityPrototype must expose try_hijack_nearby_vehicle() for F hijack flow"):
		return
	if not T.require_true(self, world.has_method("is_player_driving_vehicle"), "CityPrototype must expose is_player_driving_vehicle() for hijack contract"):
		return
	if not T.require_true(self, world.has_method("get_player_vehicle_state"), "CityPrototype must expose get_player_vehicle_state() for hijack continuity validation"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle hijack contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for vehicle hijack contract"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_state := await _find_promoted_vehicle_state(world, player)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle hijack contract needs a promoted nearfield traffic vehicle to target"):
		return
	var target_vehicle_id := str(target_state.get("vehicle_id", ""))
	var aim_position: Vector3 = _resolve_vehicle_aim_position(target_state)
	var shot_origin: Vector3 = player.global_position + Vector3.UP * 0.9
	var shot_velocity: Vector3 = (aim_position - shot_origin).normalized() * 180.0

	var hit_result: Dictionary = world.resolve_vehicle_projectile_hit(shot_origin, aim_position, 1.0, shot_velocity)
	if not T.require_true(self, str(hit_result.get("vehicle_id", "")) == target_vehicle_id, "Projectile resolver must stop the selected nearfield vehicle instead of returning no hit or the wrong target"):
		return

	var stopped_snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	var stopped_state := _find_state(stopped_snapshot, target_vehicle_id)
	if not T.require_true(self, not stopped_state.is_empty(), "Stopped vehicle must remain queryable in runtime snapshot before hijack"):
		return
	if not T.require_true(self, str(stopped_state.get("interaction_state", "")) == "stopped", "Projectile hit must move the target vehicle into stopped interaction_state"):
		return

	var stopped_position: Vector3 = stopped_state.get("world_position", Vector3.ZERO)
	for _frame_index in range(18):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
	var settled_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
	var settled_state := _find_state(settled_snapshot, target_vehicle_id)
	if not T.require_true(self, not settled_state.is_empty(), "Stopped target must remain present until hijacked"):
		return
	if not T.require_true(self, stopped_position.distance_to(settled_state.get("world_position", Vector3.ZERO)) <= 0.5, "Stopped vehicle must stop advancing along its lane after projectile hit"):
		return
	player.teleport_to_world_position(_resolve_hijack_stand_position(settled_state))
	await _refresh_vehicle_snapshot(world, player.global_position)

	var hijack_candidate: Dictionary = world.find_hijackable_vehicle_candidate()
	if not T.require_true(self, str(hijack_candidate.get("vehicle_id", "")) == target_vehicle_id, "Nearby hijack prompt must resolve to the stopped target vehicle"):
		return

	var hijack_result: Dictionary = world.try_hijack_nearby_vehicle()
	if not T.require_true(self, str(hijack_result.get("vehicle_id", "")) == target_vehicle_id, "Hijack flow must claim the stopped target vehicle when player is within range"):
		return
	if not T.require_true(self, bool(hijack_result.get("success", false)), "Hijack result must explicitly report success"):
		return

	var post_hijack_snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	if not T.require_true(self, not _snapshot_contains_vehicle(post_hijack_snapshot, target_vehicle_id), "Claimed vehicle must disappear from ambient traffic snapshot after hijack"):
		return
	if not T.require_true(self, world.is_player_driving_vehicle(), "Player must enter driving mode immediately after hijack"):
		return

	var player_vehicle_state: Dictionary = world.get_player_vehicle_state()
	if not T.require_true(self, str(player_vehicle_state.get("vehicle_id", "")) == target_vehicle_id, "Player vehicle continuity must keep the original vehicle_id after hijack"):
		return
	if not T.require_true(self, str(player_vehicle_state.get("model_id", "")) == str(hijack_result.get("model_id", "")), "Player vehicle continuity must keep the original model_id after hijack"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_promoted_vehicle_state(world, player) -> Dictionary:
	var snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	var tier1_states: Array = snapshot.get("tier1_states", [])
	var budget_contract: Dictionary = snapshot.get("budget_contract", {})
	var tier2_radius_m := float(budget_contract.get("tier2_radius_m", 120.0))
	var candidate := {}
	for state_variant in tier1_states:
		var state: Dictionary = state_variant
		if player.global_position.distance_to(state.get("world_position", Vector3.ZERO)) > tier2_radius_m + 8.0:
			candidate = state
			break
	if candidate.is_empty() and not tier1_states.is_empty():
		candidate = tier1_states[0]
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

func _snapshot_contains_vehicle(snapshot: Dictionary, vehicle_id: String) -> bool:
	return not _find_state(snapshot, vehicle_id).is_empty()
