extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)

	var current_key := CityChunkKey.world_to_chunk_key(config, Vector3.ZERO)
	var next_key := Vector2i(current_key.x + 1, current_key.y)
	var initial_entries: Array = [
		{
			"chunk_id": config.format_chunk_id(current_key),
			"chunk_key": current_key,
			"state": "mount",
		}
	]
	renderer.sync_streaming(initial_entries, Vector3.ZERO)

	var guard := 0
	while renderer.get_chunk_scene_count() < 1 and guard < 8:
		await process_frame
		renderer.sync_streaming(initial_entries, Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() == 1, "Renderer must mount the initial warm-start chunk before pipeline separation is evaluated"):
		return

	await process_frame

	var expanded_entries: Array = [
		initial_entries[0],
		{
			"chunk_id": config.format_chunk_id(next_key),
			"chunk_key": next_key,
			"state": "prepare",
		}
	]
	renderer.sync_streaming(expanded_entries, Vector3(128.0, 0.0, 0.0))
	var stats_after_expand: Dictionary = renderer.get_streaming_budget_stats()

	if not T.require_true(self, renderer.get_chunk_scene_count() == 1, "Renderer must not prepare and mount a newly requested chunk in the same frame once warm-start is complete"):
		return
	if not T.require_true(self, int(stats_after_expand.get("last_prepare_count", 0)) == 1, "Expanded window must still prepare one new chunk in the current frame"):
		return
	if not T.require_true(self, int(stats_after_expand.get("last_mount_count", 0)) == 0, "Expanded window must defer new chunk mount until a later frame"):
		return
	if not T.require_true(self, int(stats_after_expand.get("pending_mount_count", 0)) >= 1, "Prepared chunk must stay queued for mount on the next frame"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
