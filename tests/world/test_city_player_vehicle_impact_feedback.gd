extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SEARCH_POSITIONS := [
	Vector3(-1280.0, 1.1, -1024.0),
	Vector3(-2048.0, 1.1, 0.0),
	Vector3(-1200.0, 1.1, 26.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3(300.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3.ZERO,
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player vehicle impact feedback contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("resolve_player_vehicle_pedestrian_impact"), "CityPrototype must expose resolve_player_vehicle_pedestrian_impact() for vehicle impact feedback contract"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for vehicle impact feedback contract"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "CityPrototype must expose get_chunk_renderer() for vehicle impact feedback contract"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle impact feedback contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for vehicle impact feedback setup"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "PlayerController must expose enter_vehicle_drive_mode() for vehicle impact feedback setup"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "PlayerController must expose set_vehicle_drive_input() for vehicle impact feedback contract"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "PlayerController must expose clear_vehicle_drive_input() for vehicle impact feedback contract"):
		return
	if not T.require_true(self, player.has_method("get_traversal_fx_state"), "PlayerController must expose get_traversal_fx_state() for vehicle impact feedback contract"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var setup := await _prepare_drive_setup(world, player)
	if not T.require_true(self, not setup.is_empty(), "Vehicle impact feedback contract needs a synthetic driving target setup"):
		return

	var target_id := str(setup.get("target_id", ""))
	var target_state := _find_pedestrian_state(world.get_pedestrian_runtime_snapshot(), target_id)
	if not T.require_true(self, not target_state.is_empty(), "Vehicle impact feedback contract must keep the selected target live before impact"):
		return

	var drive_offset: Vector3 = player.global_position - (world.get_player_vehicle_state().get("world_position", player.global_position) as Vector3)
	var vehicle_heading: Vector3 = setup.get("vehicle_heading", Vector3.FORWARD)
	var approach_position: Vector3 = target_state.get("world_position", Vector3.ZERO) - vehicle_heading * 7.0
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

	if not T.require_true(self, not impact_result.is_empty(), "Vehicle impact feedback contract must resolve a real driving collision"):
		return

	var fx_state: Dictionary = player.get_traversal_fx_state()
	if not T.require_true(self, float(fx_state.get("camera_shake_remaining_sec", 0.0)) > 0.0, "Vehicle impact feedback must trigger a visible camera shake instead of feeling weightless"):
		return
	if not T.require_true(self, float(fx_state.get("camera_shake_amplitude_m", 0.0)) >= 0.12, "Vehicle impact feedback must shake the camera by a visible amount instead of a near-zero placeholder twitch"):
		return

	var death_visual := _find_death_visual_for_pedestrian(world.get_chunk_renderer(), str(impact_result.get("chunk_id", "")), target_id)
	if not T.require_true(self, death_visual != null, "Vehicle impact feedback contract must spawn a death visual for the casualty"):
		return

	var live_visual := _find_live_nearfield_visual_for_pedestrian(world.get_chunk_renderer(), str(impact_result.get("chunk_id", "")), target_id)
	if not T.require_true(self, live_visual == null, "Vehicle impact feedback must not leave the casualty's nearfield live visual embedded in the car during the same-frame death launch"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _prepare_drive_setup(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		await _refresh_world(world, search_position, 6, 0.25)
		var pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var target_state := _pick_target_pedestrian(pedestrian_snapshot)
		if target_state.is_empty():
			continue
		var target_position: Vector3 = target_state.get("world_position", Vector3.ZERO)
		var target_heading := Vector3(1.0, 0.0, 0.0)
		var synthetic_vehicle_state := {
			"vehicle_id": "veh:test:impact_feedback",
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
			"target_id": str(target_state.get("pedestrian_id", "")),
			"vehicle_heading": target_heading,
		}
	return {}

func _pick_target_pedestrian(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier3_states", "tier2_states"]:
		for state_variant in snapshot.get(tier_key, []):
			return state_variant
	return {}

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
		var chunk_visual := _find_child_with_prefix(chunk_scene.get_node_or_null("PedestrianCrowd/DeathVisuals"), expected_name_prefix)
		if chunk_visual != null:
			return chunk_visual
	return _find_child_with_prefix(chunk_renderer.get_node_or_null("PedestrianDeathVisualsGlobal"), expected_name_prefix)

func _find_live_nearfield_visual_for_pedestrian(chunk_renderer, chunk_id: String, pedestrian_id: String) -> Node:
	if chunk_renderer == null:
		return null
	var chunk_scene = chunk_renderer.get_chunk_scene(chunk_id) if chunk_renderer.has_method("get_chunk_scene") else null
	if chunk_scene == null:
		return null
	var normalized_name := pedestrian_id.replace(":", "_")
	var tier2_root: Node = chunk_scene.get_node_or_null("PedestrianCrowd/Tier2Agents")
	var tier3_root: Node = chunk_scene.get_node_or_null("PedestrianCrowd/Tier3Agents")
	var tier2_node: Node = tier2_root.get_node_or_null(normalized_name) if tier2_root != null else null
	if tier2_node != null:
		return tier2_node
	var tier3_node: Node = tier3_root.get_node_or_null(normalized_name) if tier3_root != null else null
	return tier3_node

func _find_child_with_prefix(root_node: Node, expected_name_prefix: String) -> Node:
	if root_node == null:
		return null
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node.name.begins_with(expected_name_prefix):
			return child_node
	return null
