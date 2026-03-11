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

	if not T.require_true(self, renderer.has_method("get_streaming_budget_stats"), "Chunk renderer must expose streaming budget stats for async road surface profiling"):
		return
	if not T.require_true(self, renderer.has_method("get_streaming_profile_stats"), "Chunk renderer must expose streaming profile stats for async road surface profiling"):
		return

	var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
	var profile_stats: Dictionary = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(budget_stats.get("pending_surface_async_count", 0)) >= 1, "M3 must queue road surface work into an async pending set instead of mounting synchronously"):
		return
	if not T.require_true(self, int(budget_stats.get("pending_mount_count", 0)) == 0, "Chunk mount must stay blocked until async road surface data becomes ready"):
		return
	if not T.require_true(self, int(profile_stats.get("surface_async_dispatch_sample_count", 0)) > 0, "Streaming profile must record async road surface dispatch samples"):
		return

	var guard := 0
	while renderer.get_chunk_scene_count() < 1 and guard < 48:
		await process_frame
		renderer.sync_streaming(entries, Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() == 1, "Async road surface pipeline must still finish and mount the requested chunk"):
		return

	profile_stats = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(profile_stats.get("surface_async_complete_sample_count", 0)) > 0, "Streaming profile must record completed async road surface jobs"):
		return
	if not T.require_true(self, int(profile_stats.get("surface_commit_sample_count", 0)) > 0, "Streaming profile must record main-thread road surface commit samples"):
		return
	if not T.require_true(self, int(profile_stats.get("surface_commit_max_usec", 0)) > 0, "Main-thread road surface commit timing must be measurable after async prepare completes"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
