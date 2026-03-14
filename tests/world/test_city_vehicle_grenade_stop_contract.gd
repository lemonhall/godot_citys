extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GRENADE_STOP_RADIUS_M := 8.5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle grenade stop contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "CityPrototype must expose get_vehicle_runtime_snapshot() for vehicle grenade stop contract"):
		return
	if not T.require_true(self, world.has_method("resolve_vehicle_explosion"), "CityPrototype must expose resolve_vehicle_explosion() for grenade-based vehicle stop"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle grenade stop contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for grenade stop contract"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_state := await _find_promoted_vehicle_state(world, player)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle grenade stop contract needs a promoted nearfield vehicle"):
		return

	var target_vehicle_id := str(target_state.get("vehicle_id", ""))
	var target_position: Vector3 = target_state.get("world_position", Vector3.ZERO)
	var baseline_snapshot: Dictionary = world.get_vehicle_runtime_snapshot()
	var far_state := _find_far_vehicle_state(baseline_snapshot, target_vehicle_id, target_position, GRENADE_STOP_RADIUS_M + 14.0)
	if not T.require_true(self, not far_state.is_empty(), "Vehicle grenade stop contract requires a second traffic vehicle outside the blast radius to prove no global freeze"):
		return

	var explosion_result: Dictionary = world.resolve_vehicle_explosion(target_position, GRENADE_STOP_RADIUS_M)
	if not T.require_true(self, int(explosion_result.get("stopped_count", 0)) >= 1, "Grenade resolver must report at least one stopped traffic vehicle inside the blast radius"):
		return

	var post_snapshot := await _refresh_vehicle_snapshot(world, player.global_position)
	var stopped_state := _find_state(post_snapshot, target_vehicle_id)
	if not T.require_true(self, not stopped_state.is_empty(), "Grenade-stopped vehicle must remain queryable after explosion"):
		return
	if not T.require_true(self, str(stopped_state.get("interaction_state", "")) == "stopped", "Grenade explosion must move the target vehicle into stopped interaction_state"):
		return

	var far_post_state := _find_state(post_snapshot, str(far_state.get("vehicle_id", "")))
	if not T.require_true(self, not far_post_state.is_empty(), "Far traffic vehicle outside the blast radius must remain queryable"):
		return
	if not T.require_true(self, str(far_post_state.get("interaction_state", "")) != "stopped", "Grenade stop flow must not globally freeze unrelated traffic vehicles outside the blast radius"):
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

func _find_far_vehicle_state(snapshot: Dictionary, excluded_vehicle_id: String, origin: Vector3, min_distance_m: float) -> Dictionary:
	for state_variant in _collect_states(snapshot):
		var state: Dictionary = state_variant
		if str(state.get("vehicle_id", "")) == excluded_vehicle_id:
			continue
		if origin.distance_to(state.get("world_position", Vector3.ZERO)) >= min_distance_m:
			return state
	return {}

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
