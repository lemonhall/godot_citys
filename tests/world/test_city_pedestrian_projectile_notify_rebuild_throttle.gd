extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const REACTIVE_MIN_DISTANCE_M := 220.0
const REACTIVE_MAX_DISTANCE_M := 380.0
const ORIGIN_CLEARANCE_M := 24.0
const FRAME_DELTA := 1.0 / 60.0
const SEARCH_POSITIONS := [
	Vector3(-1280.0, 0.0, -1024.0),
	Vector3(-2048.0, 0.0, 0.0),
	Vector3(-2048.0, 0.0, -768.0),
	Vector3(-1792.0, 0.0, -768.0),
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
	if not T.require_true(self, not cluster.is_empty(), "Projectile notify rebuild throttle test needs a stable witness ring between 220m and 380m"):
		return

	var origin_position: Vector3 = cluster.get("origin_position", Vector3.ZERO)
	streamer.update_for_world_position(origin_position)
	controller.set_player_context(origin_position, Vector3.ZERO)
	var active_entries: Array = streamer.get_active_chunk_entries()
	controller.update_active_chunks(active_entries, origin_position, 0.25)

	controller.notify_projectile_event(origin_position, Vector3.RIGHT, 36.0)
	var first_summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var first_profile: Dictionary = first_summary.get("profile_stats", {})
	if not T.require_true(self, int(first_profile.get("crowd_assignment_candidate_count", 0)) > 0, "First projectile notify must expand into a reactive crowd assignment set for this sampled cluster"):
		return
	if not T.require_true(self, str(first_profile.get("crowd_assignment_rebuild_reason", "")) == "forced", "First projectile notify should still force an immediate reactive rebuild"):
		return

	controller.notify_projectile_event(origin_position + Vector3(0.16, 0.0, 0.04), Vector3.RIGHT, 36.0)
	var second_summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var second_profile: Dictionary = second_summary.get("profile_stats", {})

	for _frame_index in range(12):
		controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	controller.notify_projectile_event(origin_position + Vector3(0.28, 0.0, -0.06), Vector3.RIGHT, 36.0)
	var third_summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var third_profile: Dictionary = third_summary.get("profile_stats", {})

	print("CITY_PEDESTRIAN_PROJECTILE_NOTIFY_REBUILD_THROTTLE %s" % JSON.stringify({
		"cluster": cluster,
		"first_profile": first_profile,
		"second_profile": second_profile,
		"third_profile": third_profile,
		"runtime_summary": controller.get_runtime_summary(),
	}))

	if not T.require_true(self, str(second_profile.get("crowd_assignment_rebuild_reason", "")) != "forced", "Burst-fire follow-up projectile notifies should reuse the recent reactive assignment instead of forcing another rebuild on the very next frame"):
		return
	if not T.require_true(self, int(controller.get_runtime_summary().get("reactive_event_count", 0)) > 0, "Burst-fire throttle must keep reactive events alive while reusing the recent assignment window"):
		return
	if not T.require_true(self, str(third_profile.get("crowd_assignment_rebuild_reason", "")) == "forced", "Projectile notify cadence must still allow a later forced rebuild after the burst-fire throttle window elapses"):
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
	for state_variant in states:
		var state: Dictionary = state_variant
		var distance_m := origin_position.distance_to(state.get("world_position", Vector3.ZERO))
		if distance_m < REACTIVE_MIN_DISTANCE_M or distance_m > REACTIVE_MAX_DISTANCE_M:
			continue
		return {
			"origin_position": origin_position,
			"reactive_id": str(state.get("pedestrian_id", "")),
			"reactive_distance_m": distance_m,
		}
	return {}

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
