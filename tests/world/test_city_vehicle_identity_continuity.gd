extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")

const CONTROLLER_PATH := "res://city_game/world/vehicles/simulation/CityVehicleTierController.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller_script := load(CONTROLLER_PATH)
	if not T.require_true(self, controller_script != null, "Vehicle tier controller script must exist for identity continuity validation"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller = controller_script.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_state_snapshot"), "Vehicle tier controller must expose get_state_snapshot() for identity continuity validation"):
		return
	if not T.require_true(self, controller.has_method("get_runtime_snapshot"), "Vehicle tier controller must expose get_runtime_snapshot() for identity continuity validation"):
		return
	if not T.require_true(self, controller.has_method("get_budget_contract"), "Vehicle tier controller must expose get_budget_contract() for identity continuity validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)

	var initial_runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	var tier1_states: Array = initial_runtime_snapshot.get("tier1_states", [])
	if not T.require_true(self, not tier1_states.is_empty(), "Identity continuity test requires at least one Tier 1 vehicle state"):
		return

	var budget_contract: Dictionary = controller.get_budget_contract()
	var tier2_radius_m := float(budget_contract.get("tier2_radius_m", 120.0))
	var promoted_candidate: Dictionary = tier1_states[0]
	for candidate_variant in tier1_states:
		var candidate: Dictionary = candidate_variant
		var candidate_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
		if origin.distance_to(candidate_position) > tier2_radius_m + 8.0:
			promoted_candidate = candidate
			break
	var vehicle_id := str(promoted_candidate.get("vehicle_id", ""))
	var target_world_position: Vector3 = promoted_candidate.get("world_position", Vector3.ZERO)
	var initial_state_snapshot: Dictionary = controller.get_state_snapshot(vehicle_id)
	if not T.require_true(self, str(initial_state_snapshot.get("tier", "")) == "tier1", "Selected continuity candidate must begin in Tier 1"):
		return

	streamer.update_for_world_position(target_world_position)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), target_world_position, 0.25)
	var promoted_state_snapshot: Dictionary = controller.get_state_snapshot(vehicle_id)
	if not T.require_true(self, str(promoted_state_snapshot.get("tier", "")) == "tier3", "Approaching the candidate must promote it into Tier 3 nearfield once vehicle runtime takes over"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("vehicle_id", "")) == vehicle_id, "Vehicle ID must remain stable after promotion"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("lane_ref_id", "")) == str(initial_state_snapshot.get("lane_ref_id", "")), "Lane ref must remain stable after promotion"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("route_signature", "")) == str(initial_state_snapshot.get("route_signature", "")), "Route signature must remain stable after promotion"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("model_signature", "")) == str(initial_state_snapshot.get("model_signature", "")), "Model signature must remain stable after promotion"):
		return

	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var demoted_state_snapshot: Dictionary = controller.get_state_snapshot(vehicle_id)
	print("CITY_VEHICLE_IDENTITY_CONTINUITY %s" % JSON.stringify(demoted_state_snapshot))

	if not T.require_true(self, str(demoted_state_snapshot.get("tier", "")) == "tier1", "Moving away from the candidate must demote it back into Tier 1 after nearfield is cleared"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("vehicle_id", "")) == vehicle_id, "Vehicle ID must remain stable after demotion"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("lane_ref_id", "")) == str(initial_state_snapshot.get("lane_ref_id", "")), "Lane ref must remain stable after demotion"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("route_signature", "")) == str(initial_state_snapshot.get("route_signature", "")), "Route signature must remain stable after demotion"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("model_signature", "")) == str(initial_state_snapshot.get("model_signature", "")), "Model signature must remain stable after demotion"):
		return

	T.pass_and_quit(self)
