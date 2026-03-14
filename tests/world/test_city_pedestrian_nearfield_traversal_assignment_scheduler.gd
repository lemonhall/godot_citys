extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const FRAME_DELTA := 1.0 / 60.0
const MOVE_STEP_M := 1.0
const MOVE_STEP_COUNT := 4
const SEARCH_POSITIONS := [
	Vector3(1800.0, 0.0, 640.0),
	Vector3(1920.0, 0.0, 704.0),
	Vector3(1984.0, 0.0, 736.0),
	Vector3(2048.0, 0.0, 768.0),
	Vector3(2112.0, 0.0, 800.0),
	Vector3(300.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
	Vector3(1536.0, 0.0, 26.0),
	Vector3.ZERO,
]
const MOVE_DIRECTIONS := [
	Vector3.RIGHT,
	Vector3.FORWARD,
	Vector3(0.70710678, 0.0, 0.70710678),
	Vector3(0.70710678, 0.0, -0.70710678),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var contract_controller := CityPedestrianTierController.new()
	contract_controller.setup(config, world_data)
	if not T.require_true(self, contract_controller.has_method("get_layer_state_ids"), "Nearfield traversal scheduler test requires layer member ID introspection"):
		return
	var scenario := _find_nearfield_same_window_scenario(config, world_data)
	if not T.require_true(self, not scenario.is_empty(), "Nearfield traversal scheduler test requires a same-window sample with persistent nearfield + farfield layers"):
		return

	print("CITY_PEDESTRIAN_NEARFIELD_TRAVERSAL_ASSIGNMENT_SCHEDULER %s" % JSON.stringify(scenario))

	var first_profile: Dictionary = scenario.get("first_profile", {})
	var last_profile: Dictionary = scenario.get("last_profile", {})

	if not T.require_true(self, int(first_profile.get("crowd_nearfield_count", 0)) > 0, "Nearfield traversal scheduler baseline must start with a non-zero nearfield layer"):
		return
	if not T.require_true(self, int(first_profile.get("crowd_farfield_count", 0)) > 0, "Nearfield traversal scheduler baseline must keep a non-zero farfield layer"):
		return
	if not T.require_true(self, int(first_profile.get("crowd_assignment_rebuild_usec", 0)) > 0, "Nearfield traversal scheduler baseline must pay the initial assignment rebuild cost"):
		return
	if not T.require_true(self, int(last_profile.get("crowd_active_state_count", 0)) > 0, "Nearfield traversal scheduler test requires active crowd states after movement"):
		return
	if not T.require_true(self, int(scenario.get("max_assignment_member_churn", -1)) == 0, "Same-window nearfield traversal must keep assignment candidate members stable when reuse skips rebuild"):
		return
	if not T.require_true(self, int(scenario.get("max_midfield_member_churn", -1)) == 0, "Same-window nearfield traversal must not rotate midfield members when reuse skips rebuild"):
		return
	if not T.require_true(self, int(scenario.get("max_nearfield_member_churn", -1)) == 0, "Same-window nearfield traversal must not rotate nearfield members when reuse skips rebuild"):
		return
	if not T.require_true(self, int(scenario.get("max_assignment_rebuild_usec", 0)) == 0, "Same-window nearfield traversal must not keep rebuilding assignments every small movement when layer counts stay stable"):
		return
	if not T.require_true(self, int(scenario.get("max_snapshot_rebuild_usec", 0)) == 0, "Same-window nearfield traversal must not keep rebuilding chunk snapshots when the assignment set stays stable"):
		return

	T.pass_and_quit(self)

func _find_nearfield_same_window_scenario(config: CityWorldConfig, world_data: Dictionary) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var origin: Vector3 = search_position_variant
		for direction_variant in MOVE_DIRECTIONS:
			var direction: Vector3 = direction_variant
			var streamer := CityChunkStreamer.new(config, world_data)
			var controller := CityPedestrianTierController.new()
			controller.setup(config, world_data)
			var scenario := _simulate_same_window_nearfield_path(streamer, controller, origin, direction)
			if not scenario.is_empty():
				return scenario
	return {}

func _simulate_same_window_nearfield_path(streamer: CityChunkStreamer, controller: CityPedestrianTierController, origin: Vector3, direction: Vector3) -> Dictionary:
	streamer.update_for_world_position(origin)
	var origin_entries: Array = streamer.get_active_chunk_entries()
	if origin_entries.is_empty():
		return {}
	var first_summary: Dictionary = controller.update_active_chunks(origin_entries, origin, FRAME_DELTA)
	var first_profile: Dictionary = first_summary.get("profile_stats", {})
	var baseline_nearfield_count := int(first_profile.get("crowd_nearfield_count", 0))
	var baseline_farfield_count := int(first_profile.get("crowd_farfield_count", 0))
	var baseline_assignment_candidate_count := int(first_profile.get("crowd_assignment_candidate_count", 0))
	var baseline_layer_state_ids: Dictionary = controller.get_layer_state_ids()
	var baseline_midfield_ids: Array[String] = _sorted_string_array(baseline_layer_state_ids.get("midfield_ids", []))
	var baseline_nearfield_ids: Array[String] = _sorted_string_array(baseline_layer_state_ids.get("nearfield_ids", []))
	var baseline_assignment_ids: Array[String] = _merge_sorted_unique_ids(baseline_midfield_ids, baseline_nearfield_ids)
	if baseline_nearfield_count <= 0 or baseline_farfield_count <= 0 or baseline_assignment_candidate_count <= 0:
		return {}

	var origin_chunk_ids := _chunk_ids_for_entries(origin_entries)
	var max_assignment_rebuild_usec := 0
	var max_snapshot_rebuild_usec := 0
	var max_assignment_member_churn := 0
	var max_midfield_member_churn := 0
	var max_nearfield_member_churn := 0
	var last_profile: Dictionary = {}
	for move_index in range(MOVE_STEP_COUNT):
		var moved_position := origin + direction * (MOVE_STEP_M * float(move_index + 1))
		streamer.update_for_world_position(moved_position)
		var moved_entries: Array = streamer.get_active_chunk_entries()
		if not _same_chunk_ids(origin_chunk_ids, _chunk_ids_for_entries(moved_entries)):
			return {}
		var moved_summary: Dictionary = controller.update_active_chunks(moved_entries, moved_position, FRAME_DELTA)
		var moved_profile: Dictionary = moved_summary.get("profile_stats", {})
		if int(moved_profile.get("crowd_nearfield_count", -1)) != baseline_nearfield_count:
			return {}
		if int(moved_profile.get("crowd_farfield_count", -1)) != baseline_farfield_count:
			return {}
		if int(moved_profile.get("crowd_assignment_candidate_count", -1)) != baseline_assignment_candidate_count:
			return {}
		var moved_layer_state_ids: Dictionary = controller.get_layer_state_ids()
		var moved_midfield_ids: Array[String] = _sorted_string_array(moved_layer_state_ids.get("midfield_ids", []))
		var moved_nearfield_ids: Array[String] = _sorted_string_array(moved_layer_state_ids.get("nearfield_ids", []))
		var moved_assignment_ids: Array[String] = _merge_sorted_unique_ids(moved_midfield_ids, moved_nearfield_ids)
		max_assignment_member_churn = maxi(max_assignment_member_churn, _symmetric_difference_size(baseline_assignment_ids, moved_assignment_ids))
		max_midfield_member_churn = maxi(max_midfield_member_churn, _symmetric_difference_size(baseline_midfield_ids, moved_midfield_ids))
		max_nearfield_member_churn = maxi(max_nearfield_member_churn, _symmetric_difference_size(baseline_nearfield_ids, moved_nearfield_ids))
		max_assignment_rebuild_usec = maxi(max_assignment_rebuild_usec, int(moved_profile.get("crowd_assignment_rebuild_usec", 0)))
		max_snapshot_rebuild_usec = maxi(max_snapshot_rebuild_usec, int(moved_profile.get("crowd_snapshot_rebuild_usec", 0)))
		last_profile = moved_profile.duplicate(true)

	if last_profile.is_empty():
		return {}
	return {
		"origin": origin,
		"direction": direction,
		"first_profile": first_profile,
		"last_profile": last_profile,
		"baseline_midfield_ids": baseline_midfield_ids,
		"baseline_nearfield_ids": baseline_nearfield_ids,
		"baseline_assignment_ids": baseline_assignment_ids,
		"max_assignment_member_churn": max_assignment_member_churn,
		"max_midfield_member_churn": max_midfield_member_churn,
		"max_nearfield_member_churn": max_nearfield_member_churn,
		"max_assignment_rebuild_usec": max_assignment_rebuild_usec,
		"max_snapshot_rebuild_usec": max_snapshot_rebuild_usec,
	}

func _same_chunk_ids(lhs_ids: Array[String], rhs_ids: Array[String]) -> bool:
	if lhs_ids.size() != rhs_ids.size():
		return false
	for item_index in range(lhs_ids.size()):
		if lhs_ids[item_index] != rhs_ids[item_index]:
			return false
	return true

func _chunk_ids_for_entries(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry_variant in entries:
		ids.append(str((entry_variant as Dictionary).get("chunk_id", "")))
	ids.sort()
	return ids

func _sorted_string_array(values: Array) -> Array[String]:
	var ids: Array[String] = []
	for value_variant in values:
		ids.append(str(value_variant))
	ids.sort()
	return ids

func _merge_sorted_unique_ids(lhs: Array[String], rhs: Array[String]) -> Array[String]:
	var merged_map: Dictionary = {}
	for item_id in lhs:
		merged_map[item_id] = true
	for item_id in rhs:
		merged_map[item_id] = true
	var merged_ids: Array[String] = []
	for item_id_variant in merged_map.keys():
		merged_ids.append(str(item_id_variant))
	merged_ids.sort()
	return merged_ids

func _symmetric_difference_size(lhs: Array[String], rhs: Array[String]) -> int:
	var lhs_map: Dictionary = {}
	var rhs_map: Dictionary = {}
	for item_id in lhs:
		lhs_map[item_id] = true
	for item_id in rhs:
		rhs_map[item_id] = true
	var churn := 0
	for item_id_variant in lhs_map.keys():
		if rhs_map.has(item_id_variant):
			continue
		churn += 1
	for item_id_variant in rhs_map.keys():
		if lhs_map.has(item_id_variant):
			continue
		churn += 1
	return churn
