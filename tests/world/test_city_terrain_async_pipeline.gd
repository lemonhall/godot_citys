extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	var chunk_key := Vector2i(136, 136)
	var entries: Array = [
		{
			"chunk_id": config.format_chunk_id(chunk_key),
			"chunk_key": chunk_key,
			"state": "mount",
		}
	]
	renderer.sync_streaming(entries, Vector3.ZERO)

	if not T.require_true(self, renderer.has_method("get_streaming_budget_stats"), "Chunk renderer must expose streaming budget stats for async terrain profiling"):
		return
	if not T.require_true(self, renderer.has_method("get_streaming_profile_stats"), "Chunk renderer must expose streaming profile stats for async terrain profiling"):
		return

	var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
	var profile_stats: Dictionary = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(budget_stats.get("pending_terrain_async_count", 0)) >= 1, "M3 must queue terrain work into an async pending set instead of building terrain synchronously inside mount"):
		return
	if not T.require_true(self, int(budget_stats.get("pending_mount_count", 0)) == 0, "Chunk mount must stay blocked until async terrain data becomes ready"):
		return
	if not T.require_true(self, int(profile_stats.get("terrain_async_dispatch_sample_count", 0)) > 0, "Streaming profile must record async terrain dispatch samples"):
		return

	var guard := 0
	while renderer.get_chunk_scene_count() < 1 and guard < 48:
		await process_frame
		renderer.sync_streaming(entries, Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() == 1, "Async terrain pipeline must still finish and mount the requested chunk"):
		return

	profile_stats = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(profile_stats.get("terrain_async_complete_sample_count", 0)) > 0, "Streaming profile must record completed async terrain jobs"):
		return
	if not T.require_true(self, int(profile_stats.get("terrain_commit_sample_count", 0)) > 0, "Streaming profile must record main-thread terrain commit samples"):
		return
	if not T.require_true(self, int(profile_stats.get("terrain_commit_max_usec", 0)) > 0, "Main-thread terrain commit timing must be measurable after async terrain prepare completes"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
