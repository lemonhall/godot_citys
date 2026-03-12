extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")

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
	renderer.sync_streaming(active_entries, Vector3.ZERO)

	if not T.require_true(self, renderer.has_method("get_streaming_budget_stats"), "Chunk renderer must expose streaming budget stats for surface async concurrency guards"):
		return

	for _step in range(8):
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)

	var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
	if not T.require_true(self, int(budget_stats.get("surface_async_concurrency_limit", 0)) == 1, "Surface async pipeline must expose a single-flight concurrency limit for redline closeout"):
		return
	if not T.require_true(self, int(budget_stats.get("pending_surface_async_count", 0)) <= int(budget_stats.get("surface_async_concurrency_limit", 0)), "Surface async pipeline must not exceed its declared concurrency limit or background CPU contention will spike wall-frame time"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
