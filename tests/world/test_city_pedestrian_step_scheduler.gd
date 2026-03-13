extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var origin := Vector3.ZERO
	var frame_delta := 1.0 / 60.0
	streamer.update_for_world_position(origin)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Step scheduler test requires at least one active chunk entry"):
		return

	var first_summary: Dictionary = controller.update_active_chunks(active_entries, origin, frame_delta)
	var first_profile: Dictionary = first_summary.get("profile_stats", {})
	var first_snapshot: Dictionary = controller.get_global_snapshot()
	var first_tier1_states: Array = first_snapshot.get("tier1_states", [])
	var first_tier1_progress_by_id := _tier1_progress_by_id(first_tier1_states)

	var second_summary: Dictionary = controller.update_active_chunks(active_entries, origin, frame_delta)
	var second_profile: Dictionary = second_summary.get("profile_stats", {})
	var second_snapshot: Dictionary = controller.get_global_snapshot()
	var second_tier1_states: Array = second_snapshot.get("tier1_states", [])
	var second_changed_ids := _collect_changed_tier1_ids(first_tier1_progress_by_id, second_tier1_states)
	var previous_tier1_progress_by_id := _tier1_progress_by_id(second_tier1_states)
	var unique_changed_ids: Dictionary = {}
	for pedestrian_id in second_changed_ids:
		unique_changed_ids[str(pedestrian_id)] = true
	var max_changed_count := second_changed_ids.size()
	var last_summary: Dictionary = second_summary
	var last_profile: Dictionary = second_profile.duplicate(true)
	for _frame_index in range(7):
		last_summary = controller.update_active_chunks(active_entries, origin, frame_delta)
		last_profile = (last_summary.get("profile_stats", {}) as Dictionary).duplicate(true)
		var last_snapshot: Dictionary = controller.get_global_snapshot()
		var last_tier1_states: Array = last_snapshot.get("tier1_states", [])
		var changed_ids := _collect_changed_tier1_ids(previous_tier1_progress_by_id, last_tier1_states)
		for pedestrian_id in changed_ids:
			unique_changed_ids[str(pedestrian_id)] = true
		max_changed_count = maxi(max_changed_count, changed_ids.size())
		previous_tier1_progress_by_id = _tier1_progress_by_id(last_tier1_states)

	print("CITY_PEDESTRIAN_STEP_SCHEDULER first=%s second=%s second_changed=%d max_changed=%d unique_changed=%d last=%s" % [
		JSON.stringify(first_profile),
		JSON.stringify(second_profile),
		second_changed_ids.size(),
		max_changed_count,
		unique_changed_ids.size(),
		JSON.stringify(last_profile),
	])

	if not T.require_true(self, int(first_profile.get("crowd_active_state_count", 0)) > 0, "Step scheduler test requires active pedestrian states"):
		return
	if not T.require_true(self, first_tier1_states.size() > 0, "Step scheduler test requires Tier 1 states to validate staggered farfield stepping"):
		return
	if not T.require_true(self, int(second_summary.get("tier2_count", -1)) == 0 and int(second_summary.get("tier3_count", -1)) == 0, "Step scheduler origin probe expects a pure Tier 1/Tier 0 frame without reactive nearfield states"):
		return
	if not T.require_true(self, second_changed_ids.size() > 0, "Tier 1 scheduler must advance at least one Tier 1 pedestrian on the second stable frame instead of idling until a whole-interval burst frame"):
		return
	if not T.require_true(self, second_changed_ids.size() < first_tier1_states.size(), "Tier 1 scheduler must not step every Tier 1 pedestrian in the same stable frame"):
		return
	if not T.require_true(self, max_changed_count < first_tier1_states.size(), "Tier 1 scheduler must keep each stable-frame Tier 1 batch below the full Tier 1 population"):
		return
	if not T.require_true(self, unique_changed_ids.size() > max_changed_count, "Tier 1 scheduler must rotate staggered work across multiple stable frames instead of repeating the same subset"):
		return

	T.pass_and_quit(self)

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
