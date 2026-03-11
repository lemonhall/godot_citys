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
	renderer.sync_streaming(active_entries, Vector3.ZERO)

	if not T.require_true(self, renderer.has_method("get_streaming_budget_stats"), "Chunk renderer must expose get_streaming_budget_stats()"):
		return

	var budget_stats: Dictionary = renderer.get_streaming_budget_stats()
	var mount_budget := int(budget_stats.get("mount_budget_per_tick", 0))
	if not T.require_true(self, mount_budget > 0, "Chunk renderer must expose a positive mount budget"):
		return
	if not T.require_true(self, int(budget_stats.get("last_mount_count", 0)) <= mount_budget, "Chunk renderer must respect mount budget per tick"):
		return
	if not T.require_true(self, renderer.get_chunk_scene_count() <= mount_budget, "First sync must not mount all chunks at once"):
		return

	var target_chunk_count := active_entries.size()
	var guard := 0
	while renderer.get_chunk_scene_count() < target_chunk_count and guard < 64:
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() == target_chunk_count, "Budgeted sync must eventually mount the full active window"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
