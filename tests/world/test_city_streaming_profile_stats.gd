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

	for _frame_index in range(10):
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)

	if not T.require_true(self, renderer.has_method("get_streaming_profile_stats"), "Chunk renderer must expose get_streaming_profile_stats()"):
		return

	var profile: Dictionary = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(profile.get("prepare_profile_sample_count", 0)) > 0, "Streaming profile must count prepare samples"):
		return
	if not T.require_true(self, int(profile.get("mount_setup_sample_count", 0)) > 0, "Streaming profile must count mount setup samples"):
		return
	if not T.require_true(self, int(profile.get("prepare_profile_max_usec", 0)) > 0, "Streaming profile must expose prepare max usec"):
		return
	if not T.require_true(self, int(profile.get("mount_setup_max_usec", 0)) > 0, "Streaming profile must expose mount setup max usec"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
