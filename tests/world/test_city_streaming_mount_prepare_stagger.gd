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
	var third_key := Vector2i(current_key.x + 2, current_key.y)
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

	if not T.require_true(self, renderer.get_chunk_scene_count() == 1, "Renderer must mount the warm-start chunk before mount/prepare staggering is evaluated"):
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
	if not T.require_true(self, int(stats_after_expand.get("last_prepare_count", 0)) == 1, "Expanded window must prepare one new chunk before staggering is evaluated"):
		return
	if not T.require_true(self, int(stats_after_expand.get("last_mount_count", 0)) == 0, "Expanded window must still defer the new chunk mount until a later tick"):
		return
	if not T.require_true(self, int(stats_after_expand.get("pending_mount_count", 0)) >= 1, "Expanded window must leave a ready chunk queued for mount on the next tick"):
		return

	var stagger_entries: Array = [
		expanded_entries[0],
		expanded_entries[1],
		{
			"chunk_id": config.format_chunk_id(third_key),
			"chunk_key": third_key,
			"state": "prepare",
		}
	]
	renderer.sync_streaming(stagger_entries, Vector3(256.0, 0.0, 0.0))
	var stats_before_stagger_tick: Dictionary = renderer.get_streaming_budget_stats()
	if not T.require_true(self, int(stats_before_stagger_tick.get("pending_prepare_count", 0)) >= 1, "Stagger regression test requires a new chunk waiting in the prepare queue before the next streaming tick"):
		return

	renderer.call("_process_streaming_queues")
	var stats_after_stagger_tick: Dictionary = renderer.get_streaming_budget_stats()
	if not T.require_true(self, int(stats_after_stagger_tick.get("last_mount_count", 0)) == 1, "Stagger tick must still mount one ready chunk"):
		return
	if not T.require_true(self, int(stats_after_stagger_tick.get("last_prepare_count", 0)) == 0, "Streaming tick must not prepare a new chunk in the same tick that already spent budget on a chunk mount"):
		return
	if not T.require_true(self, int(stats_after_stagger_tick.get("pending_prepare_count", 0)) >= 1, "Skipped prepare work must stay queued for the following tick instead of disappearing"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
