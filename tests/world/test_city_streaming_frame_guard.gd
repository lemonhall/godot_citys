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
	renderer.sync_streaming(streamer.get_active_chunk_entries(), Vector3.ZERO)

	var stats_after_sync: Dictionary = renderer.get_streaming_budget_stats()
	var mount_budget := int(stats_after_sync.get("mount_budget_per_tick", 0))
	if not T.require_true(self, mount_budget > 0, "Chunk renderer must expose a positive mount budget"):
		return
	if not T.require_true(self, renderer.get_chunk_scene_count() <= mount_budget, "First sync must not mount more than one budget tick worth of chunks"):
		return

	renderer.call("_process", 0.0)
	if not T.require_true(self, renderer.get_chunk_scene_count() <= mount_budget, "Renderer must not process prepare/mount queues twice in the same frame or traversal spikes will double"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
