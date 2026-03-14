extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const REACTIVE_MIN_DISTANCE_M := 220.0
const REACTIVE_MAX_DISTANCE_M := 380.0
const CALM_MIN_DISTANCE_M := 420.0
const ORIGIN_CLEARANCE_M := 24.0
const SEARCH_POSITIONS := [
	Vector3(-1200.0, 0.0, 26.0),
	Vector3(-900.0, 0.0, 26.0),
	Vector3(-600.0, 0.0, 26.0),
	Vector3(-300.0, 0.0, 26.0),
	Vector3(300.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
	Vector3(1536.0, 0.0, 26.0),
	Vector3(2048.0, 0.0, 768.0),
	Vector3.ZERO,
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var cluster := _find_distance_ring(streamer, controller)
	if not T.require_true(self, not cluster.is_empty(), "Layered threat runtime test requires a sampled witness in the 220m-380m ring plus a calm outsider beyond 420m"):
		return

	var origin_position: Vector3 = cluster.get("origin_position", Vector3.ZERO)
	streamer.update_for_world_position(origin_position)
	controller.set_player_context(origin_position, Vector3.ZERO)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin_position, 0.25)
	controller.notify_projectile_event(origin_position, Vector3.RIGHT, 36.0)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin_position, 0.1)

	var reactive_state := controller.get_state_snapshot(str(cluster.get("reactive_id", "")))
	var far_state := controller.get_state_snapshot(str(cluster.get("far_id", "")))
	var profile: Dictionary = controller.get_global_summary().get("profile_stats", {})
	print("CITY_PEDESTRIAN_LAYERED_THREAT_RUNTIME %s" % JSON.stringify({
		"cluster": cluster,
		"reactive": reactive_state,
		"far": far_state,
		"profile": profile,
	}))

	if not T.require_true(self, ["panic", "flee"].has(str(reactive_state.get("reaction_state", ""))), "Midfield threat witness must still escalate into panic/flee"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))), "Farfield outsider must stay calm under layered threat routing"):
		return
	if not T.require_true(self, profile.has("crowd_threat_broadcast_usec"), "Layered threat runtime must expose threat broadcast cost"):
		return
	if not T.require_true(self, profile.has("crowd_threat_candidate_count"), "Layered threat runtime must expose threat candidate count"):
		return
	if not T.require_true(self, int(profile.get("crowd_threat_broadcast_usec", 0)) > 0, "Layered threat runtime must measure non-zero threat broadcast cost when a gunshot occurs"):
		return
	if not T.require_true(self, int(profile.get("crowd_threat_candidate_count", 0)) < int(profile.get("crowd_active_state_count", 0)), "Layered threat runtime must not route gunshot threats through every active pedestrian"):
		return

	T.pass_and_quit(self)

func _find_distance_ring(streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, 0.25)
		var cluster := _pick_distance_ring(controller.get_global_snapshot(), search_position)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_distance_ring(snapshot: Dictionary, origin_position: Vector3) -> Dictionary:
	var states := _collect_states(snapshot)
	if _nearest_distance_to_states(states, origin_position) <= ORIGIN_CLEARANCE_M:
		return {}
	var reactive_candidate := {}
	var far_candidate := {}
	for state_variant in states:
		var state: Dictionary = state_variant
		var distance_m := origin_position.distance_to(state.get("world_position", Vector3.ZERO))
		if reactive_candidate.is_empty() and distance_m >= REACTIVE_MIN_DISTANCE_M and distance_m <= REACTIVE_MAX_DISTANCE_M and _is_expected_mid_ring_responder(state):
			reactive_candidate = state
		elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
			far_candidate = state
		if not reactive_candidate.is_empty() and not far_candidate.is_empty():
			break
	if reactive_candidate.is_empty() or far_candidate.is_empty():
		return {}
	return {
		"origin_position": origin_position,
		"reactive_id": str(reactive_candidate.get("pedestrian_id", "")),
		"far_id": str(far_candidate.get("pedestrian_id", "")),
	}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _nearest_distance_to_states(states: Array, world_position: Vector3) -> float:
	var best_distance := INF
	for state_variant in states:
		var state: Dictionary = state_variant
		best_distance = minf(best_distance, world_position.distance_to(state.get("world_position", Vector3.ZERO)))
	return best_distance

func _is_expected_mid_ring_responder(state: Dictionary) -> bool:
	return posmod(int(state.get("seed", 0)), 10) < 4
