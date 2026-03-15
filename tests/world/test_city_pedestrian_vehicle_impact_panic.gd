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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle impact panic contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("resolve_player_vehicle_pedestrian_impact"), "CityPrototype must expose resolve_player_vehicle_pedestrian_impact() for vehicle impact panic contract"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for vehicle impact panic contract"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Vehicle impact panic contract requires player teleport support"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "Vehicle impact panic contract requires drive-mode entry support"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "Vehicle impact panic contract requires drive input override support"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var setup := await _prepare_drive_cluster_setup(world, player)
	if not T.require_true(self, not setup.is_empty(), "Vehicle impact panic contract needs a synthetic driving setup with a nearby witness cluster and a calm outsider"):
		return

	var target_id := str(setup.get("target_id", ""))
	var drive_offset: Vector3 = player.global_position - (world.get_player_vehicle_state().get("world_position", player.global_position) as Vector3)
	var target_state := _find_pedestrian_state(world.get_pedestrian_runtime_snapshot(), target_id)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle impact panic contract must keep the selected casualty target active before collision"):
		return

	var approach_position: Vector3 = target_state.get("world_position", Vector3.ZERO) - setup.get("vehicle_heading", Vector3.FORWARD) * 7.0
	player.teleport_to_world_position(approach_position + drive_offset)
	await _refresh_world(world, player.global_position, 4, 1.0 / 60.0)

	player.set_vehicle_drive_input(1.0, 0.0, false)
	var impact_result := {}
	for _frame_index in range(90):
		await physics_frame
		await process_frame
		impact_result = world.resolve_player_vehicle_pedestrian_impact()
		if not impact_result.is_empty():
			break
	player.clear_vehicle_drive_input()

	if not T.require_true(self, not impact_result.is_empty(), "Vehicle impact panic contract must resolve a live pedestrian collision while driving"):
		return
	if not T.require_true(self, str(impact_result.get("pedestrian_id", "")) == target_id, "Vehicle impact panic contract must kill the intended collision victim"):
		return

	var candidate_count := int(impact_result.get("panic_candidate_count", 0))
	var responder_count := int(impact_result.get("panic_responder_count", 0))
	if not T.require_true(self, candidate_count >= 3, "Vehicle impact panic contract needs at least three nearby nearfield witnesses so the 60% response rule is meaningful"):
		return
	if not T.require_true(self, responder_count == int(round(float(candidate_count) * 0.6)), "Vehicle impact panic contract must deterministically react with 60% of nearby nearfield witnesses instead of falling back to all-or-none panic"):
		return
	if not T.require_true(self, responder_count < candidate_count, "Vehicle impact panic contract must keep at least one nearby witness calm instead of forcing every candidate to flee"):
		return

	await _refresh_world(world, player.global_position, 6, 1.0 / 60.0)
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	for responder_id_variant in impact_result.get("panic_responder_ids", []):
		var responder_state := _find_pedestrian_state(snapshot, str(responder_id_variant))
		if not T.require_true(self, ["panic", "flee"].has(str(responder_state.get("reaction_state", ""))), "Vehicle impact responders must enter panic-or-flee after the collision"):
			return
	var calm_witness_id := str(impact_result.get("calm_witness_id", ""))
	if not T.require_true(self, calm_witness_id != "", "Vehicle impact panic contract must report one non-responder calm witness inside the sampled nearfield ring"):
		return
	var calm_witness_state := _find_pedestrian_state(snapshot, calm_witness_id)
	if not T.require_true(self, str(calm_witness_state.get("reaction_state", "none")) == "none", "Vehicle impact calm witness must stay ambient instead of inheriting gunshot-grade panic"):
		return
	var far_outsider_state := _find_pedestrian_state(snapshot, str(setup.get("far_id", "")))
	if not T.require_true(self, str(far_outsider_state.get("reaction_state", "none")) == "none", "Vehicle impact panic radius must stay local; the sampled outsider beyond the ring must remain calm"):
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
			"vehicle_id": "veh:test:impact_panic",
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
