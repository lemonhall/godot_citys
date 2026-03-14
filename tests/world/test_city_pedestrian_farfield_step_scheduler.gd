extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const FRAME_DELTA := 1.0 / 60.0
const SAMPLE_FRAMES := 30
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

	var sample := _find_farfield_only_sample(streamer, controller)
	if not T.require_true(self, not sample.is_empty(), "Farfield step scheduler test requires a farfield-only sample with visible Tier 1 pedestrians"):
		return

	var origin_position: Vector3 = sample.get("origin_position", Vector3.ZERO)
	streamer.update_for_world_position(origin_position)
	var active_entries: Array = streamer.get_active_chunk_entries()
	var initial_summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var initial_profile: Dictionary = initial_summary.get("profile_stats", {})
	var previous_progress_by_id := _tier1_progress_by_id(controller.get_global_snapshot().get("tier1_states", []))
	var max_changed_count := 0
	var last_profile := initial_profile.duplicate(true)

	for _frame_index in range(SAMPLE_FRAMES):
		var summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
		var profile: Dictionary = summary.get("profile_stats", {})
		var changed_ids := _collect_changed_tier1_ids(previous_progress_by_id, controller.get_global_snapshot().get("tier1_states", []))
		max_changed_count = maxi(max_changed_count, changed_ids.size())
		previous_progress_by_id = _tier1_progress_by_id(controller.get_global_snapshot().get("tier1_states", []))
		last_profile = profile.duplicate(true)

	print("CITY_PEDESTRIAN_FARFIELD_STEP_SCHEDULER %s" % JSON.stringify({
		"sample": sample,
		"initial_profile": initial_profile,
		"last_profile": last_profile,
		"max_changed_count": max_changed_count,
		"tier1_count": previous_progress_by_id.size(),
	}))

	if not T.require_true(self, int(initial_profile.get("crowd_assignment_candidate_count", -1)) == 0, "Farfield step scheduler baseline must avoid midfield/nearfield candidates"):
		return
	if not T.require_true(self, previous_progress_by_id.size() > 0, "Farfield step scheduler test requires visible Tier 1 pedestrians to observe route progress churn"):
		return
	if not T.require_true(self, max_changed_count < previous_progress_by_id.size(), "Farfield stepping must stay staggered across frames instead of updating the entire Tier 1 farfield set in one burst"):
		return

	T.pass_and_quit(self)

func _find_farfield_only_sample(streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		var summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, FRAME_DELTA)
		var profile: Dictionary = summary.get("profile_stats", {})
		var snapshot: Dictionary = controller.get_global_snapshot()
		var tier1_states: Array = snapshot.get("tier1_states", [])
		if int(summary.get("active_state_count", 0)) <= 0:
			continue
		if int(profile.get("crowd_assignment_candidate_count", 1)) != 0:
			continue
		if tier1_states.is_empty():
			continue
		return {
			"origin_position": search_position,
			"tier1_count": tier1_states.size(),
		}
	return {}

func _tier1_progress_by_id(states: Array) -> Dictionary:
	var progress_by_id: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		progress_by_id[str(state.get("pedestrian_id", ""))] = float(state.get("route_progress", 0.0))
	return progress_by_id

func _collect_changed_tier1_ids(previous_progress_by_id: Dictionary, current_states: Array) -> Array[String]:
	var changed_ids: Array[String] = []
	for state_variant in current_states:
		var state: Dictionary = state_variant
		var pedestrian_id := str(state.get("pedestrian_id", ""))
		if pedestrian_id == "" or not previous_progress_by_id.has(pedestrian_id):
			continue
		if not is_equal_approx(float(previous_progress_by_id[pedestrian_id]), float(state.get("route_progress", 0.0))):
			changed_ids.append(pedestrian_id)
	return changed_ids
