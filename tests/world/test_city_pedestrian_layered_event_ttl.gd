extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const FRAME_DELTA := 1.0 / 60.0
const EVENT_SETTLE_FRAMES := 90
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

	var origin_position := _resolve_farfield_only_origin(streamer, controller)
	streamer.update_for_world_position(origin_position)
	var active_entries: Array = streamer.get_active_chunk_entries()
	var baseline_summary: Dictionary = controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var baseline_profile: Dictionary = baseline_summary.get("profile_stats", {})

	if not T.require_true(self, active_entries.size() > 0, "Layered event TTL test requires active chunk entries at the sampled origin"):
		return
	if not T.require_true(self, int(baseline_profile.get("crowd_assignment_candidate_count", -1)) == 0, "Layered event TTL test requires a farfield-only origin without assignment/threat candidates"):
		return

	controller.notify_projectile_event(origin_position, Vector3.RIGHT, 36.0)
	controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
	var seeded_runtime_summary: Dictionary = controller.get_runtime_summary()
	if not T.require_true(self, int(seeded_runtime_summary.get("reactive_event_count", 0)) > 0, "Projectile threat should seed at least one pending reactive event"):
		return

	var settled_runtime_summary := seeded_runtime_summary
	for _frame_index in range(EVENT_SETTLE_FRAMES):
		controller.update_active_chunks(active_entries, origin_position, FRAME_DELTA)
		settled_runtime_summary = controller.get_runtime_summary()

	print("CITY_PEDESTRIAN_LAYERED_EVENT_TTL %s" % JSON.stringify({
		"origin_position": origin_position,
		"baseline_profile": baseline_profile,
		"seeded_runtime_summary": seeded_runtime_summary,
		"settled_runtime_summary": settled_runtime_summary,
	}))

	if not T.require_true(self, int(settled_runtime_summary.get("reactive_event_count", -1)) == 0, "Reactive events must continue aging out even when layered runtime has no threat candidates to process"):
		return

	T.pass_and_quit(self)

func _resolve_farfield_only_origin(streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Vector3:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		var summary: Dictionary = controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, FRAME_DELTA)
		var profile: Dictionary = summary.get("profile_stats", {})
		if int(summary.get("active_state_count", 0)) <= 0:
			continue
		if int(profile.get("crowd_assignment_candidate_count", 1)) != 0:
			continue
		return search_position
	return Vector3.ZERO
