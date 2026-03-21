extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

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
	if not T.require_true(self, active_entries.size() > 0, "Retained prepare reuse test requires at least one active chunk entry"):
		return

	var entry: Dictionary = active_entries[0]
	var chunk_id := str(entry.get("chunk_id", ""))
	if not T.require_true(self, chunk_id != "", "Retained prepare reuse test requires a concrete chunk id"):
		return

	renderer._last_player_position = entry.get("chunk_center", Vector3.ZERO)
	renderer._pending_prepare[chunk_id] = entry.duplicate(true)
	renderer._store_retained_chunk_scene(chunk_id, CityChunkScene.new())
	renderer._process_prepare_budget()

	var payload: Dictionary = renderer._surface_waiting_payloads.get(chunk_id, {})
	if not T.require_true(self, not payload.is_empty(), "Retained prepare reuse test requires a prepared waiting payload"):
		return
	if not T.require_true(self, not payload.has("prepared_service_roots"), "Retained chunk-scene prepare must not prebuild service roots when mount will reuse a cached chunk scene"):
		return
	if not T.require_true(self, not payload.has("prepared_road_overlay"), "Retained chunk-scene prepare must not prebuild road overlay nodes when mount will reuse a cached chunk scene"):
		return
	if not T.require_true(self, not payload.has("prepared_street_lamps"), "Retained chunk-scene prepare must not prebuild street-lamp nodes when mount will reuse a cached chunk scene"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
