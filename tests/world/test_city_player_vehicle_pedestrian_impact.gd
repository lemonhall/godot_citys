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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player vehicle pedestrian impact contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("resolve_player_vehicle_pedestrian_impact"), "CityPrototype must expose resolve_player_vehicle_pedestrian_impact() for driving impact contract"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for driving impact contract"):
		return
	if not T.require_true(self, world.has_method("handle_vehicle_interaction"), "CityPrototype must expose handle_vehicle_interaction() for driving impact exit guard"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Driving impact contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for driving impact setup"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "PlayerController must expose enter_vehicle_drive_mode() for driving impact setup"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "PlayerController must expose set_vehicle_drive_input() for driving impact contract"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "PlayerController must expose clear_vehicle_drive_input() for driving impact contract"):
		return
	if not T.require_true(self, player.has_method("is_driving_vehicle"), "PlayerController must expose is_driving_vehicle() for driving impact contract"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var setup := await _prepare_drive_setup(world, player)
	if not T.require_true(self, not setup.is_empty(), "Driving impact contract needs a pedestrian target that can be approached in a synthetic driving-mode setup"):
		return

	var target_id := str(setup.get("target_id", ""))
	var drive_offset: Vector3 = player.global_position - (world.get_player_vehicle_state().get("world_position", player.global_position) as Vector3)
	var target_state := _find_pedestrian_state(world.get_pedestrian_runtime_snapshot(), target_id)
	if not T.require_true(self, not target_state.is_empty(), "Driving impact contract must keep the selected pedestrian target active before the collision"):
		return

	var approach_position: Vector3 = target_state.get("world_position", Vector3.ZERO) - setup.get("vehicle_heading", Vector3.FORWARD) * 7.0
	player.teleport_to_world_position(approach_position + drive_offset)
	await _refresh_world(world, player.global_position, 6, 1.0 / 30.0)

	var pre_impact_speed := 0.0
	player.set_vehicle_drive_input(1.0, 0.0, false)
	for _frame_index in range(42):
		await physics_frame
		await process_frame
		var live_state: Dictionary = world.get_player_vehicle_state()
		pre_impact_speed = maxf(pre_impact_speed, float(live_state.get("speed_mps", 0.0)))
	player.clear_vehicle_drive_input()
	if not T.require_true(self, pre_impact_speed >= 14.0, "Driving impact setup must accelerate the synthetic hijacked vehicle to a clearly lethal cruising speed before collision"):
		return

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

	if not T.require_true(self, not impact_result.is_empty(), "Driving impact contract must resolve a real player-vehicle pedestrian collision while the player is driving"):
		return
	if not T.require_true(self, str(impact_result.get("pedestrian_id", "")) == target_id, "Driving impact contract must kill the selected front pedestrian instead of a random bystander"):
		return
	if not T.require_true(self, float(impact_result.get("vehicle_speed_after_mps", 99.0)) < 10.0, "Driving impact must immediately drag the current hijacked vehicle speed down into single digits"):
		return

	await _refresh_world(world, player.global_position, 6, 1.0 / 60.0)
	var post_impact_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	if not T.require_true(self, _find_pedestrian_state(post_impact_snapshot, target_id).is_empty(), "Vehicle impact casualty must leave the live pedestrian snapshot after the hit"):
		return

	var slowed_speed := float(world.get_player_vehicle_state().get("speed_mps", 0.0))
	player.set_vehicle_drive_input(1.0, 0.0, false)
	for _frame_index in range(36):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()
	var resumed_speed := float(world.get_player_vehicle_state().get("speed_mps", 0.0))
	if not T.require_true(self, resumed_speed >= slowed_speed + 4.0, "Driving impact must still let the player re-accelerate and drive away after the slowdown hit"):
		return

	var exit_result: Dictionary = world.handle_vehicle_interaction()
	if not T.require_true(self, bool(exit_result.get("success", false)), "Driving impact contract must still allow the player to exit the vehicle after a collision"):
		return
	if not T.require_true(self, not player.is_driving_vehicle(), "Driving impact exit guard requires the player to actually leave driving mode"):
		return
	if not T.require_true(self, world.resolve_player_vehicle_pedestrian_impact().is_empty(), "Ambient traffic, abandoned vehicles and post-exit empty cars must not keep killing pedestrians once the player is no longer driving"):
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
			"vehicle_id": "veh:test:impact",
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
