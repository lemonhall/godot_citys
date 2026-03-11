extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var streamer_script := load("res://city_game/world/streaming/CityChunkStreamer.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing CityWorldConfig.gd")
		return
	if generator_script == null:
		T.fail_and_quit(self, "Missing CityWorldGenerator.gd")
		return
	if streamer_script == null:
		T.fail_and_quit(self, "Missing CityChunkStreamer.gd")
		return

	var config = config_script.new()
	var world_data: Dictionary = generator_script.new().generate_world(config)
	var streamer = streamer_script.new(config, world_data)

	var first_events: Array = streamer.update_for_world_position(Vector3(0.0, 0.0, 0.0))
	if not T.require_true(self, first_events.size() > 0, "Streamer must emit events on first update"):
		return
	if not T.require_true(self, streamer.get_active_chunk_count() == 25, "Initial active chunk window must equal 25 near world center"):
		return
	if not T.require_true(self, streamer.get_active_chunk_count() <= 25, "Active chunk count must stay <= 25"):
		return

	var first_ids: Array[String] = streamer.get_active_chunk_ids()
	var second_events: Array = streamer.update_for_world_position(Vector3(1024.0, 0.0, 0.0))
	if not T.require_true(self, second_events.size() > 0, "Streamer must emit events after crossing chunk boundaries"):
		return
	if not T.require_true(self, streamer.get_active_chunk_count() <= 25, "Active chunk count must remain <= 25 after movement"):
		return

	var second_ids: Array[String] = streamer.get_active_chunk_ids()
	if not T.require_true(self, first_ids != second_ids, "Active chunk ids must change when player enters a different chunk window"):
		return
	if not T.require_true(self, streamer.get_current_chunk_id() != "", "Current chunk id must not be empty"):
		return
	if not T.require_true(self, streamer.get_transition_log().size() >= first_events.size() + second_events.size(), "Transition log must capture streaming events"):
		return

	T.pass_and_quit(self)

