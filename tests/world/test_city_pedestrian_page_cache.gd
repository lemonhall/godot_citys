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
	var controller = CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_runtime_snapshot"), "Tier controller must expose get_runtime_snapshot() for page cache validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var first_runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	var origin_chunk_id := str(streamer.get_current_chunk_id())
	var origin_page_id := "ped_page_%s" % origin_chunk_id

	var travel_offset_m := float(config.chunk_size_m) * 3.2
	var far_position := Vector3(travel_offset_m, 0.0, 0.0)
	streamer.update_for_world_position(far_position)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), far_position, 0.25)

	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var revisit_runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	print("CITY_PEDESTRIAN_PAGE_CACHE %s" % JSON.stringify(revisit_runtime_snapshot))

	var page_build_counts: Dictionary = revisit_runtime_snapshot.get("page_build_counts", {})
	if not T.require_true(self, page_build_counts.has(origin_page_id), "Page cache stats must track the origin pedestrian page by page_id"):
		return
	if not T.require_true(self, int(page_build_counts.get(origin_page_id, 0)) == 1, "Revisiting a recently streamed chunk must reuse the warm pedestrian page instead of rebuilding it"):
		return
	if not T.require_true(self, int(revisit_runtime_snapshot.get("page_cache_hit_count", 0)) > int(first_runtime_snapshot.get("page_cache_hit_count", 0)), "Revisiting a chunk must increment pedestrian page cache hits"):
		return
	if not T.require_true(self, int(revisit_runtime_snapshot.get("duplicate_page_load_count", 0)) == 0, "Warm-cache revisit must not duplicate pedestrian page loads"):
		return

	T.pass_and_quit(self)
