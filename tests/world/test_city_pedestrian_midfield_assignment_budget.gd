extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const SEARCH_POSITIONS := [
	Vector3.ZERO,
	Vector3(300.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
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

	var summary := _find_assignment_summary(streamer, controller)
	if not T.require_true(self, not summary.is_empty(), "Midfield assignment budget test requires a crowd sample with explicit farfield states"):
		return

	var profile: Dictionary = summary.get("profile_stats", {})
	print("CITY_PEDESTRIAN_MIDFIELD_ASSIGNMENT_BUDGET %s" % JSON.stringify(summary))

	for required_key in [
		"crowd_farfield_count",
		"crowd_midfield_count",
		"crowd_nearfield_count",
		"crowd_assignment_rebuild_usec",
		"crowd_assignment_candidate_count",
	]:
		if not T.require_true(self, profile.has(required_key), "Midfield assignment profiling must expose %s" % required_key):
			return

	var active_state_count := int(summary.get("active_state_count", 0))
	var farfield_count := int(profile.get("crowd_farfield_count", -1))
	var midfield_count := int(profile.get("crowd_midfield_count", -1))
	var nearfield_count := int(profile.get("crowd_nearfield_count", -1))
	var assignment_candidate_count := int(profile.get("crowd_assignment_candidate_count", -1))

	if not T.require_true(self, active_state_count > 0, "Midfield assignment budget requires active pedestrian states"):
		return
	if not T.require_true(self, farfield_count > 0, "Midfield assignment budget requires at least one farfield state outside the assignment hot path"):
		return
	if not T.require_true(self, assignment_candidate_count == midfield_count + nearfield_count, "Assignment candidate count must only include midfield + nearfield states"):
		return
	if not T.require_true(self, farfield_count + assignment_candidate_count == active_state_count, "Farfield states must be excluded from the assignment candidate set"):
		return
	if not T.require_true(self, assignment_candidate_count < active_state_count, "Assignment rebuild must operate on a strict subset of the full crowd when farfield states are present"):
		return
	if not T.require_true(self, int(profile.get("crowd_assignment_rebuild_usec", 0)) > 0, "Midfield assignment budget must measure assignment rebuild cost explicitly"):
		return

	T.pass_and_quit(self)

func _find_assignment_summary(streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		var summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, 0.25)
		var profile: Dictionary = summary.get("profile_stats", {})
		if int(summary.get("active_state_count", 0)) <= 0:
			continue
		if int(profile.get("crowd_farfield_count", 0)) <= 0:
			continue
		return summary
	return controller.get_global_summary()
