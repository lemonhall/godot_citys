extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Chunk snapshot cache test requires at least one active chunk entry"):
		return

	controller.update_active_chunks(active_entries, origin, 0.0)
	var chunk_id := str((active_entries[0] as Dictionary).get("chunk_id", ""))
	var first_snapshot_ref: Dictionary = controller.get_chunk_snapshot_ref(chunk_id)
	if not T.require_true(self, not first_snapshot_ref.is_empty(), "Chunk snapshot cache test requires a non-empty first snapshot ref"):
		return

	controller.update_active_chunks(active_entries, origin, 0.0)
	var second_snapshot_ref: Dictionary = controller.get_chunk_snapshot_ref(chunk_id)
	print("CITY_PEDESTRIAN_CHUNK_SNAPSHOT_CACHE chunk_id=%s first=%s second=%s" % [chunk_id, str(first_snapshot_ref), str(second_snapshot_ref)])

	if not T.require_true(self, is_same(first_snapshot_ref, second_snapshot_ref), "Stable chunk snapshot refs must be reused between unchanged updates instead of allocating fresh dictionaries every frame"):
		return

	T.pass_and_quit(self)
