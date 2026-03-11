extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var start_position := Vector3.ZERO
	var current_chunk_key := CityChunkKey.world_to_chunk_key(config, start_position)
	var chunk_origin := _chunk_origin_from_key(config, current_chunk_key)
	var near_east_edge := Vector3(
		chunk_origin.x + float(config.chunk_size_m) * 0.82,
		0.0,
		chunk_origin.y + float(config.chunk_size_m) * 0.5
	)

	streamer.update_for_world_position(start_position)
	streamer.update_for_world_position(near_east_edge)

	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() == 25, "Prefetch shift must preserve the 5x5 active chunk budget"):
		return

	var min_x := 999999
	var max_x := -999999
	for entry in active_entries:
		var chunk_key: Vector2i = (entry as Dictionary).get("chunk_key", Vector2i.ZERO)
		min_x = mini(min_x, chunk_key.x)
		max_x = maxi(max_x, chunk_key.x)

	if not T.require_true(self, max_x == current_chunk_key.x + 3, "Approaching the east boundary at speed must shift the streaming window one chunk ahead to prefetch traversal content"):
		return
	if not T.require_true(self, min_x == current_chunk_key.x - 1, "Forward prefetch must trade the far trailing column for one extra lookahead column"):
		return

	T.pass_and_quit(self)

func _chunk_origin_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector2:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector2(
		bounds.position.x + float(chunk_key.x) * float(config.chunk_size_m),
		bounds.position.y + float(chunk_key.y) * float(config.chunk_size_m)
	)
