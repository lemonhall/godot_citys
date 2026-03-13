extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	streamer.update_for_world_position(Vector3.ZERO)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Chunk dirty-skip test requires active chunk entries"):
		return

	var guard := 0
	while guard < 96:
		renderer.sync_streaming(active_entries, Vector3.ZERO, 0.0)
		await process_frame
		var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
		var pending_work_count := int(budget_stats.get("pending_prepare_count", 0)) \
			+ int(budget_stats.get("pending_surface_async_count", 0)) \
			+ int(budget_stats.get("pending_terrain_async_count", 0)) \
			+ int(budget_stats.get("pending_mount_count", 0))
		if renderer.get_chunk_scene_count() > 0 and pending_work_count == 0:
			break
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Chunk dirty-skip test requires mounted chunk scenes"):
		return

	renderer.sync_streaming(active_entries, Vector3.ZERO, 0.0)
	await process_frame

	renderer.reset_streaming_profile_stats()
	renderer.sync_streaming(active_entries, Vector3.ZERO, 0.0)

	var profile: Dictionary = renderer.get_streaming_profile_stats()
	print("CITY_PEDESTRIAN_CHUNK_DIRTY_SKIP %s" % JSON.stringify(profile))

	if not T.require_true(self, int(profile.get("crowd_active_state_count", 0)) > 0, "Chunk dirty-skip test requires active crowd state profiling"):
		return
	if not T.require_true(self, int(profile.get("crowd_chunk_commit_usec", -1)) == 0, "Stable zero-delta crowd frames must skip chunk commit work when no mounted chunk snapshot is dirty"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
