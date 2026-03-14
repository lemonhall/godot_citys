extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const FRAME_DELTA := 0.25
const SEARCH_POSITIONS := [
	Vector3.ZERO,
	Vector3(-1200.0, 0.0, 26.0),
	Vector3(-900.0, 0.0, 26.0),
	Vector3(-600.0, 0.0, 26.0),
	Vector3(-300.0, 0.0, 26.0),
	Vector3(300.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
	Vector3(1200.0, 0.0, 26.0),
	Vector3(1536.0, 0.0, 26.0),
	Vector3(2048.0, 0.0, 768.0),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var baseline_sample := _find_farfield_release_sample(streamer, controller)
	if not T.require_true(self, not baseline_sample.is_empty(), "Farfield assignment release test requires a farfield-only origin with at least one promotable Tier 1 candidate"):
		return

	var origin_position: Vector3 = baseline_sample.get("origin_position", Vector3.ZERO)
	var candidate_id := str(baseline_sample.get("candidate_id", ""))
	var candidate_position: Vector3 = baseline_sample.get("candidate_position", Vector3.ZERO)

	streamer.update_for_world_position(origin_position)
	var baseline_summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), origin_position, FRAME_DELTA)
	var baseline_profile: Dictionary = baseline_summary.get("profile_stats", {})
	var baseline_state: Dictionary = controller.get_state_snapshot(candidate_id)

	streamer.update_for_world_position(candidate_position)
	var promoted_summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), candidate_position, FRAME_DELTA)
	var promoted_profile: Dictionary = promoted_summary.get("profile_stats", {})
	var promoted_state: Dictionary = controller.get_state_snapshot(candidate_id)

	streamer.update_for_world_position(origin_position)
	var released_summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), origin_position, FRAME_DELTA)
	var released_profile: Dictionary = released_summary.get("profile_stats", {})
	var released_state: Dictionary = controller.get_state_snapshot(candidate_id)

	print("CITY_PEDESTRIAN_FARFIELD_ASSIGNMENT_RELEASE %s" % JSON.stringify({
		"sample": baseline_sample,
		"baseline_summary": baseline_summary,
		"baseline_state": baseline_state,
		"promoted_summary": promoted_summary,
		"promoted_state": promoted_state,
		"released_summary": released_summary,
		"released_state": released_state,
	}))

	if not T.require_true(self, int(baseline_profile.get("crowd_assignment_candidate_count", -1)) == 0, "Farfield release baseline must start with zero assignment candidates"):
		return
	if not T.require_true(self, str(baseline_state.get("tier", "")) == "tier1", "Release candidate must begin as a Tier 1 farfield pedestrian"):
		return
	if not T.require_true(self, int(promoted_profile.get("crowd_assignment_candidate_count", 0)) > 0, "Approaching the candidate must rebuild a non-empty assignment set"):
		return
	if not T.require_true(self, ["tier2", "tier3"].has(str(promoted_state.get("tier", ""))), "Approaching the candidate must promote it into the nearfield assignment set"):
		return
	if not T.require_true(self, int(released_profile.get("crowd_assignment_candidate_count", -1)) == 0, "Returning to the farfield-only origin must release the assignment candidate set back to zero"):
		return
	if not T.require_true(self, int(released_profile.get("crowd_assignment_rebuild_usec", 0)) > 0, "Returning to the farfield-only origin must still report assignment rebuild cost even when the rebuilt candidate set is empty"):
		return
	if not T.require_true(self, int(released_profile.get("crowd_snapshot_rebuild_usec", 0)) > 0, "Returning to the farfield-only origin must rebuild chunk snapshots so stale nearfield assignment state is released"):
		return
	if not T.require_true(self, int(released_summary.get("tier2_count", -1)) == 0 and int(released_summary.get("tier3_count", -1)) == 0, "Release frame must not keep stale nearfield promotions alive after returning to farfield-only origin"):
		return
	if not T.require_true(self, str(released_state.get("tier", "")) == "tier1", "Release candidate must demote back into Tier 1 after assignment release"):
		return

	T.pass_and_quit(self)

func _find_farfield_release_sample(streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		var summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, FRAME_DELTA)
		var profile: Dictionary = summary.get("profile_stats", {})
		if int(summary.get("active_state_count", 0)) <= 0:
			continue
		if int(profile.get("crowd_assignment_candidate_count", 1)) != 0:
			continue
		var snapshot: Dictionary = controller.get_global_snapshot()
		var tier1_states: Array = snapshot.get("tier1_states", [])
		if tier1_states.is_empty():
			continue
		var candidate: Dictionary = tier1_states[0]
		return {
			"origin_position": search_position,
			"candidate_id": str(candidate.get("pedestrian_id", "")),
			"candidate_position": candidate.get("world_position", Vector3.ZERO),
		}
	return {}
