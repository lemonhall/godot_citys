extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const FRAME_DELTA := 1.0 / 60.0
const SAMPLE_FRAMES := 40
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
	var sample := _find_farfield_only_sample(config, world_data)
	if not T.require_true(self, not sample.is_empty(), "Farfield render commit test requires a farfield-only sample with visible Tier 1 pedestrians"):
		return

	var origin_position: Vector3 = sample.get("origin_position", Vector3.ZERO)
	var streamer := CityChunkStreamer.new(config, world_data)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	streamer.update_for_world_position(origin_position)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Farfield render commit test requires active chunk entries"):
		return

	var guard := 0
	while guard < 96:
		renderer.sync_streaming(active_entries, origin_position, 0.0)
		await process_frame
		var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
		var pending_work_count := int(budget_stats.get("pending_prepare_count", 0)) \
			+ int(budget_stats.get("pending_surface_async_count", 0)) \
			+ int(budget_stats.get("pending_terrain_async_count", 0)) \
			+ int(budget_stats.get("pending_mount_count", 0))
		if renderer.get_chunk_scene_count() > 0 and pending_work_count == 0:
			break
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Farfield render commit test requires mounted chunk scenes"):
		return

	renderer.sync_streaming(active_entries, origin_position, 0.0)
	await process_frame

	renderer.reset_streaming_profile_stats()
	var max_farfield_step_usec := 0
	var max_chunk_commit_usec := 0
	var max_tier1_transform_writes := 0
	var last_profile: Dictionary = {}
	for _frame_index in range(SAMPLE_FRAMES):
		renderer.sync_streaming(active_entries, origin_position, FRAME_DELTA)
		await process_frame
		var profile: Dictionary = renderer.get_streaming_profile_stats()
		max_farfield_step_usec = maxi(max_farfield_step_usec, int(profile.get("crowd_farfield_step_usec", 0)))
		max_chunk_commit_usec = maxi(max_chunk_commit_usec, int(profile.get("crowd_chunk_commit_usec", 0)))
		max_tier1_transform_writes = maxi(max_tier1_transform_writes, int(profile.get("crowd_tier1_transform_writes", 0)))
		last_profile = profile.duplicate(true)

	print("CITY_PEDESTRIAN_FARFIELD_RENDER_COMMIT %s" % JSON.stringify({
		"sample": sample,
		"last_profile": last_profile,
		"max_farfield_step_usec": max_farfield_step_usec,
		"max_chunk_commit_usec": max_chunk_commit_usec,
		"max_tier1_transform_writes": max_tier1_transform_writes,
	}))

	if not T.require_true(self, max_farfield_step_usec > 0, "Farfield render commit test must observe at least one farfield scheduler step"):
		return
	if not T.require_true(self, max_chunk_commit_usec > 0, "Visible Tier 1 farfield stepping must trigger a chunk commit once stepped states need a render refresh"):
		return
	if not T.require_true(self, max_tier1_transform_writes > 0, "Visible Tier 1 farfield stepping must write Tier 1 transforms after the render commit fires"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)

func _find_farfield_only_sample(config: CityWorldConfig, world_data: Dictionary) -> Dictionary:
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)
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
