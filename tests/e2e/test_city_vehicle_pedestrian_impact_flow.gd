extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SEARCH_POSITIONS := [
	Vector3(-1280.0, 1.1, -1024.0),
	Vector3(-2048.0, 1.1, 0.0),
	Vector3(-2048.0, 1.1, -768.0),
	Vector3(-1792.0, 1.1, -768.0),
	Vector3(-2048.0, 1.1, -512.0),
	Vector3(-1200.0, 1.1, 26.0),
	Vector3(-900.0, 1.1, 26.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3(-300.0, 1.1, 26.0),
	Vector3(300.0, 1.1, 26.0),
	Vector3(600.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1024.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(1792.0, 1.1, 512.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3(2304.0, 1.1, 896.0),
	Vector3.ZERO,
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle pedestrian impact flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("resolve_player_vehicle_pedestrian_impact"), "Vehicle pedestrian impact flow requires CityPrototype.resolve_player_vehicle_pedestrian_impact()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Vehicle pedestrian impact flow requires CityPrototype.get_pedestrian_runtime_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Vehicle pedestrian impact flow requires CityPrototype.get_chunk_renderer()"):
		return
	if not T.require_true(self, world.has_method("handle_vehicle_interaction"), "Vehicle pedestrian impact flow requires CityPrototype.handle_vehicle_interaction()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle pedestrian impact flow requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Vehicle pedestrian impact flow requires teleport support"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "Vehicle pedestrian impact flow requires synthetic drive-mode entry support"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "Vehicle pedestrian impact flow requires drive input override support"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "Vehicle pedestrian impact flow requires drive input reset support"):
		return
	if not T.require_true(self, player.has_method("is_driving_vehicle"), "Vehicle pedestrian impact flow requires drive-state introspection"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var setup := await _prepare_drive_cluster_setup(world, player)
	if not T.require_true(self, not setup.is_empty(), "Vehicle pedestrian impact flow needs a synthetic driving setup with local witnesses and a calm outsider"):
		return

	var target_id := str(setup.get("target_id", ""))
	var target_state := _find_pedestrian_state(world.get_pedestrian_runtime_snapshot(), target_id)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle pedestrian impact flow must keep the selected casualty target live before auto-impact"):
		return

	var drive_offset: Vector3 = player.global_position - (world.get_player_vehicle_state().get("world_position", player.global_position) as Vector3)
	var vehicle_heading: Vector3 = setup.get("vehicle_heading", Vector3.FORWARD)
	var approach_position: Vector3 = target_state.get("world_position", Vector3.ZERO) - vehicle_heading * 7.0
	player.teleport_to_world_position(approach_position + drive_offset)
	await _refresh_world(world, player.global_position, 4, 1.0 / 60.0)

	player.set_vehicle_drive_input(1.0, 0.0, false)
	var target_removed := false
	for _frame_index in range(90):
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await physics_frame
		await process_frame
		target_removed = _find_pedestrian_state(world.get_pedestrian_runtime_snapshot(), target_id).is_empty()
		if target_removed:
			break
	player.clear_vehicle_drive_input()

	var impact_result: Dictionary = world.resolve_player_vehicle_pedestrian_impact()
	if not T.require_true(self, not impact_result.is_empty(), "Vehicle pedestrian impact flow must auto-resolve the collision through CityPrototype._process() without needing a manual per-frame resolver call"):
		return
	if not T.require_true(self, target_removed, "Vehicle pedestrian impact flow must remove the casualty from the live snapshot once the auto-impact resolves"):
		return
	if not T.require_true(self, str(impact_result.get("pedestrian_id", "")) == target_id, "Vehicle pedestrian impact flow must preserve the intended casualty id through the cached auto-impact result"):
		return
	if not T.require_true(self, float(impact_result.get("vehicle_speed_after_mps", 99.0)) < 10.0, "Vehicle pedestrian impact flow must still drag the hijacked car down to single digits after the hit"):
		return

	var death_visual := _find_death_visual_for_pedestrian(world.get_chunk_renderer(), str(impact_result.get("chunk_id", "")), target_id)
	if not T.require_true(self, death_visual != null, "Vehicle pedestrian impact flow must leave a death visual behind the auto-resolved casualty"):
		return
	if not T.require_true(self, death_visual.has_method("get_current_animation_name"), "Vehicle pedestrian impact flow needs death visual animation introspection"):
		return
	if not T.require_true(self, _has_any_token(str(death_visual.call("get_current_animation_name")), ["death", "dead"]), "Vehicle pedestrian impact flow must keep the launched casualty on a death/dead clip"):
		return

	var candidate_count := int(impact_result.get("panic_candidate_count", 0))
	var responder_count := int(impact_result.get("panic_responder_count", 0))
	if not T.require_true(self, candidate_count >= 1, "Vehicle pedestrian impact flow must still trigger a local nearfield panic slice instead of collapsing into a no-witness auto-impact"):
		return
	var expected_responder_count := int(round(float(candidate_count) * 0.6))
	if candidate_count > 0:
		expected_responder_count = clampi(expected_responder_count, 1, candidate_count)
	if not T.require_true(self, responder_count == expected_responder_count, "Vehicle pedestrian impact flow must keep the local panic response ratio formula in the cached auto-impact result"):
		return

	await _refresh_world(world, player.global_position, 6, 1.0 / 60.0)
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	for responder_id_variant in impact_result.get("panic_responder_ids", []):
		var responder_state := _find_pedestrian_state(snapshot, str(responder_id_variant))
		if not T.require_true(self, ["panic", "flee"].has(str(responder_state.get("reaction_state", ""))), "Vehicle pedestrian impact flow must push chosen nearfield witnesses into panic-or-flee after the auto-impact"):
			return
	if candidate_count > responder_count:
		var calm_witness_state := _find_pedestrian_state(snapshot, str(impact_result.get("calm_witness_id", "")))
		if not T.require_true(self, str(calm_witness_state.get("reaction_state", "none")) == "none", "Vehicle pedestrian impact flow must keep at least one sampled local witness calm when the response ratio leaves spare candidates"):
			return
	var far_outsider_state := _find_pedestrian_state(snapshot, str(setup.get("far_id", "")))
	if not T.require_true(self, str(far_outsider_state.get("reaction_state", "none")) == "none", "Vehicle pedestrian impact flow must keep the sampled outsider beyond the local ring calm"):
		return

	var exit_result: Dictionary = world.handle_vehicle_interaction()
	if not T.require_true(self, bool(exit_result.get("success", false)), "Vehicle pedestrian impact flow must still allow the player to exit after the auto-impact"):
		return
	if not T.require_true(self, not player.is_driving_vehicle(), "Vehicle pedestrian impact flow must leave driving mode after the exit interaction"):
		return
	if not T.require_true(self, world.resolve_player_vehicle_pedestrian_impact().is_empty(), "Vehicle pedestrian impact flow must not let empty parked vehicles or ambient traffic keep killing pedestrians after exit"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _prepare_drive_cluster_setup(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		await _refresh_world(world, search_position, 6, 0.25)
		var pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_cluster(pedestrian_snapshot)
		if cluster.is_empty():
			continue
		var target_state := _find_pedestrian_state(pedestrian_snapshot, str(cluster.get("target_id", "")))
		if target_state.is_empty():
			continue
		var target_position: Vector3 = target_state.get("world_position", Vector3.ZERO)
		var target_heading := Vector3(1.0, 0.0, 0.0)
		var synthetic_vehicle_state := {
			"vehicle_id": "veh:test:impact_flow",
			"model_id": "car_b",
			"heading": target_heading,
			"world_position": target_position - target_heading * 7.0,
			"length_m": 4.4,
			"width_m": 1.9,
			"height_m": 1.6,
			"speed_mps": 0.0,
		}
		player.enter_vehicle_drive_mode(synthetic_vehicle_state)
		await _refresh_world(world, player.global_position, 2, 1.0 / 60.0)
		return {
			"target_id": str(cluster.get("target_id", "")),
			"far_id": str(cluster.get("far_id", "")),
			"vehicle_heading": target_heading,
		}
	return {}

func _pick_cluster(snapshot: Dictionary) -> Dictionary:
	var states: Array = _collect_states(snapshot)
	for state_variant in states:
		var target: Dictionary = state_variant
		var target_id := str(target.get("pedestrian_id", ""))
		var target_position: Vector3 = target.get("world_position", Vector3.ZERO)
		var witness_ids: Array[String] = []
		var far_id := ""
		for other_variant in states:
			var other: Dictionary = other_variant
			var other_id := str(other.get("pedestrian_id", ""))
			if other_id == target_id:
				continue
			var distance_m := target_position.distance_to(other.get("world_position", Vector3.ZERO))
			if ["tier2", "tier3"].has(str(other.get("tier", ""))) and distance_m >= 2.5 and distance_m <= 16.0:
				witness_ids.append(other_id)
			elif far_id == "" and distance_m >= 18.0:
				far_id = other_id
		if witness_ids.size() >= 3 and far_id != "":
			return {
				"target_id": target_id,
				"far_id": far_id,
			}
	return {}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _refresh_world(world, anchor_world_position: Vector3, step_count: int, delta: float) -> void:
	for _step_index in range(step_count):
		world.update_streaming_for_position(anchor_world_position, delta)
		await process_frame

func _find_pedestrian_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}

func _find_death_visual_for_pedestrian(chunk_renderer, chunk_id: String, pedestrian_id: String) -> Node:
	if chunk_renderer == null:
		return null
	var expected_name_prefix := pedestrian_id.replace(":", "_")
	var chunk_scene = chunk_renderer.get_chunk_scene(chunk_id) if chunk_renderer.has_method("get_chunk_scene") else null
	if chunk_scene != null:
		var chunk_visual := _find_death_visual_in_root(chunk_scene.get_node_or_null("PedestrianCrowd/DeathVisuals"), expected_name_prefix)
		if chunk_visual != null:
			return chunk_visual
	return _find_death_visual_in_root(chunk_renderer.get_node_or_null("PedestrianDeathVisualsGlobal"), expected_name_prefix)

func _find_death_visual_in_root(root_node: Node, expected_name_prefix: String) -> Node:
	if root_node == null:
		return null
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node.name.begins_with(expected_name_prefix):
			return child_node
	return null

func _has_any_token(animation_name: String, tokens: Array[String]) -> bool:
	var normalized_animation := animation_name.to_lower()
	for token in tokens:
		if normalized_animation.find(token) >= 0:
			return true
	return false
