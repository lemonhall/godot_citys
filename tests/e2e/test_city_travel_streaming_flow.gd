extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for travel streaming flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_chunk_streamer"), "CityPrototype must expose get_chunk_streamer()"):
		return
	if not T.require_true(self, world.has_method("update_streaming_for_position"), "CityPrototype must expose update_streaming_for_position()"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for travel flow"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position()"):
		return
	if not T.require_true(self, world.get_chunk_streamer().has_method("clear_transition_log"), "CityChunkStreamer must expose clear_transition_log()"):
		return

	world.get_chunk_streamer().clear_transition_log()

	var seen_chunk_ids: Dictionary = {}
	for step in 9:
		var travel_position := Vector3(-1200.0 + float(step) * 300.0, 1.1, 26.0)
		player.teleport_to_world_position(travel_position)
		world.update_streaming_for_position(travel_position)
		await process_frame

		var snapshot: Dictionary = world.get_streaming_snapshot()
		if not T.require_true(self, snapshot.get("active_chunk_count", 0) <= 25, "Travel flow must keep active_chunk_count <= 25"):
			return
		var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
		if not T.require_true(self, current_chunk_id != "", "Travel flow must report current_chunk_id"):
			return
		seen_chunk_ids[current_chunk_id] = true

	if not T.require_true(self, seen_chunk_ids.size() >= 8, "Travel flow must cross at least 8 unique chunks"):
		return

	var transition_log: Array = world.get_chunk_streamer().get_transition_log()
	var mounted_ids: Dictionary = {}
	for entry in transition_log:
		if entry.get("event_type", "") == "mount":
			var chunk_id := str(entry.get("chunk_id", ""))
			if mounted_ids.has(chunk_id):
				T.fail_and_quit(self, "Travel flow must not mount the same chunk twice during one-way traversal: %s" % chunk_id)
				return
			mounted_ids[chunk_id] = true

	world.queue_free()
	T.pass_and_quit(self)
